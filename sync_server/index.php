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
    // 用户认证系统
    'POST /api/auth/device-init' => 'api/auth.php',
    'POST /api/auth/device-bind' => 'api/auth.php',
    'POST /api/auth/device-unbind' => 'api/auth.php',
    'POST /api/auth/refresh' => 'api/auth.php',
    'POST /api/auth/logout' => 'api/auth.php',

    // 用户同步API
    'GET /api/user/sync/full' => 'api/sync_user.php',
    'GET /api/user/sync/summary' => 'api/sync_user.php',
    'POST /api/user/sync/incremental' => 'api/sync_user.php',
    'POST /api/user/sync/migrate' => 'api/sync_user.php',

    // 用户管理API
    'GET /api/user/profile' => 'api/user.php',
    'GET /api/user/devices' => 'api/user.php',
    'DELETE /api/user/devices' => 'api/user.php',

    // 统计和健康检查
    'GET /get_week_statistic' => 'statistic.php',
    'GET /get_day_statistic' => 'statistic.php',
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
    error_log("Debug: Available routes: " . print_r(array_keys($routes), true));
    error_log("Debug: Looking for route: " . $route_key);
    error_log("Debug: Route exists: " . (isset($routes[$route_key]) ? 'yes' : 'no'));

    if (isset($routes[$route_key])) {
        if (is_callable($routes[$route_key])) {
            $result = $routes[$route_key]();
            echo json_encode([
                'success' => true,
                'data' => $result,
                'timestamp' => time() * 1000
            ]);
        } else {
            error_log("Debug: Including file: " . $routes[$route_key]);
            require_once $routes[$route_key];
        }
    } else {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Endpoint not found',
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
