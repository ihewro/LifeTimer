<?php
/**
 * 用户认证API接口
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/base.php';
require_once __DIR__ . '/../includes/auth.php';

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

    // 提取API端点
    if (preg_match('/\/api\/auth\/(.+)$/', $path, $matches)) {
        $endpoint = $matches[1];
    } else {
        throw new Exception('Invalid API endpoint');
    }

    // 路由处理
    switch ($endpoint) {
        case 'device-init':
            if ($method === 'POST') {
                handleDeviceInit();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        case 'device-bind':
            if ($method === 'POST') {
                handleDeviceBind();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;

        case 'device-unbind':
            if ($method === 'POST') {
                handleDeviceUnbind();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;

        case 'token-refresh':
            if ($method === 'POST') {
                handleTokenRefresh();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        case '/logout':
            if ($method === 'POST') {
                handleLogout();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        case '/register':
            if ($method === 'POST') {
                handleUserRegister();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        case '/login':
            if ($method === 'POST') {
                handleUserLogin();
            } else {
                throw new Exception('Method not allowed', 405);
            }
            break;
            
        default:
            throw new Exception('Endpoint not found', 404);
    }
    
} catch (Exception $e) {
    $code = is_numeric($e->getCode()) ? (int)$e->getCode() : 500;
    if ($code < 100 || $code > 599) {
        $code = 500;
    }
    sendError($e->getMessage(), $code);
}

/**
 * 设备初始化（简化认证流程）
 */
function handleDeviceInit() {
    $data = getRequestData();
    
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
            
            logMessage("Device re-initialized: $deviceUuid for user: {$user['user_uuid']}");
            
            sendSuccess([
                'user_uuid' => $user['user_uuid'],
                'session_token' => $session['session_token'],
                'expires_at' => $session['expires_at'],
                'is_new_user' => false,
                'user_info' => [
                    'user_uuid' => $user['user_uuid'],
                    'user_name' => $user['user_name'],
                    'email' => $user['email'],
                    'created_at' => $user['created_at']
                ]
            ], 'Device initialized successfully');
            
        } else {
            // 新设备，创建新用户
            $userUuid = generateUserUUID();
            $user = getOrCreateUser($userUuid, $deviceName);
            $device = getOrCreateDevice($deviceUuid, $user['id'], $deviceName, $platform);
            $session = createUserSession($user['id'], $device['id']);
            
            $db->commit();
            
            logMessage("New device initialized: $deviceUuid with new user: $userUuid");
            
            sendSuccess([
                'user_uuid' => $user['user_uuid'],
                'session_token' => $session['session_token'],
                'expires_at' => $session['expires_at'],
                'is_new_user' => true,
                'user_info' => [
                    'user_uuid' => $user['user_uuid'],
                    'user_name' => $user['user_name'],
                    'email' => $user['email'],
                    'created_at' => $user['created_at']
                ]
            ], 'Device initialized successfully');
        }
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 设备绑定到现有用户
 */
