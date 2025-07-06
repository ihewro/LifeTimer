<?php
/**
 * 用户管理API接口
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
    $method = $_SERVER['REQUEST_METHOD'];
    $path = $_SERVER['PATH_INFO'] ?? '';
    
    // 路由处理
    switch ($path) {
        case '/profile':
            if ($method === 'GET') {
                handleGetProfile();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        case '/devices':
            if ($method === 'GET') {
                handleGetDevices();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        case '/devices/remove':
            if ($method === 'POST') {
                handleRemoveDevice();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        case '/sessions':
            if ($method === 'GET') {
                handleGetSessions();
            } elseif ($method === 'DELETE') {
                handleRevokeAllSessions();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        default:
            throw new Exception('Endpoint not found', 404);
    }
    
} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    sendError($e->getMessage(), $code);
}

/**
 * 获取用户资料
 */
function handleGetProfile() {
    $userInfo = requireAuth();
    
    $db = getDB();
    
    // 获取用户详细信息
    $stmt = $db->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$userInfo['user_id']]);
    $user = $stmt->fetch();
    
    if (!$user) {
        throw new Exception('User not found');
    }
    
    // 获取用户设备列表
    $devices = getUserDevices($userInfo['user_id']);
    
    // 标记当前设备
    foreach ($devices as &$device) {
        $device['is_current'] = ($device['device_uuid'] === $userInfo['device_uuid']);
    }
    
    // 获取统计信息
    $stats = getUserStats($userInfo['user_id']);
    
    sendSuccess([
        'user_uuid' => $user['user_uuid'],
        'user_name' => $user['user_name'],
        'email' => $user['email'],
        'created_at' => $user['created_at'],
        'last_active_at' => $user['last_active_at'],
        'devices' => $devices,
        'stats' => $stats
    ], 'Profile retrieved successfully');
}

/**
 * 获取用户设备列表
 */
function handleGetDevices() {
    $userInfo = requireAuth();
    
    $devices = getUserDevices($userInfo['user_id']);
    
    // 标记当前设备
    foreach ($devices as &$device) {
        $device['is_current'] = ($device['device_uuid'] === $userInfo['device_uuid']);
    }
    
    sendSuccess($devices, 'Devices retrieved successfully');
}

/**
 * 移除设备
 */
function handleRemoveDevice() {
    $userInfo = requireAuth();
    $data = getRequestData();
    
    validateRequired($data, ['device_uuid']);
    $deviceUuid = $data['device_uuid'];
    
    // 不能删除当前设备
    if ($deviceUuid === $userInfo['device_uuid']) {
        throw new Exception('Cannot remove current device');
    }
    
    $db = getDB();
    $db->beginTransaction();
    
    try {
        // 检查设备是否属于当前用户
        $stmt = $db->prepare('SELECT id FROM devices WHERE device_uuid = ? AND user_id = ?');
        $stmt->execute([$deviceUuid, $userInfo['user_id']]);
        $device = $stmt->fetch();
        
        if (!$device) {
            throw new Exception('Device not found or not owned by user');
        }
        
        $deviceId = $device['id'];
        
        // 撤销该设备的所有会话
        $stmt = $db->prepare('UPDATE user_sessions SET is_active = 0 WHERE device_id = ?');
        $stmt->execute([$deviceId]);
        
        // 标记设备为非活跃
        $stmt = $db->prepare('UPDATE devices SET is_active = 0 WHERE id = ?');
        $stmt->execute([$deviceId]);
        
        $db->commit();
        
        logMessage("Device removed: $deviceUuid by user: {$userInfo['user_uuid']}");
        
        sendSuccess([], 'Device removed successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 获取用户会话列表
 */
function handleGetSessions() {
    $userInfo = requireAuth();
    
    $db = getDB();
    
    $stmt = $db->prepare('
        SELECT 
            s.session_token,
            s.expires_at,
            s.created_at,
            s.last_used_at,
            s.is_active,
            d.device_uuid,
            d.device_name,
            d.platform
        FROM user_sessions s
        JOIN devices d ON s.device_id = d.id
        WHERE s.user_id = ? AND s.is_active = 1
        ORDER BY s.last_used_at DESC
    ');
    
    $stmt->execute([$userInfo['user_id']]);
    $sessions = $stmt->fetchAll();
    
    // 标记当前会话
    $currentToken = getAuthTokenFromHeader();
    foreach ($sessions as &$session) {
        $session['is_current'] = ($session['session_token'] === $currentToken);
        // 不返回完整的token，只返回部分用于识别
        $session['session_token'] = substr($session['session_token'], 0, 8) . '...';
    }
    
    sendSuccess($sessions, 'Sessions retrieved successfully');
}

/**
 * 撤销所有会话（除当前会话外）
 */
function handleRevokeAllSessions() {
    $userInfo = requireAuth();
    
    $db = getDB();
    
    $currentToken = getAuthTokenFromHeader();
    
    $stmt = $db->prepare('
        UPDATE user_sessions 
        SET is_active = 0 
        WHERE user_id = ? AND session_token != ? AND is_active = 1
    ');
    
    $stmt->execute([$userInfo['user_id'], $currentToken]);
    $revokedCount = $stmt->rowCount();
    
    logMessage("Revoked $revokedCount sessions for user: {$userInfo['user_uuid']}");
    
    sendSuccess([
        'revoked_count' => $revokedCount
    ], 'Sessions revoked successfully');
}

/**
 * 获取用户统计信息
 */
function getUserStats($userId) {
    $db = getDB();
    
    // 番茄事件统计
    $stmt = $db->prepare('
        SELECT 
            COUNT(*) as total_events,
            COUNT(CASE WHEN is_completed = 1 THEN 1 END) as completed_events,
            COUNT(CASE WHEN event_type = "pomodoro" THEN 1 END) as pomodoro_count,
            COUNT(CASE WHEN event_type = "break" THEN 1 END) as break_count
        FROM pomodoro_events 
        WHERE user_id = ? AND deleted_at IS NULL
    ');
    $stmt->execute([$userId]);
    $pomodoroStats = $stmt->fetch();
    
    // 系统事件统计
    $stmt = $db->prepare('SELECT COUNT(*) as total_system_events FROM system_events WHERE user_id = ? AND deleted_at IS NULL');
    $stmt->execute([$userId]);
    $systemStats = $stmt->fetch();
    
    // 最近活动
    $stmt = $db->prepare('
        SELECT created_at 
        FROM pomodoro_events 
        WHERE user_id = ? AND deleted_at IS NULL 
        ORDER BY created_at DESC 
        LIMIT 1
    ');
    $stmt->execute([$userId]);
    $lastActivity = $stmt->fetchColumn();
    
    return [
        'total_pomodoro_events' => (int)$pomodoroStats['total_events'],
        'completed_pomodoro_events' => (int)$pomodoroStats['completed_events'],
        'pomodoro_count' => (int)$pomodoroStats['pomodoro_count'],
        'break_count' => (int)$pomodoroStats['break_count'],
        'total_system_events' => (int)$systemStats['total_system_events'],
        'last_activity' => $lastActivity
    ];
}
?>
