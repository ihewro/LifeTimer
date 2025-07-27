<?php
// 统计API处理
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
require_once 'includes/auth.php';

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

try {
    if ($method === 'GET' && strpos($path, 'get_week_statistic') !== false) {
        handleWeekStatistic();
    } elseif ($method === 'GET' && strpos($path, 'get_day_statistic') !== false) {
        handleDayStatistic();
    } else {
        throw new Exception('Invalid statistic endpoint');
    }
} catch (Exception $e) {
    logMessage("Statistic error: " . $e->getMessage(), 'ERROR');
    sendStatisticError($e->getMessage());
}

// 发送统计API格式的错误响应
function sendStatisticError($message, $httpCode = 400) {
    http_response_code($httpCode);
    echo json_encode([
        'meta' => [
            'status' => $httpCode,
            'msg' => $message
        ],
        'data' => null
    ]);
    exit();
}

// 发送统计API格式的成功响应
function sendStatisticSuccess($data) {
    echo json_encode([
        'meta' => [
            'status' => 200,
            'msg' => ''
        ],
        'data' => $data
    ]);
    exit();
}

// 处理周统计请求
function handleWeekStatistic() {
    // 获取用户信息（支持device_id参数或Bearer token认证）
    $userInfo = getUserInfoForStatistic();
    $db = getDB();

    // 检查是否开启debug模式
    $debug = isset($_GET['debug']) && $_GET['debug'] === '1';

    // 获取当前周的开始和结束时间（周一到周日）
    $weekDates = getCurrentWeekDates();

    // 获取每天的专注时间数据
    $dailyStats = [];
    $debugInfo = [];
    $previousDayMinutes = null;

    foreach ($weekDates as $date) {
        $dayName = getDayName($date);

        if ($debug) {
            // Debug模式：获取详细事件信息
            $dayData = calculateDayFocusTimeWithDebug($db, $date, $userInfo['user_id']);
            $focusMinutes = $dayData['totalMinutes'];
            $debugInfo[] = $dayData['debugInfo'];
        } else {
            // 正常模式：只获取总时间
            $focusMinutes = calculateDayFocusTime($db, $date, $userInfo['user_id']);
        }

        // 格式化时间显示
        $timeValue = formatTime($focusMinutes);

        // 计算百分比变化
        if ($previousDayMinutes === null) {
            $subValue = "——";
            $subValueColor = "#7D7D7E";
        } else {
            $percentChange = calculatePercentChange($previousDayMinutes, $focusMinutes);
            if ($percentChange > 0) {
                $subValue = "↑" . $percentChange . "%";
                $subValueColor = "#04B921";
            } elseif ($percentChange < 0) {
                $subValue = "↓" . $percentChange . "%";
                $subValueColor = "#ff0000";
            } else {
                $subValue = "——";
                $subValueColor = "#7D7D7E";
            }
        }

        $dailyStats[] = [
            'title' => $dayName,
            'value' => $timeValue,
            'subValue' => $subValue,
            'subValueColor' => $subValueColor
        ];

        $previousDayMinutes = $focusMinutes;
    }

    $response = [
        'title' => '📅 本周专注信息 ψ(｀∇´)ψ',
        'metrics' => $dailyStats,
        'footnote' => ' Copyright @ hewro. life notice'
    ];

    // 如果是debug模式，添加调试信息
    if ($debug) {
        $response['debug'] = $debugInfo;

        // 同时输出到日志
        foreach ($debugInfo as $dayDebug) {
            logMessage("DEBUG - " . $dayDebug['date'] . " (" . $dayDebug['dayName'] . "):");
            logMessage("  总时长: " . $dayDebug['totalMinutes'] . " 分钟");
            logMessage("  事件数量: " . count($dayDebug['events']));
            foreach ($dayDebug['events'] as $event) {
                logMessage("    - " . $event['type'] . ": " . $event['startTime'] . " -> " . $event['endTime'] . " (持续 " . $event['duration'] . " 分钟)");
            }
        }
    }

    logMessage("Week statistic completed" . ($debug ? " (DEBUG MODE)" : ""));
    sendStatisticSuccess($response);
}

// 获取当前周的日期数组（周一到周日）
function getCurrentWeekDates() {
    $dates = [];
    
    // 获取当前周的周一
    $monday = new DateTime();
    $monday->modify('monday this week');
    
    // 生成7天的日期
    for ($i = 0; $i < 7; $i++) {
        $date = clone $monday;
        $date->modify("+$i days");
        $dates[] = $date->format('Y-m-d');
    }
    
    return $dates;
}