function handleDeviceBind() {
    $data = getRequestData();
    
    // 验证必需参数
    validateRequired($data, ['user_uuid', 'device_uuid', 'device_name', 'platform']);
    
    $userUuid = $data['user_uuid'];
    $deviceUuid = $data['device_uuid'];
    $deviceName = $data['device_name'];
    $platform = $data['platform'];
    
    // 验证UUID格式
    if (!validateUUID($userUuid) || !validateUUID($deviceUuid)) {
        throw new Exception('Invalid UUID format');
    }
    
    $db = getDB();
    $db->beginTransaction();
    
    try {
        // 检查用户是否存在
        $stmt = $db->prepare('SELECT * FROM users WHERE user_uuid = ?');
        $stmt->execute([$userUuid]);
        $user = $stmt->fetch();
        
        if (!$user) {
            throw new Exception('User not found');
        }
        
        // 检查设备是否已被其他用户使用（只检查活跃设备）
        $stmt = $db->prepare('SELECT d.*, u.user_uuid FROM devices d JOIN users u ON d.user_id = u.id WHERE d.device_uuid = ? AND d.is_active = 1');
        $stmt->execute([$deviceUuid]);
        $existingDevice = $stmt->fetch();

        if ($existingDevice && $existingDevice['user_uuid'] !== $userUuid) {
            throw new Exception('Device is already bound to another user: ' . $existingDevice['user_uuid']);
        }
        
        // 创建或更新设备
        $device = getOrCreateDevice($deviceUuid, $user['id'], $deviceName, $platform);
        $session = createUserSession($user['id'], $device['id']);
        
        // 获取用户设备数量
        $stmt = $db->prepare('SELECT COUNT(*) FROM devices WHERE user_id = ? AND is_active = 1');
        $stmt->execute([$user['id']]);
        $deviceCount = $stmt->fetchColumn();
        
        $db->commit();
        
        logMessage("Device bound: $deviceUuid to user: $userUuid");
        
        sendSuccess([
            'session_token' => $session['session_token'],
            'expires_at' => $session['expires_at'],
            'user_data' => [
                'user_uuid' => $user['user_uuid'],
                'user_name' => $user['user_name'],
                'email' => $user['email'],
                'created_at' => $user['created_at'],
                'device_count' => $deviceCount,
                'last_sync_timestamp' => 0 // 新设备需要全量同步
            ]
        ], 'Device bound successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * Token刷新
 */
function handleTokenRefresh() {
    $userInfo = requireAuth();
    
    $db = getDB();
    
    // 撤销当前token
    $currentToken = getAuthTokenFromHeader();
    revokeUserSession($currentToken);
    
    // 创建新token
    $session = createUserSession($userInfo['user_id'], $userInfo['device_id']);
    
    logMessage("Token refreshed for user: {$userInfo['user_uuid']}");
    
    sendSuccess([
        'session_token' => $session['session_token'],
        'expires_at' => $session['expires_at']
    ], 'Token refreshed successfully');
}

/**
 * 用户登出
 */
function handleLogout() {
    $token = getAuthTokenFromHeader();
    
    if ($token) {
        $revoked = revokeUserSession($token);
        if ($revoked) {
            logMessage("User logged out");
            sendSuccess([], 'Logged out successfully');
        } else {
            throw new Exception('Invalid session token');
        }
    } else {
        throw new Exception('No session token provided');
    }
}

/**
 * 传统用户注册
 */
function handleUserRegister() {
    $data = getRequestData();
    
    // 验证必需参数
    validateRequired($data, ['user_name', 'password', 'device_uuid', 'device_name', 'platform']);
    
    $userName = $data['user_name'];
    $password = $data['password'];
    $email = $data['email'] ?? null;
    $deviceUuid = $data['device_uuid'];
    $deviceName = $data['device_name'];
    $platform = $data['platform'];
    
    // 验证密码强度
    if (strlen($password) < 6) {
        throw new Exception('Password must be at least 6 characters long');
    }
    
    $db = getDB();
    $db->beginTransaction();
    
    try {
        // 检查用户名是否已存在
        $stmt = $db->prepare('SELECT id FROM users WHERE user_name = ?');
        $stmt->execute([$userName]);
        if ($stmt->fetch()) {
            throw new Exception('Username already exists');
        }
        
        // 创建用户
        $userUuid = generateUserUUID();
        $passwordHash = hashPassword($password);
        
        $stmt = $db->prepare('
            INSERT INTO users (user_uuid, user_name, email, password_hash, created_at, updated_at, last_active_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ');
        $stmt->execute([$userUuid, $userName, $email, $passwordHash]);
        $userId = $db->lastInsertId();
        
        // 创建设备
        $device = getOrCreateDevice($deviceUuid, $userId, $deviceName, $platform);
        $session = createUserSession($userId, $device['id']);
        
        $db->commit();
        
        logMessage("User registered: $userName ($userUuid)");
        
        sendSuccess([
            'user_uuid' => $userUuid,
            'session_token' => $session['session_token'],
            'expires_at' => $session['expires_at'],
            'user_info' => [
                'user_uuid' => $userUuid,
                'user_name' => $userName,
                'email' => $email
            ]
        ], 'User registered successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 传统用户登录
 */
function handleUserLogin() {
    $data = getRequestData();
    
    // 验证必需参数
    validateRequired($data, ['user_name', 'password', 'device_uuid', 'device_name', 'platform']);
    
    $userName = $data['user_name'];
    $password = $data['password'];
    $deviceUuid = $data['device_uuid'];
    $deviceName = $data['device_name'];
    $platform = $data['platform'];
    
    $db = getDB();
    
    // 验证用户凭据
    $stmt = $db->prepare('SELECT * FROM users WHERE user_name = ?');
    $stmt->execute([$userName]);
    $user = $stmt->fetch();
    
    if (!$user || !verifyPassword($password, $user['password_hash'])) {
        throw new Exception('Invalid username or password');
    }
    
    $db->beginTransaction();
    
    try {
        // 创建或更新设备
        $device = getOrCreateDevice($deviceUuid, $user['id'], $deviceName, $platform);
        $session = createUserSession($user['id'], $device['id']);
        
        // 更新用户最后活跃时间
        $stmt = $db->prepare('UPDATE users SET last_active_at = CURRENT_TIMESTAMP WHERE id = ?');
        $stmt->execute([$user['id']]);
        
        $db->commit();
        
        logMessage("User logged in: $userName");
        
        sendSuccess([
            'user_uuid' => $user['user_uuid'],
            'session_token' => $session['session_token'],
            'expires_at' => $session['expires_at'],
            'user_info' => [
                'user_uuid' => $user['user_uuid'],
                'user_name' => $user['user_name'],
                'email' => $user['email']
            ]
        ], 'Login successful');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}

/**
 * 设备解绑
 */
function handleDeviceUnbind() {
    // 需要认证才能解绑设备
    $userInfo = requireAuth();

    $data = getRequestData();

    // 验证必需参数
    validateRequired($data, ['device_uuid']);

    $deviceUuid = $data['device_uuid'];

    // 验证UUID格式
    if (!validateUUID($deviceUuid)) {
        throw new Exception('Invalid device UUID format');
    }


    $db = getDB();
    $db->beginTransaction();

    try {
        // 检查设备是否属于当前用户
        $stmt = $db->prepare('
            SELECT d.*, u.user_uuid
            FROM devices d
            JOIN users u ON d.user_id = u.id
            WHERE d.device_uuid = ? AND d.user_id = ?
        ');
        $stmt->execute([$deviceUuid, $userInfo['user_id']]);
        $device = $stmt->fetch();

        if (!$device) {
            throw new Exception('Device not found or not owned by current user');
        }

        error_log("Debug: 'unbind ,did:'".$deviceUuid."user_id:".$userInfo['user_id']);

        // 撤销该设备的所有会话
        $stmt = $db->prepare('UPDATE user_sessions SET is_active = 0 WHERE device_id = ?');
        $stmt->execute([$device['id']]);

        // 删除设备记录（彻底解绑）
        $stmt = $db->prepare('DELETE FROM devices WHERE id = ?');

        $stmt->execute([$device['id']]);

        // 获取用户剩余活跃设备数量
        $stmt = $db->prepare('SELECT COUNT(*) FROM devices WHERE user_id = ? AND is_active = 1');
        $stmt->execute([$userInfo['user_id']]);
        $remainingDeviceCount = $stmt->fetchColumn();

        $db->commit();

        logMessage("Device unbound: $deviceUuid from user: {$userInfo['user_uuid']}");

        sendSuccess([
            'device_uuid' => $deviceUuid,
            'remaining_device_count' => $remainingDeviceCount,
            'unbound_at' => date('c')
        ], 'Device unbound successfully');

    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
}
?>
