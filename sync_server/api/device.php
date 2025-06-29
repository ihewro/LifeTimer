<?php
// 设备注册API
try {
    $data = getRequestData();
    
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
            'status' => 'updated'
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
            'status' => 'registered'
        ], 'Device registered successfully');
    }
    
} catch (Exception $e) {
    logMessage("Device registration error: " . $e->getMessage(), 'ERROR');
    sendError($e->getMessage());
}
?>
