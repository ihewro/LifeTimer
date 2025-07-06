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

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

try {
    if ($method === 'GET' && strpos($path, 'get_week_statistic') !== false) {
        handleWeekStatistic();
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
            $dayData = calculateDayFocusTimeWithDebug($db, $date);
            $focusMinutes = $dayData['totalMinutes'];
            $debugInfo[] = $dayData['debugInfo'];
        } else {
            // 正常模式：只获取总时间
            $focusMinutes = calculateDayFocusTime($db, $date);
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
function calculateDayFocusTime($db, $date) {
    // 将日期转换为时间戳范围（毫秒）
    $startOfDay = strtotime($date . ' 00:00:00') * 1000;
    $endOfDay = strtotime($date . ' 23:59:59') * 1000;

    // 查询番茄时间和正计时事件
    $sql = "SELECT start_time, end_time, event_type
            FROM pomodoro_events
            WHERE start_time >= ? AND start_time <= ?
            AND (event_type = '番茄时间' OR event_type = '正计时')
            AND deleted_at IS NULL
            AND is_completed = 1
            AND device_uuid = 5BCB91C4-62F1-4DCD-B927-642545156FF7"
            ;

    $stmt = $db->prepare($sql);
    $stmt->execute([$startOfDay, $endOfDay]);
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
function calculateDayFocusTimeWithDebug($db, $date) {
    // 将日期转换为时间戳范围（毫秒）
    $startOfDay = strtotime($date . ' 00:00:00') * 1000;
    $endOfDay = strtotime($date . ' 23:59:59') * 1000;

    // 查询番茄时间和正计时事件
    $sql = "SELECT title, start_time, end_time, event_type
            FROM pomodoro_events
            WHERE start_time >= ? AND start_time <= ?
            AND (event_type != 'rest')
            AND deleted_at IS NULL
            -- AND is_completed = 1
            AND device_uuid = '5BCB91C4-62F1-4DCD-B927-642545156FF7'
            ORDER BY start_time";

    $stmt = $db->prepare($sql);
    $stmt->execute([$startOfDay, $endOfDay]);
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
?>