// 获取中文星期名称
function getDayName($date) {
    $dayNames = [
        1 => '星期一',
        2 => '星期二', 
        3 => '星期三',
        4 => '星期四',
        5 => '星期五',
        6 => '星期六',
        7 => '星期日'
    ];
    
    $dateObj = new DateTime($date);
    $dayOfWeek = $dateObj->format('N'); // 1 (Monday) to 7 (Sunday)
    
    return $dayNames[$dayOfWeek];
}

// 计算指定日期的专注时间（分钟）
function calculateDayFocusTime($db, $date, $userId) {
    // 将日期转换为时间戳范围（毫秒）
    $startOfDay = strtotime($date . ' 00:00:00') * 1000;
    $endOfDay = strtotime($date . ' 23:59:59') * 1000;

    // 查询番茄时间和正计时事件（支持中英文事件类型）
    $sql = "SELECT start_time, end_time, event_type
            FROM pomodoro_events
            WHERE start_time >= ? AND start_time <= ?
            AND (event_type IN ('番茄时间', 'pomodoro', '正计时', 'positive_timer'))
            AND deleted_at IS NULL
            AND is_completed = 1
            AND user_id = ?";

    $stmt = $db->prepare($sql);
    $stmt->execute([$startOfDay, $endOfDay, $userId]);
    $events = $stmt->fetchAll();

    $totalMinutes = 0;
    foreach ($events as $event) {
        // 计算事件持续时间（毫秒转分钟）
        $durationMs = $event['end_time'] - $event['start_time'];
        $durationMinutes = round($durationMs / (1000 * 60));
        $totalMinutes += $durationMinutes;
    }

    return $totalMinutes;
}

// 计算指定日期的专注时间（带调试信息）
function calculateDayFocusTimeWithDebug($db, $date, $userId) {
    // 将日期转换为时间戳范围（毫秒）
    $startOfDay = strtotime($date . ' 00:00:00') * 1000;
    $endOfDay = strtotime($date . ' 23:59:59') * 1000;

    // 查询番茄时间和正计时事件（支持中英文事件类型）
    $sql = "SELECT title, start_time, end_time, event_type
            FROM pomodoro_events
            WHERE start_time >= ? AND start_time <= ?
            AND (event_type NOT IN ('rest', '休息', 'short_break', 'long_break'))
            AND deleted_at IS NULL
            -- AND is_completed = 1
            AND user_id = ?
            ORDER BY start_time";

    $stmt = $db->prepare($sql);
    $stmt->execute([$startOfDay, $endOfDay, $userId]);
    $events = $stmt->fetchAll();

    $totalMinutes = 0;
    $debugEvents = [];

    foreach ($events as $event) {
        // 计算事件持续时间（毫秒转分钟）
        $durationMs = $event['end_time'] - $event['start_time'];
        $durationMinutes = round($durationMs / (1000 * 60));
        $totalMinutes += $durationMinutes;

        // 格式化时间显示
        $startTime = @date('H:i:s', $event['start_time'] / 1000);
        $endTime = @date('H:i:s', $event['end_time'] / 1000);

        $debugEvents[] = [
            'title' => $event['title'],
            'type' => $event['event_type'],
            'startTime' => $startTime,
            'endTime' => $endTime,
            'duration' => $durationMinutes,
            'startTimestamp' => $event['start_time'],
            'endTimestamp' => $event['end_time']
        ];
    }

    return [
        'totalMinutes' => $totalMinutes,
        'debugInfo' => [
            'date' => $date,
            'dayName' => getDayName($date),
            'totalMinutes' => $totalMinutes,
            'events' => $debugEvents,
            'timeRange' => [
                'startOfDay' => $startOfDay,
                'endOfDay' => $endOfDay,
                'startOfDayFormatted' => date('Y-m-d H:i:s', $startOfDay / 1000),
                'endOfDayFormatted' => date('Y-m-d H:i:s', $endOfDay / 1000)
            ]
        ]
    ];
}

// 格式化时间显示
function formatTime($minutes) {
    if ($minutes == 0) {
        return "0min";
    }
    
    if ($minutes < 60) {
        return $minutes . "min";
    }
    
    $hours = intval($minutes / 60);
    $remainingMinutes = $minutes % 60;
    
    if ($remainingMinutes == 0) {
        return $hours . "h";
    }
    
    return $hours . "h" . $remainingMinutes . "min";
}

// 计算百分比变化
function calculatePercentChange($previousValue, $currentValue) {
    if ($previousValue == 0) {
        return $currentValue > 0 ? 100 : 0;
    }

    $change = (($currentValue - $previousValue) / $previousValue) * 100;
    return round($change);
}

