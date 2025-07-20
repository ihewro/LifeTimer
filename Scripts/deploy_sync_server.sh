#!/bin/bash

# 番茄钟同步服务部署脚本
# 使用方法: ./deploy_sync_server.sh [server_path]

set -e

# 默认部署路径
DEFAULT_SERVER_PATH="/var/www/html/sync_server"
SERVER_PATH="${1:-$DEFAULT_SERVER_PATH}"

echo "=== 番茄钟同步服务部署脚本 ==="
echo "部署路径: $SERVER_PATH"
echo

# 检查是否为root用户或有sudo权限
if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "❌ 需要root权限或sudo权限来部署服务"
    echo "请使用: sudo ./deploy_sync_server.sh"
    exit 1
fi

# 检查PHP是否安装
if ! command -v php &> /dev/null; then
    echo "❌ PHP未安装，请先安装PHP 7.4或更高版本"
    exit 1
fi

# 检查PHP版本
PHP_VERSION=$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)
if (( $(echo "$PHP_VERSION < 7.4" | bc -l) )); then
    echo "❌ PHP版本过低 ($PHP_VERSION)，需要7.4或更高版本"
    exit 1
fi

echo "✅ PHP版本检查通过: $PHP_VERSION"

# 检查SQLite3扩展
if ! php -m | grep -q sqlite3; then
    echo "❌ PHP SQLite3扩展未安装"
    echo "Ubuntu/Debian: sudo apt-get install php-sqlite3"
    echo "CentOS/RHEL: sudo yum install php-sqlite3"
    exit 1
fi

echo "✅ SQLite3扩展检查通过"

# 创建部署目录
echo "📁 创建部署目录..."
if [[ $EUID -eq 0 ]]; then
    mkdir -p "$SERVER_PATH"
else
    sudo mkdir -p "$SERVER_PATH"
fi

# 复制文件
echo "📋 复制服务文件..."
if [[ $EUID -eq 0 ]]; then
    cp -r sync_server/* "$SERVER_PATH/"
else
    sudo cp -r sync_server/* "$SERVER_PATH/"
fi

# 创建必要的目录
echo "📁 创建数据和日志目录..."
if [[ $EUID -eq 0 ]]; then
    mkdir -p "$SERVER_PATH/database"
    mkdir -p "$SERVER_PATH/logs"
else
    sudo mkdir -p "$SERVER_PATH/database"
    sudo mkdir -p "$SERVER_PATH/logs"
fi

# 设置权限
echo "🔐 设置文件权限..."
if [[ $EUID -eq 0 ]]; then
    # 设置目录权限
    chmod 755 "$SERVER_PATH"
    chmod 755 "$SERVER_PATH/database"
    chmod 755 "$SERVER_PATH/logs"
    
    # 设置文件权限
    find "$SERVER_PATH" -type f -name "*.php" -exec chmod 644 {} \;
    find "$SERVER_PATH" -type f -name "*.sql" -exec chmod 644 {} \;
    
    # 如果数据库文件存在，设置权限
    if [ -f "$SERVER_PATH/database/pomodoro_sync.db" ]; then
        chmod 666 "$SERVER_PATH/database/pomodoro_sync.db"
    fi
    
    # 设置Web服务器用户权限
    if command -v apache2 &> /dev/null; then
        chown -R www-data:www-data "$SERVER_PATH"
    elif command -v nginx &> /dev/null; then
        chown -R nginx:nginx "$SERVER_PATH"
    else
        echo "⚠️  未检测到Apache或Nginx，请手动设置Web服务器用户权限"
    fi
else
    sudo chmod 755 "$SERVER_PATH"
    sudo chmod 755 "$SERVER_PATH/database"
    sudo chmod 755 "$SERVER_PATH/logs"
    
    sudo find "$SERVER_PATH" -type f -name "*.php" -exec chmod 644 {} \;
    sudo find "$SERVER_PATH" -type f -name "*.sql" -exec chmod 644 {} \;
    
    if [ -f "$SERVER_PATH/database/pomodoro_sync.db" ]; then
        sudo chmod 666 "$SERVER_PATH/database/pomodoro_sync.db"
    fi
    
    if command -v apache2 &> /dev/null; then
        sudo chown -R www-data:www-data "$SERVER_PATH"
    elif command -v nginx &> /dev/null; then
        sudo chown -R nginx:nginx "$SERVER_PATH"
    else
        echo "⚠️  未检测到Apache或Nginx，请手动设置Web服务器用户权限"
    fi
fi

# 创建.htaccess文件（如果是Apache）
if command -v apache2 &> /dev/null; then
    echo "🔧 创建Apache .htaccess文件..."
    cat > "$SERVER_PATH/.htaccess" << 'EOF'
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.php [QSA,L]

# 安全设置
<Files "*.db">
    Order allow,deny
    Deny from all
</Files>

<Files "*.log">
    Order allow,deny
    Deny from all
</Files>
EOF
    
    if [[ $EUID -eq 0 ]]; then
        chmod 644 "$SERVER_PATH/.htaccess"
        chown www-data:www-data "$SERVER_PATH/.htaccess"
    else
        sudo chmod 644 "$SERVER_PATH/.htaccess"
        sudo chown www-data:www-data "$SERVER_PATH/.htaccess"
    fi
fi

# 初始化数据库
echo "🗄️  初始化数据库..."
cd "$SERVER_PATH"
php -r "
require_once 'config/database.php';
try {
    \$db = Database::getInstance();
    echo '✅ 数据库初始化成功\n';
} catch (Exception \$e) {
    echo '❌ 数据库初始化失败: ' . \$e->getMessage() . '\n';
    exit(1);
}
"

# 测试API
echo "🧪 测试API接口..."
if command -v curl &> /dev/null; then
    # 检测服务器URL
    if command -v apache2 &> /dev/null || command -v nginx &> /dev/null; then
        # 尝试本地测试
        LOCAL_URL="http://localhost$(echo $SERVER_PATH | sed 's|/var/www/html||')"
        
        echo "测试URL: $LOCAL_URL/api/health"
        
        RESPONSE=$(curl -s -w "%{http_code}" "$LOCAL_URL/api/health" 2>/dev/null || echo "000")
        HTTP_CODE="${RESPONSE: -3}"
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ API测试通过"
        else
            echo "⚠️  API测试失败 (HTTP $HTTP_CODE)"
            echo "请检查Web服务器配置和URL重写规则"
        fi
    else
        echo "⚠️  未检测到Web服务器，跳过API测试"
    fi
else
    echo "⚠️  curl未安装，跳过API测试"
fi

echo
echo "🎉 部署完成！"
echo
echo "📋 部署信息:"
echo "   服务路径: $SERVER_PATH"
echo "   数据库: $SERVER_PATH/database/pomodoro_sync.db"
echo "   日志: $SERVER_PATH/logs/sync.log"
echo
echo "🔧 后续步骤:"
echo "1. 配置Web服务器虚拟主机指向 $SERVER_PATH"
echo "2. 确保启用URL重写模块"
echo "3. 在客户端应用中配置服务器URL"
echo "4. 运行测试脚本验证功能: php $SERVER_PATH/test_api.php"
echo
echo "📖 详细文档请查看: $SERVER_PATH/README.md"
