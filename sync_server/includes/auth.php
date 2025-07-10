<?php
/**
 * 用户认证相关函数
 */

/**
 * 生成会话token
 */
function generateSessionToken() {
    return bin2hex(random_bytes(32));
}

/**
 * 生成用户UUID
 */
function generateUserUUID() {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

/**
 * 验证UUID格式
 */
if (!function_exists('validateUUID')) {
    function validateUUID($uuid) {
        return preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $uuid);
    }
}

/**
 * 密码哈希
 */
function hashPassword($password) {
    return password_hash($password, PASSWORD_DEFAULT);
}

/**
 * 验证密码
 */
function verifyPassword($password, $hash) {
    return password_verify($password, $hash);
}

/**
 * 从请求头获取认证token
 */
function getAuthTokenFromHeader() {
    $headers = getallheaders();
    
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $matches[1];
        }
    }
    
    return null;
}

/**
 * 验证会话token并获取用户信息
 */
function validateSessionToken($token) {
    if (empty($token)) {
        return null;
    }
    
    $db = getDB();
    
    $stmt = $db->prepare('
        SELECT 
            s.user_id,
            s.device_id,
            s.expires_at,
            s.is_active,
            u.user_uuid,
            u.user_name,
            d.device_uuid,
            d.device_name,
            d.platform
        FROM user_sessions s
        JOIN users u ON s.user_id = u.id
        JOIN devices d ON s.device_id = d.id
        WHERE s.session_token = ? AND s.is_active = 1
    ');
    
    $stmt->execute([$token]);
    $session = $stmt->fetch();
    
    if (!$session) {
        return null;
    }
    
    // 检查token是否过期
    $expiresAt = new DateTime($session['expires_at']);
    if ($expiresAt < new DateTime()) {
        // Token过期，标记为无效
        $stmt = $db->prepare('UPDATE user_sessions SET is_active = 0 WHERE session_token = ?');
        $stmt->execute([$token]);
        return null;
    }
    
    // 更新最后使用时间
    $stmt = $db->prepare('UPDATE user_sessions SET last_used_at = CURRENT_TIMESTAMP WHERE session_token = ?');
    $stmt->execute([$token]);
    
    return [
        'user_id' => $session['user_id'],
        'user_uuid' => $session['user_uuid'],
        'user_name' => $session['user_name'],
        'device_id' => $session['device_id'],
        'device_uuid' => $session['device_uuid'],
        'device_name' => $session['device_name'],
        'platform' => $session['platform']
    ];
}

/**
 * 创建用户会话
 */
function createUserSession($userId, $deviceId, $expiresInHours = 24) {
    $db = getDB();
    
    $token = generateSessionToken();
    $expiresAt = new DateTime();
    $expiresAt->add(new DateInterval("PT{$expiresInHours}H"));
    
    $stmt = $db->prepare('
        INSERT INTO user_sessions (user_id, device_id, session_token, expires_at)
        VALUES (?, ?, ?, ?)
    ');
    
    $stmt->execute([
        $userId,
        $deviceId,
        $token,
        $expiresAt->format('Y-m-d H:i:s')
    ]);
    
    return [
        'session_token' => $token,
        'expires_at' => $expiresAt->format('c')
    ];
}

/**
 * 撤销用户会话
 */
function revokeUserSession($token) {
    $db = getDB();
    
    $stmt = $db->prepare('UPDATE user_sessions SET is_active = 0 WHERE session_token = ?');
    $stmt->execute([$token]);
    
    return $stmt->rowCount() > 0;
}

/**
 * 撤销用户的所有会话
 */
function revokeAllUserSessions($userId) {
    $db = getDB();
    
    $stmt = $db->prepare('UPDATE user_sessions SET is_active = 0 WHERE user_id = ?');
    $stmt->execute([$userId]);
    
    return $stmt->rowCount();
}

/**
 * 清理过期的会话
 */
function cleanupExpiredSessions() {
    $db = getDB();
    
    $stmt = $db->prepare('UPDATE user_sessions SET is_active = 0 WHERE expires_at < CURRENT_TIMESTAMP');
    $stmt->execute();
    
    return $stmt->rowCount();
}

/**
 * 获取或创建用户
 */
function getOrCreateUser($userUuid, $userName = null, $email = null) {
    $db = getDB();
    
    // 先尝试获取现有用户
    $stmt = $db->prepare('SELECT * FROM users WHERE user_uuid = ?');
    $stmt->execute([$userUuid]);
    $user = $stmt->fetch();
    
    if ($user) {
        // 更新最后活跃时间
        $stmt = $db->prepare('UPDATE users SET last_active_at = CURRENT_TIMESTAMP WHERE id = ?');
        $stmt->execute([$user['id']]);
        return $user;
    }
    
    // 创建新用户
    $stmt = $db->prepare('
        INSERT INTO users (user_uuid, user_name, email, created_at, updated_at, last_active_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ');
    
    $stmt->execute([$userUuid, $userName, $email]);
    
    // 返回新创建的用户
    $userId = $db->lastInsertId();
    $stmt = $db->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    
    return $stmt->fetch();
}

/**
 * 获取或创建设备
 */
function getOrCreateDevice($deviceUuid, $userId, $deviceName = null, $platform = null) {
    $db = getDB();
    
    // 先尝试获取现有设备
    $stmt = $db->prepare('SELECT * FROM devices WHERE device_uuid = ?');
    $stmt->execute([$deviceUuid]);
    $device = $stmt->fetch();
    
    if ($device) {
        // 检查设备是否属于正确的用户
        if ($device['user_id'] != $userId) {
            throw new Exception('Device belongs to another user'.$device['user_id']);
        }
        
        // 更新设备信息
        $stmt = $db->prepare('
            UPDATE devices 
            SET device_name = COALESCE(?, device_name),
                platform = COALESCE(?, platform),
                updated_at = CURRENT_TIMESTAMP,
                is_active = 1
            WHERE id = ?
        ');
        $stmt->execute([$deviceName, $platform, $device['id']]);
        
        return $device;
    }
    
    // 创建新设备
    $stmt = $db->prepare('
        INSERT INTO devices (device_uuid, user_id, device_name, platform, created_at, updated_at, is_active)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1)
    ');
    
    $stmt->execute([$deviceUuid, $userId, $deviceName, $platform]);
    
    // 返回新创建的设备
    $deviceId = $db->lastInsertId();
    $stmt = $db->prepare('SELECT * FROM devices WHERE id = ?');
    $stmt->execute([$deviceId]);
    
    return $stmt->fetch();
}

/**
 * 验证用户权限（中间件函数）
 */
function requireAuth() {
    $token = getAuthTokenFromHeader();
    $userInfo = validateSessionToken($token);
    
    if (!$userInfo) {
        http_response_code(401);
        sendError('Authentication required', 401);
        exit;
    }
    
    return $userInfo;
}

/**
 * 获取用户的所有设备
 */
function getUserDevices($userId) {
    $db = getDB();
    
    $stmt = $db->prepare('
        SELECT 
            device_uuid,
            device_name,
            platform,
            last_sync_timestamp,
            created_at,
            updated_at,
            is_active
        FROM devices 
        WHERE user_id = ? 
        ORDER BY last_sync_timestamp DESC
    ');
    
    $stmt->execute([$userId]);
    
    return $stmt->fetchAll();
}
?>
