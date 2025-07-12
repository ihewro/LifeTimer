<?php
/**
 * 通用函数库
 */


// 这些函数已经在 api/base.php 中定义，避免重复定义

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

// sendSuccess 和 sendError 函数已经在 api/base.php 中定义
