<?php
// 基础API响应函数
function sendResponse($success, $data = null, $message = '', $httpCode = 200) {
    http_response_code($httpCode);
    echo json_encode([
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => time() * 1000
    ]);
    exit();
}

function sendError($message, $httpCode = 400, $data = null) {
    sendResponse(false, $data, $message, $httpCode);
}

function sendSuccess($data = null, $message = 'Success') {
    sendResponse(true, $data, $message);
}

// 获取请求体JSON数据
function getRequestData() {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE && !empty($input)) {
        throw new Exception('Invalid JSON data');
    }
    
    return $data ?: [];
}

// 验证必需参数
function validateRequired($data, $required_fields) {
    $missing = [];
    foreach ($required_fields as $field) {
        if (!isset($data[$field]) || $data[$field] === '') {
            $missing[] = $field;
        }
    }
    
    if (!empty($missing)) {
        throw new Exception('Missing required fields: ' . implode(', ', $missing));
    }
}

// 验证UUID格式
function validateUUID($uuid) {
    return preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $uuid);
}

// 获取当前时间戳（毫秒）
function getCurrentTimestamp() {
    return round(microtime(true) * 1000);
}

// 日志记录函数
function logMessage($message, $level = 'INFO') {
    $log_file = __DIR__ . '/../logs/sync.log';
    $log_dir = dirname($log_file);
    
    if (!is_dir($log_dir)) {
        mkdir($log_dir, 0755, true);
    }
    
    $timestamp = date('Y-m-d H:i:s');
    $log_entry = "[$timestamp] [$level] $message" . PHP_EOL;
    file_put_contents($log_file, $log_entry, FILE_APPEND | LOCK_EX);
}

// 设备验证
function validateDevice($device_uuid) {
    if (!validateUUID($device_uuid)) {
        throw new Exception('Invalid device UUID format');
    }
    
    $db = getDB();
    $stmt = $db->prepare('SELECT device_uuid FROM devices WHERE device_uuid = ?');
    $stmt->execute([$device_uuid]);
    
    if (!$stmt->fetch()) {
        throw new Exception('Device not registered');
    }
    
    return true;
}
?>
