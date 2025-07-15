<?php
/**
 * 基于用户账户的同步API接口
 * 替换原有的基于设备隔离的同步系统
 */

// 配置错误处理，防止警告信息污染JSON响应
// error_reporting(E_ERROR | E_PARSE); // 只报告严重错误
// ini_set('display_errors', 0); // 不显示错误到输出
// ini_set('log_errors', 1); // 记录错误到日志


// 包含必要的函数文件
require_once 'api/base.php';           // API基础函数（响应、验证等）
require_once 'includes/functions.php'; // 通用工具函数（UUID、Token生成等）
require_once 'includes/auth.php';      // 认证相关函数

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
    } elseif ($method === 'GET' && $path === '/api/user/sync/summary') {
        handleDataSummary();
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
    $pomodoroEvents = getUserPomodoroEvents($db, $userInfo['user_id']);
    $systemEvents = getUserSystemEvents($db, $userInfo['user_id']);
    $timerSettings = getUserTimerSettings($db, $userInfo['user_id']);

    // 计算数据的实际最后修改时间戳
    $serverTimestamp = calculateDataLastModifiedTimestamp($db, $userInfo['user_id'], $pomodoroEvents, $systemEvents, $timerSettings);

    $data = [
        'pomodoro_events' => $pomodoroEvents,
        'system_events' => $systemEvents,
        'timer_settings' => $timerSettings,
        'server_timestamp' => $serverTimestamp,
        'user_info' => [
            'user_uuid' => $userInfo['user_uuid'],
            'device_count' => getUserDeviceCount($db, $userInfo['user_id'])
        ]
    ];

    // 更新设备最后同步时间
    updateDeviceLastSync($db, $userInfo['device_id'], $serverTimestamp);

    error_log("Full sync completed for user: {$userInfo['user_uuid']}, device: {$userInfo['device_uuid']}, server_timestamp:$serverTimestamp");
    sendSuccess($data, 'Full sync completed');
}

/**
 * 数据摘要处理 - 轻量级数据预览
 */
