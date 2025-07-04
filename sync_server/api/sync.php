<?php
// 同步API处理

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

try {
    if ($method === 'GET' && strpos($path, '/api/sync/full') !== false) {
        handleFullSync();
    } elseif ($method === 'POST' && strpos($path, '/api/sync/incremental') !== false) {
        handleIncrementalSync();
    } else {
        throw new Exception('Invalid sync endpoint');
    }
} catch (Exception $e) {
    logMessage("Sync error: " . $e->getMessage(), 'ERROR');
    sendError($e->getMessage());
}

// 全量同步处理
function handleFullSync() {
    $device_uuid = $_GET['device_uuid'] ?? '';
    
    if (empty($device_uuid)) {
        throw new Exception('device_uuid parameter is required');
    }
    
    validateDevice($device_uuid);
    
    $db = getDB();
    
    // 获取所有数据
    $data = [
        'pomodoro_events' => getPomodoroEvents($db, $device_uuid),
        'system_events' => getSystemEvents($db, $device_uuid),
        'timer_settings' => getTimerSettings($db, $device_uuid),
        'server_timestamp' => getCurrentTimestamp()
    ];
    
    // 更新设备最后同步时间
    updateDeviceLastSync($db, $device_uuid, $data['server_timestamp']);
    
    logMessage("Full sync completed for device: $device_uuid");
    sendSuccess($data, 'Full sync completed');
}

