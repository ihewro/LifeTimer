<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 处理预检请求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config/database.php';
require_once 'api/base.php';

// 简单路由
$request_uri = $_SERVER['REQUEST_URI'];
$path = parse_url($request_uri, PHP_URL_PATH);
// 移除基础路径（如果存在）
$path = str_replace('/sync_server', '', $path);
// 确保路径以 / 开头
if (!str_starts_with($path, '/')) {
    $path = '/' . $path;
}

// 路由映射
$routes = [
    'POST /api/device/register' => 'api/device.php',
    'GET /api/sync/full' => 'api/sync.php',
    'POST /api/sync/incremental' => 'api/sync.php',
    'GET /get_week_statistic' => 'statistic.php',
    'GET /api/health' => function() {
        return ['status' => 'ok', 'timestamp' => time() * 1000];
    }
];

$method = $_SERVER['REQUEST_METHOD'];
$route_key = "$method $path";

// 调试信息
error_log("Debug: Request URI: " . $request_uri);
error_log("Debug: Path: " . $path);
error_log("Debug: Method: " . $method);
error_log("Debug: Route key: " . $route_key);

try {
    if (isset($routes[$route_key])) {
        if (is_callable($routes[$route_key])) {
            $result = $routes[$route_key]();
            echo json_encode([
                'success' => true,
                'data' => $result,
                'timestamp' => time() * 1000
            ]);
        } else {
            require_once $routes[$route_key];
        }
    } else {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'API endpoint not found',
            'timestamp' => time() * 1000
        ]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Internal server error: ' . $e->getMessage(),
        'timestamp' => time() * 1000
    ]);
}
?>
