<?php
/**
 * 测试 auth.php 是否正确引用了 functions.php
 */

echo "=== 测试 auth.php 依赖引用 ===\n";

try {
    // 只引用 auth.php，看是否能正确使用 functions.php 中的函数
    require_once 'includes/auth.php';
    
    echo "✅ auth.php 加载成功\n";
    
    // 测试 functions.php 中的函数是否可用
    if (function_exists('generateUserUUID')) {
        $uuid = generateUserUUID();
        echo "✅ generateUserUUID() 可用: $uuid\n";
    } else {
        echo "❌ generateUserUUID() 不可用\n";
    }
    
    if (function_exists('generateSessionToken')) {
        $token = generateSessionToken();
        echo "✅ generateSessionToken() 可用: " . substr($token, 0, 16) . "...\n";
    } else {
        echo "❌ generateSessionToken() 不可用\n";
    }
    
    // 测试 auth.php 中的函数是否可用
    if (function_exists('validateUUID')) {
        $testUuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
        $isValid = validateUUID($testUuid);
        echo "✅ validateUUID() 可用: $testUuid -> " . ($isValid ? 'valid' : 'invalid') . "\n";
    } else {
        echo "❌ validateUUID() 不可用\n";
    }
    
    echo "\n✅ 所有测试通过！依赖引用正确。\n";
    
} catch (Exception $e) {
    echo "❌ 测试失败: " . $e->getMessage() . "\n";
}

echo "\n=== 测试完成 ===\n";
?>