// 获取统计接口的用户信息（支持device_id参数或Bearer token认证）
function getUserInfoForStatistic() {
    $db = getDB();

    // 方式1：通过device_id参数获取用户信息
    if (isset($_GET['device_id']) && !empty($_GET['device_id'])) {
        $deviceId = $_GET['device_id'];

        // 验证device_id格式（UUID）
        if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $deviceId)) {
            throw new Exception('Invalid device_id format');
        }

        // 根据device_uuid查询用户信息
        $stmt = $db->prepare('
            SELECT
                u.id as user_id,
                u.user_uuid,
                u.user_name,
                d.id as device_id,
                d.device_uuid,
                d.device_name,
                d.platform
            FROM devices d
            JOIN users u ON d.user_id = u.id
            WHERE d.device_uuid = ? AND d.is_active = 1
        ');
        $stmt->execute([$deviceId]);
        $result = $stmt->fetch();

        if (!$result) {
            throw new Exception('Device not found or inactive');
        }

        logMessage("Statistic access via device_id: $deviceId for user: {$result['user_name']}");
        return $result;
    }

    // 方式2：通过Bearer token认证（原有方式）
    $token = getAuthTokenFromHeader();
    if ($token) {
        $userInfo = validateSessionToken($token);
        if ($userInfo) {
            logMessage("Statistic access via Bearer token for user: {$userInfo['user_name']}");
            return $userInfo;
        }
    }

    // 如果两种方式都失败，返回错误
    throw new Exception('Authentication required. Please provide either device_id parameter or Authorization header');
}

// 处理单日统计请求
function handleDayStatistic() {
    // 获取用户信息（支持device_id参数或Bearer token认证）
    $userInfo = getUserInfoForStatistic();
    $db = getDB();

    // 获取日期参数，默认为今天
    $date = isset($_GET['date']) ? $_GET['date'] : date('Y-m-d');

    // 验证日期格式
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        throw new Exception('Invalid date format. Use YYYY-MM-DD');
    }

    // 计算统计数据
    $stats = calculateDayStatistics($db, $date, $userInfo['user_id']);

    $response = [
        'title' => '🎉 今日专注信息 ψ(｀∇´)ψ',
        'metrics' => [
            [
                'title' => '⏳ 总时间',
                'value' => $stats['totalTime'] . 'min',
                'subValue' => '——',
                'subValueColor' => '#7D7D7E'
            ],
            [
                'title' => '🍅 总番茄',
                'value' => $stats['totalPomodoros'] . '个',
                'subValue' => '——',
                'subValueColor' => '#7D7D7E'
            ],
            [
                'title' => '🚥 休息次数',
                'value' => $stats['totalBreaks'] . '次',
                'subValue' => '——',
                'subValueColor' => '#7D7D7E'
            ]
        ],
        'footnote' => ' Copyright @ hewro. life notice'
    ];

    logMessage("Day statistic completed for date: $date, user: {$userInfo['user_uuid']}");
    sendStatisticSuccess($response);
}

// 计算指定日期的统计数据
function calculateDayStatistics($db, $date, $userId) {
    // 将日期转换为时间戳范围（毫秒）
    $startOfDay = strtotime($date . ' 00:00:00') * 1000;
    $endOfDay = strtotime($date . ' 23:59:59') * 1000;

    // 查询所有事件（支持中英文事件类型）
    $sql = "SELECT start_time, end_time, event_type
            FROM pomodoro_events
            WHERE start_time >= ? AND start_time <= ?
            AND deleted_at IS NULL
            AND is_completed = 1
            AND user_id = ?";

    $stmt = $db->prepare($sql);
    $stmt->execute([$startOfDay, $endOfDay, $userId]);
    $events = $stmt->fetchAll();

    $totalTime = 0;
    $totalPomodoros = 0;
    $totalBreaks = 0;

    foreach ($events as $event) {
        $eventType = $event['event_type'];

        // 判断是否为专注事件（番茄时间或正计时）
        if (in_array($eventType, ['番茄时间', 'pomodoro', '正计时', 'positive_timer'])) {
            // 计算专注时间
            $durationMs = $event['end_time'] - $event['start_time'];
            $durationMinutes = round($durationMs / (1000 * 60));
            $totalTime += $durationMinutes;

            // 统计番茄数量
            if (in_array($eventType, ['番茄时间', 'pomodoro'])) {
                $totalPomodoros++;
            }
        } elseif (in_array($eventType, ['休息', 'rest', 'short_break', 'long_break'])) {
            // 统计休息次数
            $totalBreaks++;
        }
    }

    return [
        'totalTime' => $totalTime,
        'totalPomodoros' => $totalPomodoros,
        'totalBreaks' => $totalBreaks
    ];
}
?>
