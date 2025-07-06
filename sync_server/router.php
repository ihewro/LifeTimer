<?php
// Router for PHP development server
$uri = $_SERVER['REQUEST_URI'];
$path = parse_url($uri, PHP_URL_PATH);

// If it's a static file and exists, serve it
if ($path !== '/' && file_exists(__DIR__ . $path)) {
    return false; // Let PHP serve the file
}

// Otherwise, route to index.php
require_once __DIR__ . '/index.php';
?>
