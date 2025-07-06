<?php
/**
 * 通用函数库
 */


/**
 * 验证必需参数
 */
function validateRequired($data, $requiredFields) {
    foreach ($requiredFields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
}

/**
 * 获取请求数据
 */
function getRequestData() {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Invalid JSON data');
    }
    
    return $data ?: [];
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
 * 生成会话Token
 */
function generateSessionToken() {
    return bin2hex(random_bytes(32));
}

/**
 * 获取数据库连接
 */
if (!function_exists('getDB')) {
    function getDB() {
        return Database::getInstance()->getConnection();
    }
}

/**
 * 发送成功响应
 */
if (!function_exists('sendSuccess')) {
    function sendSuccess($data = null, $message = 'Success') {
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'data' => $data,
            'message' => $message,
            'timestamp' => time() * 1000
        ]);
        exit();
    }
}

/**
 * 发送错误响应
 */
if (!function_exists('sendError')) {
    function sendError($message, $httpCode = 400, $data = null) {
        http_response_code($httpCode);
        echo json_encode([
            'success' => false,
            'data' => $data,
            'message' => $message,
            'timestamp' => time() * 1000
        ]);
        exit();
    }
}