function handleDataSummary() {
    $userInfo = requireAuth();

    $db = getDB();

    // 获取数据统计信息，不传输具体数据
    $pomodoroCount = getUserPomodoroEventCount($db, $userInfo['user_id']);
    $systemEventCount = getUserSystemEventCount($db, $userInfo['user_id']);
    $hasTimerSettings = hasUserTimerSettings($db, $userInfo['user_id']);

    // 计算最后修改时间戳
    $serverTimestamp = calculateDataLastModifiedTimestamp($db, $userInfo['user_id'], [], [], null);

    // 获取最近的事件信息（用于预览）
    $recentEvents = getRecentPomodoroEvents($db, $userInfo['user_id'], 5); // 最近5个事件

    $data = [
        'summary' => [
            'pomodoro_event_count' => $pomodoroCount,
            'system_event_count' => $systemEventCount,
            'has_timer_settings' => $hasTimerSettings,
            'server_timestamp' => $serverTimestamp,
            'last_updated' => @date('Y-m-d H:i:s', @$serverTimestamp / 1000)
        ],
        'recent_events' => $recentEvents,
        'user_info' => [
            'user_uuid' => $userInfo['user_uuid'],
            'device_count' => getUserDeviceCount($db, $userInfo['user_id'])
        ]
    ];

    // 更新设备最后访问时间（不是同步时间）
    updateDeviceLastAccess($db, $userInfo['device_id']);

    error_log("Data summary requested for user: {$userInfo['user_uuid']}, device: {$userInfo['device_uuid']}, server_timestamp: $serverTimestamp");
    sendSuccess($data, 'Data summary retrieved');
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

    $db = getDB();
    $db->beginTransaction();

    try {
        $conflicts = [];

        // 检查是否为强制覆盖远程操作
        if ($lastSyncTimestamp == 0) {
            logMessage("Force overwrite remote detected for user: {$userInfo['user_uuid']}");

            // 强制覆盖：清空现有数据并用客户端数据替换
            $serverTimestamp = performForceOverwriteRemote($db, $userInfo['user_id'], $userInfo['device_id'], $changes);

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

            // 计算增量同步后的实际最后修改时间戳
            $serverTimestamp = calculateIncrementalSyncTimestamp($db, $userInfo['user_id'], $changes, $serverChanges, $lastSyncTimestamp);
        }

        // 更新设备最后同步时间
        updateDeviceLastSync($db, $userInfo['device_id'], $serverTimestamp);

        $db->commit();

        error_log("Incremental sync completed for user: {$userInfo['user_uuid']}, device: {$userInfo['device_uuid']}, server_timestamp:$serverTimestamp");

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
    $events = $stmt->fetchAll();

    // 解码JSON数据字段
    foreach ($events as &$event) {
        if ($event['data']) {
            $decoded = json_decode($event['data'], true);
            $event['data'] = $decoded !== null ? $decoded : [];
        } else {
            $event['data'] = [];
        }
    }

    return $events;
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
    $result = $stmt->fetch();

    if ($result) {
        // 数据库中的 updated_at 已经是毫秒时间戳，直接转换为整数
        $result['updated_at'] = (int)$result['updated_at'];
    }

    return $result ?: null;
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
 * 计算数据的实际最后修改时间戳
 * 基于所有数据的最新修改时间来确定server_timestamp
 */
function calculateDataLastModifiedTimestamp($db, $userId, $pomodoroEvents, $systemEvents, $timerSettings) {
    $maxTimestamp = 0;

    // 检查番茄事件的最新修改时间
    foreach ($pomodoroEvents as $event) {
        $eventTimestamp = $event['updated_at'];
        if ($eventTimestamp > $maxTimestamp) {
            $maxTimestamp = $eventTimestamp;
        }
    }

    // 检查系统事件的最新创建时间
    foreach ($systemEvents as $event) {
        $eventTimestamp = $event['created_at'];
        if ($eventTimestamp > $maxTimestamp) {
            $maxTimestamp = $eventTimestamp;
        }
    }
    error_log("calculateDataLastModifiedTimestamp222 maxTimestamp:$maxTimestamp");


    // 检查计时器设置的最新修改时间
    if ($timerSettings && isset($timerSettings['updated_at'])) {
        $settingsTimestamp = $timerSettings['updated_at']; // 已经是毫秒时间戳
        if ($settingsTimestamp > $maxTimestamp) {
            $maxTimestamp = $settingsTimestamp;
        }
    }
    error_log("calculateDataLastModifiedTimestamp333 maxTimestamp:$maxTimestamp");

    // 如果没有任何数据，使用当前时间戳
    if ($maxTimestamp == 0) {
        $maxTimestamp = getServerDataMaxTimestamp($db, $userId);
    }

    error_log("calculateDataLastModifiedTimestamp maxTimestamp2:$maxTimestamp");


    return $maxTimestamp;
}

/**
 * 计算增量同步后的实际最后修改时间戳
 * 考虑客户端推送的数据和服务器端变更的最新时间
 */
function calculateIncrementalSyncTimestamp($db, $userId, $clientChanges, $serverChanges, $lastSyncTimestamp) {
    $maxTimestamp = $lastSyncTimestamp;

    // 检查客户端推送的番茄事件变更
    if (isset($clientChanges['pomodoro_events'])) {
        $pomodoroChanges = $clientChanges['pomodoro_events'];

        // 检查新创建的事件
        if (isset($pomodoroChanges['created'])) {
            foreach ($pomodoroChanges['created'] as $event) {
                if (isset($event['updated_at'])) {
                    $eventTimestamp = $event['updated_at'];
                    if ($eventTimestamp > $maxTimestamp) {
                        $maxTimestamp = $eventTimestamp;
                    }
                }
            }
        }

        // 检查更新的事件
        if (isset($pomodoroChanges['updated'])) {
            foreach ($pomodoroChanges['updated'] as $event) {
                if (isset($event['updated_at'])) {
                    $eventTimestamp = $event['updated_at'];
                    if ($eventTimestamp > $maxTimestamp) {
                        $maxTimestamp = $eventTimestamp;
                    }
                }
            }
        }
    }

    // 检查客户端推送的系统事件变更
    if (isset($clientChanges['system_events']['created'])) {
        foreach ($clientChanges['system_events']['created'] as $event) {
            if (isset($event['created_at'])) {
                $eventTimestamp = $event['created_at'];
                if ($eventTimestamp > $maxTimestamp) {
                    $maxTimestamp = $eventTimestamp;
                }
            }
        }
    }

    // 检查客户端推送的计时器设置变更
    if (isset($clientChanges['timer_settings']['updated_at'])) {
        $settingsTimestamp = $clientChanges['timer_settings']['updated_at'];
        if ($settingsTimestamp > $maxTimestamp) {
            $maxTimestamp = $settingsTimestamp;
        }
    }

    // 检查服务器端的番茄事件变更
    foreach ($serverChanges['pomodoro_events'] as $event) {
        $eventTimestamp = $event['updated_at'];
        if ($eventTimestamp > $maxTimestamp) {
            $maxTimestamp = $eventTimestamp;
        }
    }

    // 检查服务器端的系统事件变更
    foreach ($serverChanges['system_events'] as $event) {
        $eventTimestamp = $event['created_at'];
        if ($eventTimestamp > $maxTimestamp) {
            $maxTimestamp = $eventTimestamp;
        }
    }

    // 检查服务器端的计时器设置变更
    if ($serverChanges['timer_settings'] && isset($serverChanges['timer_settings']['updated_at'])) {
        // 服务器端的设置时间戳已经是毫秒格式，无需转换
        $settingsTimestamp = $serverChanges['timer_settings']['updated_at'];
        if ($settingsTimestamp > $maxTimestamp) {
            $maxTimestamp = $settingsTimestamp;
        }
    }

    // 如果没有任何变更，查询服务端数据的实际最大时间戳
    if ($maxTimestamp == $lastSyncTimestamp) {
        $maxTimestamp = getServerDataMaxTimestamp($db, $userId);
    }

    return $maxTimestamp;
}

/**
 * 获取指定时间后的用户番茄事件
 */
function getUserPomodoroEventsAfter($db, $userId, $timestamp) {
    error_log("getUserPomodoroEventsAfter timestamp: $timestamp, userId:$userId");
    // 数据库中的updated_at字段存储的就是毫秒时间戳，直接比较
    // 返回所有在指定时间戳之后更新的事件，包括已删除的事件

    $stmt = $db->prepare('
        SELECT
            uuid, title, start_time, end_time, event_type,
            is_completed, created_at, updated_at, deleted_at
        FROM pomodoro_events
        WHERE user_id = ? AND updated_at > ?
        ORDER BY updated_at ASC
    ');
    $stmt->execute([$userId, $timestamp]);
    return $stmt->fetchAll();
}

/**
 * 获取指定时间后的用户系统事件
 */
function getUserSystemEventsAfter($db, $userId, $timestamp) {
    // 数据库中的created_at字段存储的就是毫秒时间戳，直接比较

    $stmt = $db->prepare('
        SELECT
            uuid, event_type, timestamp, data, created_at
        FROM system_events
        WHERE user_id = ? AND created_at > ? AND deleted_at IS NULL
        ORDER BY created_at ASC
    ');
    $stmt->execute([$userId, $timestamp]);
    $events = $stmt->fetchAll();

    // 解码JSON数据字段
    foreach ($events as &$event) {
        if ($event['data']) {
            $decoded = json_decode($event['data'], true);
            $event['data'] = $decoded !== null ? $decoded : [];
        } else {
            $event['data'] = [];
        }
    }

    return $events;
}

/**
 * 获取指定时间后的用户计时器设置
 */
function getUserTimerSettingsAfter($db, $userId, $timestamp) {
    // 直接使用毫秒时间戳进行比较
    $stmt = $db->prepare('
        SELECT pomodoro_time, short_break_time, long_break_time, updated_at
        FROM timer_settings
        WHERE user_id = ? AND updated_at > ? AND is_global = 1
        ORDER BY updated_at DESC
        LIMIT 1
    ');
    $stmt->execute([$userId, $timestamp]);
    $result = $stmt->fetch();

    if ($result) {
        // 数据库中的 updated_at 已经是毫秒时间戳，直接转换为整数
        $result['updated_at'] = (int)$result['updated_at'];
        error_log("Found timer settings after $timestamp for user: $userId, updated_at: {$result['updated_at']}");
    }

    return $result ?: null;
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
            $currentTimestamp = getCurrentTimestamp();
            $stmt = $db->prepare('
                UPDATE pomodoro_events
                SET deleted_at = ?, updated_at = ?, last_modified_device_id = ?
                WHERE uuid = ? AND user_id = ? AND deleted_at IS NULL
            ');
            $stmt->execute([$currentTimestamp, $currentTimestamp, $deviceId, $uuid, $userId]);
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
                    is_array($event['data']) ? json_encode($event['data']) : $event['data'],
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
    // 直接使用客户端的毫秒时间戳
    $clientUpdatedAt = $settings['updated_at'];

    // 检查是否有冲突
    $stmt = $db->prepare('SELECT updated_at FROM timer_settings WHERE user_id = ? AND is_global = 1');
    $stmt->execute([$userId]);
    $serverSettings = $stmt->fetch();

    if ($serverSettings && $serverSettings['updated_at'] > $lastSyncTimestamp) {
        // 有冲突，使用最新的设置（客户端优先）
        error_log("Timer settings conflict detected for user: $userId, server: {$serverSettings['updated_at']}, client: $clientUpdatedAt, using client version");
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
        $clientUpdatedAt  // 直接使用毫秒时间戳
    ]);

    error_log("Timer settings updated for user: $userId, pomodoro: {$settings['pomodoro_time']}s, short_break: {$settings['short_break_time']}s, long_break: {$settings['long_break_time']}s, updated_at: $clientUpdatedAt");
}

/**
 * 强制覆盖远程数据
 */
function performForceOverwriteRemote($db, $userId, $deviceId, $changes) {
    $currentTimestamp = getCurrentTimestamp();

    // 清空用户数据
    clearUserData($db, $userId, $currentTimestamp);

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

    // 计算强制覆盖后的实际最后修改时间戳
    $serverTimestamp = calculateForceOverwriteTimestamp($changes, $currentTimestamp);

    logMessage("Force overwrite completed for user: $userId");

    return $serverTimestamp;
}

/**
 * 计算强制覆盖后的实际最后修改时间戳
 * 基于客户端推送的数据的最新修改时间
 */
function calculateForceOverwriteTimestamp($changes, $fallbackTimestamp) {
    $maxTimestamp = 0;

    // 检查番茄事件的最新修改时间
    if (isset($changes['pomodoro_events'])) {
        $pomodoroChanges = $changes['pomodoro_events'];

        // 检查新创建的事件
        if (isset($pomodoroChanges['created'])) {
            foreach ($pomodoroChanges['created'] as $event) {
                if (isset($event['updated_at'])) {
                    $eventTimestamp = $event['updated_at'];
                    if ($eventTimestamp > $maxTimestamp) {
                        $maxTimestamp = $eventTimestamp;
                    }
                }
            }
        }

        // 检查更新的事件
        if (isset($pomodoroChanges['updated'])) {
            foreach ($pomodoroChanges['updated'] as $event) {
                if (isset($event['updated_at'])) {
                    $eventTimestamp = $event['updated_at'];
                    if ($eventTimestamp > $maxTimestamp) {
                        $maxTimestamp = $eventTimestamp;
                    }
                }
            }
        }
    }

    // 检查系统事件的最新创建时间
    if (isset($changes['system_events']['created'])) {
        foreach ($changes['system_events']['created'] as $event) {
            if (isset($event['created_at'])) {
                $eventTimestamp = $event['created_at'];
                if ($eventTimestamp > $maxTimestamp) {
                    $maxTimestamp = $eventTimestamp;
                }
            }
        }
    }

    // 检查计时器设置的最新修改时间
    if (isset($changes['timer_settings']['updated_at'])) {
        $settingsTimestamp = $changes['timer_settings']['updated_at'];
        if ($settingsTimestamp > $maxTimestamp) {
            $maxTimestamp = $settingsTimestamp;
        }
    }

    // 如果没有任何数据，使用回退时间戳
    if ($maxTimestamp == 0) {
        $maxTimestamp = $fallbackTimestamp;
    }

    return $maxTimestamp;
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
                is_array($event['data']) ? json_encode($event['data']) : $event['data'],
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

/**
 * 获取用户番茄事件数量
 */
function getUserPomodoroEventCount($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM pomodoro_events WHERE user_id = ? AND deleted_at IS NULL');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn();
}

/**
 * 获取用户系统事件数量
 */
function getUserSystemEventCount($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM system_events WHERE user_id = ? AND deleted_at IS NULL');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn();
}

/**
 * 检查用户是否有计时器设置
 */
function hasUserTimerSettings($db, $userId) {
    $stmt = $db->prepare('SELECT COUNT(*) FROM timer_settings WHERE user_id = ? AND is_global = 1');
    $stmt->execute([$userId]);
    return (int)$stmt->fetchColumn() > 0;
}

/**
 * 获取用户最近的番茄事件（用于预览）
 */
function getRecentPomodoroEvents($db, $userId, $limit = 5) {
    $stmt = $db->prepare('
        SELECT
            uuid, title, start_time, end_time, event_type,
            is_completed, created_at, updated_at
        FROM pomodoro_events
        WHERE user_id = ? AND deleted_at IS NULL
        ORDER BY start_time DESC
        LIMIT ?
    ');
    $stmt->execute([$userId, $limit]);
    return $stmt->fetchAll();
}

/**
 * 更新设备最后访问时间（不是同步时间）
 */
function updateDeviceLastAccess($db, $deviceId) {
    $stmt = $db->prepare('UPDATE devices SET last_access_timestamp = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?');
    $stmt->execute([getCurrentTimestamp(), $deviceId]);
}

/**
 * 获取服务端数据的实际最大时间戳
 * 查询用户所有数据的最新修改时间
 */
function getServerDataMaxTimestamp($db, $userId) {
    $maxTimestamp = 0;

    // 查询番茄事件的最大时间戳
    $stmt = $db->prepare('SELECT MAX(updated_at) as max_timestamp FROM pomodoro_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result && $result['max_timestamp']) {
        $maxTimestamp = max($maxTimestamp, $result['max_timestamp']);
    }

    // 查询系统事件的最大时间戳
    $stmt = $db->prepare('SELECT MAX(created_at) as max_timestamp FROM system_events WHERE user_id = ?');
    $stmt->execute([$userId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result && $result['max_timestamp']) {
        $maxTimestamp = max($maxTimestamp, $result['max_timestamp']);
    }

    // 查询计时器设置的最大时间戳
    $stmt = $db->prepare('SELECT MAX(updated_at) as max_timestamp FROM timer_settings WHERE user_id = ?');
    $stmt->execute([$userId]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($result && $result['max_timestamp']) {
        $maxTimestamp = max($maxTimestamp, $result['max_timestamp']);
    }

    error_log("maxTimestamp: $maxTimestamp");
    // 如果没有任何数据，返回0
    return $maxTimestamp;
}
?>