// 增量同步处理
function handleIncrementalSync() {
    $data = getRequestData();
    
    validateRequired($data, ['device_uuid', 'last_sync_timestamp']);
    
    $device_uuid = $data['device_uuid'];
    $last_sync_timestamp = $data['last_sync_timestamp'];
    $changes = $data['changes'] ?? [];
    
    validateDevice($device_uuid);
    
    $db = getDB();
    
    // 开始事务
    $db->beginTransaction();
    
    try {
        $conflicts = [];
        $server_timestamp = getCurrentTimestamp();

        // 检查是否为强制覆盖远程操作（lastSyncTimestamp = 0）
        if ($last_sync_timestamp == 0) {
            logMessage("Force overwrite remote detected for device: $device_uuid");

            // 强制覆盖：清空现有数据并用客户端数据替换
            performForceOverwriteRemote($db, $device_uuid, $changes, $server_timestamp);

            // 强制覆盖后不返回服务器变更，因为服务器数据已被完全替换
            $server_changes = [
                'pomodoro_events' => [],
                'system_events' => [],
                'timer_settings' => null
            ];
        } else {
            // 正常增量同步
            // 处理客户端变更
            if (isset($changes['pomodoro_events'])) {
                $conflicts = array_merge($conflicts,
                    processPomodoroEventChanges($db, $device_uuid, $changes['pomodoro_events'], $last_sync_timestamp)
                );
            }

            if (isset($changes['system_events'])) {
                processSystemEventChanges($db, $device_uuid, $changes['system_events']);
            }

            if (isset($changes['timer_settings'])) {
                processTimerSettingsChanges($db, $device_uuid, $changes['timer_settings'], $last_sync_timestamp);
            }

            // 获取服务器端的变更
            $server_changes = [
                'pomodoro_events' => getPomodoroEventsAfter($db, $device_uuid, $last_sync_timestamp),
                'system_events' => getSystemEventsAfter($db, $device_uuid, $last_sync_timestamp),
                'timer_settings' => getTimerSettingsAfter($db, $device_uuid, $last_sync_timestamp)
            ];
        }
        
        // 更新设备最后同步时间
        updateDeviceLastSync($db, $device_uuid, $server_timestamp);
        
        $db->commit();
        
        logMessage("Incremental sync completed for device: $device_uuid");
        
        sendSuccess([
            'conflicts' => $conflicts,
            'server_changes' => $server_changes,
            'server_timestamp' => $server_timestamp
        ], 'Incremental sync completed');
        
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
}

// 获取番茄事件
function getPomodoroEvents($db, $device_uuid, $after_timestamp = null) {
    $sql = 'SELECT * FROM pomodoro_events WHERE device_uuid = ? AND deleted_at IS NULL';
    $params = [$device_uuid];
    
    if ($after_timestamp !== null) {
        $sql .= ' AND updated_at > ?';
        $params[] = $after_timestamp;
    }
    
    $sql .= ' ORDER BY updated_at ASC';
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    
    return $stmt->fetchAll();
}

function getPomodoroEventsAfter($db, $device_uuid, $timestamp) {
    return getPomodoroEvents($db, $device_uuid, $timestamp);
}

// 获取系统事件
function getSystemEvents($db, $device_uuid, $after_timestamp = null) {
    $sql = 'SELECT * FROM system_events WHERE device_uuid = ? AND deleted_at IS NULL';
    $params = [$device_uuid];
    
    if ($after_timestamp !== null) {
        $sql .= ' AND created_at > ?';
        $params[] = $after_timestamp;
    }
    
    $sql .= ' ORDER BY timestamp ASC LIMIT 1000'; // 限制返回数量
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    
    return $stmt->fetchAll();
}

function getSystemEventsAfter($db, $device_uuid, $timestamp) {
    return getSystemEvents($db, $device_uuid, $timestamp);
}

// 获取计时器设置
function getTimerSettings($db, $device_uuid, $after_timestamp = null) {
    $sql = 'SELECT * FROM timer_settings WHERE device_uuid = ?';
    $params = [$device_uuid];
    
    if ($after_timestamp !== null) {
        $sql .= ' AND updated_at > ?';
        $params[] = $after_timestamp;
    }
    
    $sql .= ' ORDER BY updated_at DESC LIMIT 1';
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    
    return $stmt->fetch() ?: null;
}

function getTimerSettingsAfter($db, $device_uuid, $timestamp) {
    return getTimerSettings($db, $device_uuid, $timestamp);
}

// 更新设备最后同步时间
function updateDeviceLastSync($db, $device_uuid, $timestamp) {
    $stmt = $db->prepare('UPDATE devices SET last_sync_timestamp = ?, updated_at = CURRENT_TIMESTAMP WHERE device_uuid = ?');
    $stmt->execute([$timestamp, $device_uuid]);
}

// 处理番茄事件变更
function processPomodoroEventChanges($db, $device_uuid, $changes, $last_sync_timestamp) {
    $conflicts = [];

    // 处理新创建的事件
    if (isset($changes['created'])) {
        foreach ($changes['created'] as $event) {
            try {
                $stmt = $db->prepare('
                    INSERT INTO pomodoro_events
                    (uuid, device_uuid, title, start_time, end_time, event_type, is_completed, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ');
                $stmt->execute([
                    $event['uuid'],
                    $device_uuid,
                    $event['title'],
                    $event['start_time'],
                    $event['end_time'],
                    $event['event_type'],
                    $event['is_completed'] ? 1 : 0,
                    $event['created_at'],
                    $event['updated_at']
                ]);
            } catch (PDOException $e) {
                if ($e->getCode() == 23000) { // UNIQUE constraint failed
                    // UUID冲突，记录为冲突
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
            $stmt = $db->prepare('SELECT updated_at FROM pomodoro_events WHERE uuid = ? AND device_uuid = ?');
            $stmt->execute([$event['uuid'], $device_uuid]);
            $server_event = $stmt->fetch();

            if ($server_event && $server_event['updated_at'] > $last_sync_timestamp) {
                // 服务器端有更新的版本，产生冲突
                if ($server_event['updated_at'] > $event['updated_at']) {
                    $conflicts[] = [
                        'type' => 'pomodoro_event',
                        'uuid' => $event['uuid'],
                        'reason' => 'server_newer',
                        'server_updated_at' => $server_event['updated_at'],
                        'client_updated_at' => $event['updated_at']
                    ];
                    continue; // 跳过更新，保留服务器版本
                }
            }

            // 更新事件
            $stmt = $db->prepare('
                UPDATE pomodoro_events
                SET title = ?, start_time = ?, end_time = ?, event_type = ?, is_completed = ?, updated_at = ?
                WHERE uuid = ? AND device_uuid = ?
            ');
            $stmt->execute([
                $event['title'],
                $event['start_time'],
                $event['end_time'],
                $event['event_type'],
                $event['is_completed'] ? 1 : 0,
                $event['updated_at'],
                $event['uuid'],
                $device_uuid
            ]);
        }
    }

    // 处理删除的事件
    if (isset($changes['deleted'])) {
        foreach ($changes['deleted'] as $uuid) {
            $stmt = $db->prepare('
                UPDATE pomodoro_events
                SET deleted_at = ?
                WHERE uuid = ? AND device_uuid = ? AND deleted_at IS NULL
            ');
            $stmt->execute([getCurrentTimestamp(), $uuid, $device_uuid]);
        }
    }

    return $conflicts;
}

// 处理系统事件变更（只允许创建）
function processSystemEventChanges($db, $device_uuid, $changes) {
    if (isset($changes['created'])) {
        foreach ($changes['created'] as $event) {
            try {
                $stmt = $db->prepare('
                    INSERT INTO system_events
                    (uuid, device_uuid, event_type, timestamp, data, created_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                ');
                $stmt->execute([
                    $event['uuid'],
                    $device_uuid,
                    $event['event_type'],
                    $event['timestamp'],
                    isset($event['data']) ? json_encode($event['data']) : null,
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

// 处理计时器设置变更
function processTimerSettingsChanges($db, $device_uuid, $settings, $last_sync_timestamp) {
    // 检查是否有更新的服务器版本
    $stmt = $db->prepare('SELECT updated_at FROM timer_settings WHERE device_uuid = ? ORDER BY updated_at DESC LIMIT 1');
    $stmt->execute([$device_uuid]);
    $server_settings = $stmt->fetch();

    if ($server_settings && $server_settings['updated_at'] > $last_sync_timestamp) {
        // 服务器有更新的版本，检查时间戳
        if ($server_settings['updated_at'] > $settings['updated_at']) {
            return; // 保留服务器版本
        }
    }

    // 更新或插入设置
    $stmt = $db->prepare('
        INSERT OR REPLACE INTO timer_settings
        (device_uuid, pomodoro_time, short_break_time, long_break_time, updated_at)
        VALUES (?, ?, ?, ?, ?)
    ');
    $stmt->execute([
        $device_uuid,
        $settings['pomodoro_time'],
        $settings['short_break_time'],
        $settings['long_break_time'],
        $settings['updated_at']
    ]);
}

// 强制覆盖远程数据
function performForceOverwriteRemote($db, $device_uuid, $changes, $server_timestamp) {
    logMessage("Performing force overwrite remote for device: $device_uuid");

    // 1. 清空该设备的所有现有数据（软删除）
    clearDeviceData($db, $device_uuid, $server_timestamp);

    // 2. 插入客户端发送的所有数据
    if (isset($changes['pomodoro_events']['created'])) {
        foreach ($changes['pomodoro_events']['created'] as $event) {
            $stmt = $db->prepare('
                INSERT INTO pomodoro_events
                (uuid, device_uuid, title, start_time, end_time, event_type, is_completed, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ');
            $stmt->execute([
                $event['uuid'],
                $device_uuid,
                $event['title'],
                $event['start_time'],
                $event['end_time'],
                $event['event_type'],
                $event['is_completed'] ? 1 : 0,
                $event['created_at'],
                $event['updated_at']
            ]);
        }
    }

    if (isset($changes['system_events']['created'])) {
        foreach ($changes['system_events']['created'] as $event) {
            $stmt = $db->prepare('
                INSERT INTO system_events
                (uuid, device_uuid, event_type, timestamp, data, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            ');
            $stmt->execute([
                $event['uuid'],
                $device_uuid,
                $event['event_type'],
                $event['timestamp'],
                isset($event['data']) ? json_encode($event['data']) : null,
                $event['created_at']
            ]);
        }
    }

    if (isset($changes['timer_settings'])) {
        $settings = $changes['timer_settings'];
        $stmt = $db->prepare('
            INSERT OR REPLACE INTO timer_settings
            (device_uuid, pomodoro_time, short_break_time, long_break_time, updated_at)
            VALUES (?, ?, ?, ?, ?)
        ');
        $stmt->execute([
            $device_uuid,
            $settings['pomodoro_time'],
            $settings['short_break_time'],
            $settings['long_break_time'],
            $settings['updated_at']
        ]);
    }

    logMessage("Force overwrite remote completed for device: $device_uuid");
}

// 清空设备数据（硬删除，用于强制覆盖）
function clearDeviceData($db, $device_uuid, $timestamp) {
    // 硬删除所有番茄事件（强制覆盖时需要完全清空以避免UUID冲突）
    $stmt = $db->prepare('DELETE FROM pomodoro_events WHERE device_uuid = ?');
    $stmt->execute([$device_uuid]);

    // 硬删除所有系统事件
    $stmt = $db->prepare('DELETE FROM system_events WHERE device_uuid = ?');
    $stmt->execute([$device_uuid]);

    // 删除计时器设置
    $stmt = $db->prepare('DELETE FROM timer_settings WHERE device_uuid = ?');
    $stmt->execute([$device_uuid]);

    logMessage("Hard deleted all existing data for device: $device_uuid (force overwrite)");
}
?>
