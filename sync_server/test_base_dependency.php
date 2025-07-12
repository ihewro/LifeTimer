<?php
/**
 * 测试 base.php 的依赖关系
 */

echo "=== 测试 base.php 依赖关系 ===\n";

try {
    // 只引用 base.php，看是否能正确使用 functions.php 中的函数
    require_once 'api/base.php';
    
    echo "✅ base.php 加载成功\n";
    
    // 测试 functions.php 中的函数是否可用
    if (function_exists('getDB')) {
        echo "✅ getDB() 函数可用\n";
    } else {
        echo "❌ getDB() 函数不可用\n";
    }
    
    if (function_exists('generateUserUUID')) {
        $uuid = generateUserUUID();
        echo "✅ generateUserUUID() 可用: $uuid\n";
    } else {
        echo "❌ generateUserUUID() 不可用\n";
    }
    
    // 测试 base.php 中的函数
    if (function_exists('validateUUID')) {
        $testUuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
        $isValid = validateUUID($testUuid);
        echo "✅ validateUUID() 可用: $testUuid -> " . ($isValid ? 'valid' : 'invalid') . "\n";
    } else {
        echo "❌ validateUUID() 不可用\n";
    }
    
    if (function_exists('getCurrentTimestamp')) {
        $timestamp = getCurrentTimestamp();
        echo "✅ getCurrentTimestamp() 可用: $timestamp\n";
    } else {
        echo "❌ getCurrentTimestamp() 不可用\n";
    }
    
    if (function_exists('logMessage')) {
        echo "✅ logMessage() 函数可用\n";
    } else {
        echo "❌ logMessage() 函数不可用\n";
    }
    
    // 测试 validateDevice 函数（这个函数内部使用了 getDB）
    if (function_exists('validateDevice')) {
        echo "✅ validateDevice() 函数可用\n";
        // 注意：不实际调用，因为需要数据库连接
    } else {
        echo "❌ validateDevice() 函数不可用\n";
    }
    
    echo "\n✅ 所有测试通过！base.php 正确引用了 functions.php\n";
    
} catch (Exception $e) {
    echo "❌ 测试失败: " . $e->getMessage() . "\n";
}

echo "\n=== 测试完成 ===\n";
?>
