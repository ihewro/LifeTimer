<?php
/**
 * 基于用户账户的同步API接口
 * 替换原有的基于设备隔离的同步系统
 */

// 注意：config/database.php 和基础函数已经在 index.php 中包含了
// 只需要包含认证相关的函数
require_once 'includes/auth.php';

// 设置响应头
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 处理预检请求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    $method = $_SERVER['REQUEST_METHOD'];
    $request_uri = $_SERVER['REQUEST_URI'];
    $path = parse_url($request_uri, PHP_URL_PATH);

    // 移除基础路径（如果存在）
    $path = str_replace('/sync_server', '', $path);

    // 调试信息
    error_log("Debug sync_user.php: Request URI: " . $request_uri);
    error_log("Debug sync_user.php: Path: " . $path);
    error_log("Debug sync_user.php: Method: " . $method);

    // 路由处理
    if ($method === 'GET' && $path === '/api/user/sync/full') {
        handleFullSync();
    } elseif ($method === 'POST' && $path === '/api/user/sync/incremental') {
        handleIncrementalSync();
    } elseif ($method === 'POST' && ($path === '/api/user/sync/migrate' || $path === '/api/sync/migrate')) {
        handleDataMigration();
    } else {
        throw new Exception('Endpoint not found', 404);
    }
    
} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    // 确保 code 是整数
    if (!is_int($code)) {
        $code = 500;
    }
    http_response_code($code);
    logMessage("Sync error: " . $e->getMessage(), 'ERROR');
    sendError($e->getMessage(), $code);
}

/**
 * 全量同步处理
 */
function handleFullSync() {
    $userInfo = requireAuth();
    
    $db = getDB();
    
    // 获取用户的所有数据
    $data = [
        'pomodoro_events' => getUserPomodoroEvents($db, $userInfo['user_id']),
        'system_events' => getUserSystemEvents($db, $userInfo['user_id']),
        'timer_settings' => getUserTimerSettings($db, $userInfo['user_id']),
        'server_timestamp' => getCurrentTimestamp(),
        'user_info' => [
            'user_uuid' => $userInfo['user_uuid'],
            'device_count' => getUserDeviceCount($db, $userInfo['user_id'])
        ]
    ];
    
    // 更新设备最后同步时间
    updateDeviceLastSync($db, $userInfo['device_id'], $data['server_timestamp']);
    
    logMessage("Full sync completed for user: {$userInfo['user_uuid']}, device: {$userInfo['device_uuid']}");
    sendSuccess($data, 'Full sync completed');
}

/**
 * 增量同步处理
 */
