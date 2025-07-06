<?php
/**
 * 设备注册API - 向后兼容版本
 * 自动检测数据库版本并重定向到相应的认证系统
 */

require_once '../config/database.php';
require_once '../includes/functions.php';
require_once '../includes/auth.php';

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
    $data = getRequestData();
    
    // 检查数据库版本
    $dbVersion = Database::getInstance()->getDatabaseVersion();

    if ($dbVersion['type'] === 'user_system') {
        // 新版本：重定向到用户认证系统
        handleUserSystemDeviceRegistration($data);
    } else {
        // 旧版本：使用传统设备注册
        handleLegacyDeviceRegistration($data);
    }

} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    sendError($e->getMessage(), $code);
}

/**
 * 处理用户系统的设备注册（重定向到认证API）
 */
function handleUserSystemDeviceRegistration($data) {
    // 验证必需参数
    validateRequired($data, ['device_uuid', 'device_name', 'platform']);

    $deviceUuid = $data['device_uuid'];
    $deviceName = $data['device_name'];
    $platform = $data['platform'];

    // 验证UUID格式
    if (!validateUUID($deviceUuid)) {
        throw new Exception('Invalid device UUID format');
    }

    // 验证平台
    $validPlatforms = ['macOS', 'iOS'];
    if (!in_array($platform, $validPlatforms)) {
        throw new Exception('Invalid platform. Must be one of: ' . implode(', ', $validPlatforms));
    }

    $db = getDB();
    $db->beginTransaction();

    try {
        // 检查设备是否已存在
        $stmt = $db->prepare('SELECT d.*, u.user_uuid FROM devices d JOIN users u ON d.user_id = u.id WHERE d.device_uuid = ?');
        $stmt->execute([$deviceUuid]);
        $existingDevice = $stmt->fetch();

        if ($existingDevice) {
            // 设备已存在，返回现有用户信息
            $user = getOrCreateUser($existingDevice['user_uuid']);
            $device = getOrCreateDevice($deviceUuid, $user['id'], $deviceName, $platform);
            $session = createUserSession($user['id'], $device['id']);

            $db->commit();

            logMessage("Device re-registered: $deviceUuid for user: {$user['user_uuid']}");

            // 返回兼容格式的响应
            sendSuccess([
                'device_uuid' => $deviceUuid,
                'last_sync_timestamp' => $device['last_sync_timestamp'],
                'status' => 'updated',
                // 新增字段
                'user_uuid' => $user['user_uuid'],
                'session_token' => $session['session_token'],
                'expires_at' => $session['expires_at'],
                'migration_required' => false
            ], 'Device registered successfully');

        } else {
            // 新设备，创建新用户
            $userUuid = generateUserUUID();
            $user = getOrCreateUser($userUuid, $deviceName);
            $device = getOrCreateDevice($deviceUuid, $user['id'], $deviceName, $platform);
            $session = createUserSession($user['id'], $device['id']);

            $db->commit();

            logMessage("New device registered: $deviceUuid with new user: $userUuid");

            // 返回兼容格式的响应
            sendSuccess([
                'device_uuid' => $deviceUuid,
                'last_sync_timestamp' => 0,
                'status' => 'created',
                // 新增字段
                'user_uuid' => $user['user_uuid'],
                'session_token' => $session['session_token'],
                'expires_at' => $session['expires_at'],
                'migration_required' => false
            ], 'Device registered successfully');
        }

    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 处理传统设备注册（旧版本兼容）
 */
function handleLegacyDeviceRegistration($data) {
    // 验证必需参数
    validateRequired($data, ['device_uuid', 'device_name', 'platform']);

    $device_uuid = $data['device_uuid'];
    $device_name = $data['device_name'];
    $platform = $data['platform'];

    // 验证UUID格式
    if (!validateUUID($device_uuid)) {
        throw new Exception('Invalid device UUID format');
    }

    // 验证平台
    $valid_platforms = ['macOS', 'iOS'];
    if (!in_array($platform, $valid_platforms)) {
        throw new Exception('Invalid platform. Must be one of: ' . implode(', ', $valid_platforms));
    }

    $db = getDB();

    // 检查设备是否已存在
    $stmt = $db->prepare('SELECT device_uuid, last_sync_timestamp FROM devices WHERE device_uuid = ?');
    $stmt->execute([$device_uuid]);
    $existing_device = $stmt->fetch();

    if ($existing_device) {
        // 设备已存在，更新信息
        $stmt = $db->prepare('
            UPDATE devices
            SET device_name = ?, platform = ?, updated_at = CURRENT_TIMESTAMP
            WHERE device_uuid = ?
        ');
        $stmt->execute([$device_name, $platform, $device_uuid]);

        logMessage("Device updated: $device_uuid ($device_name)");

        sendSuccess([
            'device_uuid' => $device_uuid,
            'last_sync_timestamp' => $existing_device['last_sync_timestamp'],
            'status' => 'updated',
            'migration_required' => true // 提示需要迁移到用户系统
        ], 'Device information updated');
    } else {
        // 新设备注册
        $stmt = $db->prepare('
            INSERT INTO devices (device_uuid, device_name, platform, last_sync_timestamp)
            VALUES (?, ?, ?, 0)
        ');
        $stmt->execute([$device_uuid, $device_name, $platform]);

        logMessage("New device registered: $device_uuid ($device_name)");

        sendSuccess([
            'device_uuid' => $device_uuid,
            'last_sync_timestamp' => 0,
            'status' => 'registered',
            'migration_required' => true // 提示需要迁移到用户系统
        ], 'Device registered successfully');
    }
}
?>