function handleIncrementalSync() {
    $userInfo = requireAuth();
    $data = getRequestData();
    
    // 验证必需参数
    validateRequired($data, ['last_sync_timestamp', 'changes']);
    
    $lastSyncTimestamp = $data['last_sync_timestamp'];
    $changes = $data['changes'];
    $serverTimestamp = getCurrentTimestamp();
    
    $db = getDB();
    $db->beginTransaction();
    
    try {
        $conflicts = [];
        
        // 检查是否为强制覆盖远程操作
        if ($lastSyncTimestamp == 0) {
            logMessage("Force overwrite remote detected for user: {$userInfo['user_uuid']}");
            
            // 强制覆盖：清空现有数据并用客户端数据替换
            performForceOverwriteRemote($db, $userInfo['user_id'], $userInfo['device_id'], $changes, $serverTimestamp);
            
            $serverChanges = [
                'pomodoro_events' => [],
                'system_events' => [],
                'timer_settings' => null
            ];
        } else {
            // 正常增量同步
            // 处理客户端变更
            if (isset($changes['pomodoro_events'])) {
                $conflicts = array_merge($conflicts,
                    processUserPomodoroEventChanges($db, $userInfo['user_id'], $userInfo['device_id'], $changes['pomodoro_events'], $lastSyncTimestamp)
                );
            }
            
            if (isset($changes['system_events'])) {
                processUserSystemEventChanges($db, $userInfo['user_id'], $userInfo['device_id'], $changes['system_events']);
            }
            
            if (isset($changes['timer_settings'])) {
                processUserTimerSettingsChanges($db, $userInfo['user_id'], $userInfo['device_id'], $changes['timer_settings'], $lastSyncTimestamp);
            }
            
            // 获取服务器端的变更
            $serverChanges = [
                'pomodoro_events' => getUserPomodoroEventsAfter($db, $userInfo['user_id'], $lastSyncTimestamp),
                'system_events' => getUserSystemEventsAfter($db, $userInfo['user_id'], $lastSyncTimestamp),
                'timer_settings' => getUserTimerSettingsAfter($db, $userInfo['user_id'], $lastSyncTimestamp)
            ];
        }
        
        // 更新设备最后同步时间
        updateDeviceLastSync($db, $userInfo['device_id'], $serverTimestamp);
        
        $db->commit();
        
        logMessage("Incremental sync completed for user: {$userInfo['user_uuid']}, device: {$userInfo['device_uuid']}");
        
        sendSuccess([
            'conflicts' => $conflicts,
            'server_changes' => $serverChanges,
            'server_timestamp' => $serverTimestamp
        ], 'Incremental sync completed');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 获取用户的番茄事件
 */
function getUserPomodoroEvents($db, $userId) {
    $stmt = $db->prepare('
        SELECT 
            uuid, title, start_time, end_time, event_type, 
            is_completed, created_at, updated_at
        FROM pomodoro_events 
        WHERE user_id = ? AND deleted_at IS NULL
        ORDER BY start_time DESC
    ');
    $stmt->execute([$userId]);
    return $stmt->fetchAll();
}

/**
 * 获取用户的系统事件
 */
function getUserSystemEvents($db, $userId) {
    $stmt = $db->prepare('
        SELECT 
            uuid, event_type, timestamp, data, created_at
        FROM system_events 
        WHERE user_id = ? AND deleted_at IS NULL
        ORDER BY timestamp DESC
    ');
    $stmt->execute([$userId]);
    return $stmt->fetchAll();
}

/**
 * 获取用户的计时器设置
 */
function getUserTimerSettings($db, $userId) {
    // 优先获取全局设置，如果没有则返回null
    $stmt = $db->prepare('
        SELECT pomodoro_time, short_break_time, long_break_time, updated_at
        FROM timer_settings 
        WHERE user_id = ? AND is_global = 1
        ORDER BY updated_at DESC
        LIMIT 1
    ');
    $stmt->execute([$userId]);
    return $stmt->fetch() ?: null;
}

/**
 * 获取用户设备数量
 */
function getUserDeviceCount($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM devices WHERE user_id = ? AND is_active = 1');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn();
}

/**
 * 更新设备最后同步时间
 */
function updateDeviceLastSync($db, $deviceId, $timestamp) {
    $stmt = $db->prepare('UPDATE devices SET last_sync_timestamp = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
    $stmt->execute([$timestamp, $deviceId]);
}

/**
 * 获取指定时间后的用户番茄事件
 */
function getUserPomodoroEventsAfter($db, $userId, $timestamp) {
    $stmt = $db->prepare('
        SELECT 
            uuid, title, start_time, end_time, event_type, 
            is_completed, created_at, updated_at
        FROM pomodoro_events 
        WHERE user_id = ? AND updated_at > ? AND deleted_at IS NULL
        ORDER BY updated_at ASC
    ');
    $stmt->execute([$userId, $timestamp]);
    return $stmt->fetchAll();
}

/**
 * 获取指定时间后的用户系统事件
 */
function getUserSystemEventsAfter($db, $userId, $timestamp) {
    $stmt = $db->prepare('
        SELECT 
            uuid, event_type, timestamp, data, created_at
        FROM system_events 
        WHERE user_id = ? AND created_at > ? AND deleted_at IS NULL
        ORDER BY created_at ASC
    ');
    $stmt->execute([$userId, $timestamp]);
    return $stmt->fetchAll();
}

/**
 * 获取指定时间后的用户计时器设置
 */
function getUserTimerSettingsAfter($db, $userId, $timestamp) {
    $stmt = $db->prepare('
        SELECT pomodoro_time, short_break_time, long_break_time, updated_at
        FROM timer_settings 
        WHERE user_id = ? AND updated_at > ? AND is_global = 1
        ORDER BY updated_at DESC
        LIMIT 1
    ');
    $stmt->execute([$userId, $timestamp]);
    return $stmt->fetch() ?: null;
}

/**
 * 处理用户番茄事件变更
 */
function processUserPomodoroEventChanges($db, $userId, $deviceId, $changes, $lastSyncTimestamp) {
    $conflicts = [];
    
    // 处理新创建的事件
    if (isset($changes['created'])) {
        foreach ($changes['created'] as $event) {
            try {
                $stmt = $db->prepare('
                    INSERT INTO pomodoro_events
                    (uuid, user_id, device_id, title, start_time, end_time, event_type, is_completed, created_at, updated_at, last_modified_device_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ');
                $stmt->execute([
                    $event['uuid'],
                    $userId,
                    $deviceId,
                    $event['title'],
                    $event['start_time'],
                    $event['end_time'],
                    $event['event_type'],
                    $event['is_completed'] ? 1 : 0,
                    $event['created_at'],
                    $event['updated_at'],
                    $deviceId
                ]);
            } catch (PDOException $e) {
                if ($e->getCode() == 23000) { // UNIQUE constraint failed
                    $conflicts[] = [
                        'type' => 'pomodoro_event',
                        'uuid' => $event['uuid'],
                        'reason' => 'duplicate_uuid'
                    ];
                } else {
                    throw $e;
                }
            }
        }
    }
    
    // 处理更新的事件
    if (isset($changes['updated'])) {
        foreach ($changes['updated'] as $event) {
            // 检查服务器端是否有更新的版本
            $stmt = $db->prepare('SELECT updated_at FROM pomodoro_events WHERE uuid = ? AND user_id = ?');
            $stmt->execute([$event['uuid'], $userId]);
            $serverEvent = $stmt->fetch();
            
            if ($serverEvent && $serverEvent['updated_at'] > $lastSyncTimestamp) {
                // 冲突：服务器端也有更新
                $conflicts[] = [
                    'type' => 'pomodoro_event',
                    'uuid' => $event['uuid'],
                    'reason' => 'concurrent_modification',
                    'server_updated_at' => $serverEvent['updated_at'],
                    'client_updated_at' => $event['updated_at']
                ];
            } else {
                // 更新事件
                $stmt = $db->prepare('
                    UPDATE pomodoro_events 
                    SET title = ?, start_time = ?, end_time = ?, event_type = ?, 
                        is_completed = ?, updated_at = ?, last_modified_device_id = ?
                    WHERE uuid = ? AND user_id = ?
                ');
                $stmt->execute([
                    $event['title'],
                    $event['start_time'],
                    $event['end_time'],
                    $event['event_type'],
                    $event['is_completed'] ? 1 : 0,
                    $event['updated_at'],
                    $deviceId,
                    $event['uuid'],
                    $userId
                ]);
            }
        }
    }
    
    // 处理删除的事件
    if (isset($changes['deleted'])) {
        foreach ($changes['deleted'] as $uuid) {
            $stmt = $db->prepare('
                UPDATE pomodoro_events 
                SET deleted_at = ?, last_modified_device_id = ?
                WHERE uuid = ? AND user_id = ? AND deleted_at IS NULL
            ');
            $stmt->execute([getCurrentTimestamp(), $deviceId, $uuid, $userId]);
        }
    }
    
    return $conflicts;
}

/**
 * 处理用户系统事件变更
 */
function processUserSystemEventChanges($db, $userId, $deviceId, $changes) {
    if (isset($changes['created'])) {
        foreach ($changes['created'] as $event) {
            try {
                $stmt = $db->prepare('
                    INSERT INTO system_events
                    (uuid, user_id, device_id, event_type, timestamp, data, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ');
                $stmt->execute([
                    $event['uuid'],
                    $userId,
                    $deviceId,
                    $event['event_type'],
                    $event['timestamp'],
                    $event['data'],
                    $event['created_at']
                ]);
            } catch (PDOException $e) {
                if ($e->getCode() != 23000) { // 忽略重复UUID错误
                    throw $e;
                }
            }
        }
    }
}

/**
 * 处理用户计时器设置变更
 */
function processUserTimerSettingsChanges($db, $userId, $deviceId, $settings, $lastSyncTimestamp) {
    // 检查是否有冲突
    $stmt = $db->prepare('SELECT updated_at FROM timer_settings WHERE user_id = ? AND is_global = 1');
    $stmt->execute([$userId]);
    $serverSettings = $stmt->fetch();
    
    if ($serverSettings && $serverSettings['updated_at'] > $lastSyncTimestamp) {
        // 有冲突，使用最新的设置（客户端优先）
        logMessage("Timer settings conflict detected for user: $userId, using client version");
    }
    
    // 更新或插入设置
    $stmt = $db->prepare('
        INSERT OR REPLACE INTO timer_settings 
        (user_id, device_id, pomodoro_time, short_break_time, long_break_time, updated_at, is_global)
        VALUES (?, NULL, ?, ?, ?, ?, 1)
    ');
    $stmt->execute([
        $userId,
        $settings['pomodoro_time'],
        $settings['short_break_time'],
        $settings['long_break_time'],
        $settings['updated_at']
    ]);
}

/**
 * 强制覆盖远程数据
 */
function performForceOverwriteRemote($db, $userId, $deviceId, $changes, $timestamp) {
    // 清空用户数据
    clearUserData($db, $userId, $timestamp);
    
    // 重新插入客户端数据
    if (isset($changes['pomodoro_events'])) {
        processUserPomodoroEventChanges($db, $userId, $deviceId, $changes['pomodoro_events'], 0);
    }
    
    if (isset($changes['system_events'])) {
        processUserSystemEventChanges($db, $userId, $deviceId, $changes['system_events']);
    }
    
    if (isset($changes['timer_settings'])) {
        processUserTimerSettingsChanges($db, $userId, $deviceId, $changes['timer_settings'], 0);
    }
    
    logMessage("Force overwrite completed for user: $userId");
}

/**
 * 清空用户数据（用于强制覆盖）
 */
function clearUserData($db, $userId, $timestamp) {
    // 硬删除所有番茄事件
    $stmt = $db->prepare('DELETE FROM pomodoro_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    // 硬删除所有系统事件
    $stmt = $db->prepare('DELETE FROM system_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    // 删除计时器设置
    $stmt = $db->prepare('DELETE FROM timer_settings WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    logMessage("Hard deleted all existing data for user: $userId (force overwrite)");
}

/**
 * 处理数据迁移请求
 */
function handleDataMigration() {
    $data = getRequestData();

    // 验证必需参数
    validateRequired($data, ['device_uuid']);

    $deviceUuid = $data['device_uuid'];
    $targetUserUuid = $data['target_user_uuid'] ?? null;

    // 验证UUID格式
    if (!validateUUID($deviceUuid)) {
        throw new Exception('Invalid device UUID format');
    }

    if ($targetUserUuid && !validateUUID($targetUserUuid)) {
        throw new Exception('Invalid target user UUID format');
    }

    $db = getDB();

    // 检查数据库版本
    $dbVersion = Database::getInstance()->getDatabaseVersion();
    if ($dbVersion['type'] !== 'device_isolation') {
        throw new Exception('Migration is only available for legacy device-based systems');
    }

    $db->beginTransaction();

    try {
        // 检查设备是否存在（在旧表中）
        $stmt = $db->prepare('SELECT * FROM devices_backup WHERE device_uuid = ?');
        $stmt->execute([$deviceUuid]);
        $legacyDevice = $stmt->fetch();

        if (!$legacyDevice) {
            throw new Exception('Legacy device not found');
        }

        // 创建或获取目标用户
        if ($targetUserUuid) {
            $user = getOrCreateUser($targetUserUuid);
        } else {
            // 自动创建新用户
            $userUuid = generateUserUUID();
            $user = getOrCreateUser($userUuid, $legacyDevice['device_name']);
        }

        // 创建设备记录
        $device = getOrCreateDevice($deviceUuid, $user['id'], $legacyDevice['device_name'], $legacyDevice['platform']);

        // 迁移番茄事件数据
        $migratedEvents = migrateDevicePomodoroEvents($db, $deviceUuid, $user['id'], $device['id']);

        // 迁移系统事件数据
        $migratedSystemEvents = migrateDeviceSystemEvents($db, $deviceUuid, $user['id'], $device['id']);

        // 迁移计时器设置
        $migratedSettings = migrateDeviceTimerSettings($db, $deviceUuid, $user['id'], $device['id']);

        // 创建会话token
        $session = createUserSession($user['id'], $device['id']);

        $db->commit();

        logMessage("Data migration completed: device $deviceUuid -> user {$user['user_uuid']}");

        sendSuccess([
            'user_uuid' => $user['user_uuid'],
            'session_token' => $session['session_token'],
            'expires_at' => $session['expires_at'],
            'migration_summary' => [
                'migrated_events' => $migratedEvents,
                'migrated_system_events' => $migratedSystemEvents,
                'migrated_settings' => $migratedSettings
            ]
        ], 'Data migration completed successfully');

    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 迁移设备的番茄事件数据
 */
function migrateDevicePomodoroEvents($db, $deviceUuid, $userId, $deviceId) {
    $stmt = $db->prepare('
        SELECT * FROM pomodoro_events_backup
        WHERE device_uuid = ? AND deleted_at IS NULL
    ');
    $stmt->execute([$deviceUuid]);
    $events = $stmt->fetchAll();

    $migratedCount = 0;
    foreach ($events as $event) {
        try {
            $stmt = $db->prepare('
                INSERT INTO pomodoro_events
                (uuid, user_id, device_id, title, start_time, end_time, event_type, is_completed, created_at, updated_at, last_modified_device_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ');
            $stmt->execute([
                $event['uuid'],
                $userId,
                $deviceId,
                $event['title'],
                $event['start_time'],
                $event['end_time'],
                $event['event_type'],
                $event['is_completed'],
                $event['created_at'],
                $event['updated_at'],
                $deviceId
            ]);
            $migratedCount++;
        } catch (PDOException $e) {
            if ($e->getCode() != 23000) { // 忽略重复UUID错误
                throw $e;
            }
        }
    }

    return $migratedCount;
}

/**
 * 迁移设备的系统事件数据
 */
function migrateDeviceSystemEvents($db, $deviceUuid, $userId, $deviceId) {
    $stmt = $db->prepare('
        SELECT * FROM system_events_backup
        WHERE device_uuid = ? AND deleted_at IS NULL
    ');
    $stmt->execute([$deviceUuid]);
    $events = $stmt->fetchAll();

    $migratedCount = 0;
    foreach ($events as $event) {
        try {
            $stmt = $db->prepare('
                INSERT INTO system_events
                (uuid, user_id, device_id, event_type, timestamp, data, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ');
            $stmt->execute([
                $event['uuid'],
                $userId,
                $deviceId,
                $event['event_type'],
                $event['timestamp'],
                $event['data'],
                $event['created_at']
            ]);
            $migratedCount++;
        } catch (PDOException $e) {
            if ($e->getCode() != 23000) { // 忽略重复UUID错误
                throw $e;
            }
        }
    }

    return $migratedCount;
}

/**
 * 迁移设备的计时器设置
 */
function migrateDeviceTimerSettings($db, $deviceUuid, $userId, $deviceId) {
    $stmt = $db->prepare('
        SELECT * FROM timer_settings_backup
        WHERE device_uuid = ?
        ORDER BY updated_at DESC
        LIMIT 1
    ');
    $stmt->execute([$deviceUuid]);
    $settings = $stmt->fetch();

    if (!$settings) {
        return 0;
    }

    try {
        $stmt = $db->prepare('
            INSERT INTO timer_settings
            (user_id, device_id, pomodoro_time, short_break_time, long_break_time, updated_at, is_global)
            VALUES (?, NULL, ?, ?, ?, ?, 1)
        ');
        $stmt->execute([
            $userId,
            $settings['pomodoro_time'],
            $settings['short_break_time'],
            $settings['long_break_time'],
            $settings['updated_at']
        ]);
        return 1;
    } catch (PDOException $e) {
        if ($e->getCode() != 23000) { // 忽略重复错误
            throw $e;
        }
        return 0;
    }
}
?>
