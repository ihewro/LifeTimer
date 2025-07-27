#!/bin/bash

# LifeTimer 应用签名脚本
# 用于对应用进行代码签名和公证

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 配置变量（需要根据实际情况修改）
DEVELOPER_ID_APPLICATION=""  # 例如: "Developer ID Application: Your Name (TEAM_ID)"
DEVELOPER_ID_INSTALLER=""    # 例如: "Developer ID Installer: Your Name (TEAM_ID)"
APPLE_ID=""                  # 你的 Apple ID
APP_SPECIFIC_PASSWORD=""     # App 专用密码
TEAM_ID=""                   # 团队 ID

# 路径配置
APP_PATH="./build/export/LifeTimer.app"
SIGNED_APP_PATH="./build/signed/LifeTimer.app"
ZIP_PATH="./build/LifeTimer-signed.zip"
PKG_PATH="./build/LifeTimer.pkg"

# 函数：打印带颜色的消息
print_message() {
    echo -e "${2}${1}${NC}"
}

# 函数：打印标题
print_title() {
    echo ""
    print_message "========================================" $PURPLE
    print_message "$1" $PURPLE
    print_message "========================================" $PURPLE
}

# 函数：检查配置
check_config() {
    print_title "检查签名配置"
    
    local config_error=false
    
    # 检查必要的配置
    if [ -z "$DEVELOPER_ID_APPLICATION" ]; then
        print_message "❌ 错误: DEVELOPER_ID_APPLICATION 未配置" $RED
        config_error=true
    else
        print_message "✅ Developer ID Application: $DEVELOPER_ID_APPLICATION" $GREEN
    fi
    
    if [ -z "$APPLE_ID" ]; then
        print_message "⚠️  警告: APPLE_ID 未配置，无法进行公证" $YELLOW
    else
        print_message "✅ Apple ID: $APPLE_ID" $GREEN
    fi
    
    if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        print_message "⚠️  警告: APP_SPECIFIC_PASSWORD 未配置，无法进行公证" $YELLOW
    else
        print_message "✅ App 专用密码已配置" $GREEN
    fi
    
    if [ -z "$TEAM_ID" ]; then
        print_message "⚠️  警告: TEAM_ID 未配置" $YELLOW
    else
        print_message "✅ Team ID: $TEAM_ID" $GREEN
    fi
    
    # 检查应用是否存在
    if [ ! -d "$APP_PATH" ]; then
        print_message "❌ 错误: 未找到应用文件 $APP_PATH" $RED
        print_message "请先运行打包脚本生成应用" $YELLOW
        config_error=true
    else
        print_message "✅ 应用文件存在: $APP_PATH" $GREEN
    fi
    
    if [ "$config_error" = true ]; then
        print_message "❌ 配置检查失败，请修复上述问题" $RED
        exit 1
    fi
}

# 函数：准备签名环境
prepare_signing_env() {
    print_title "准备签名环境"
    
    # 创建签名目录
    mkdir -p "./build/signed"
    
    # 复制应用到签名目录
    if [ -d "$SIGNED_APP_PATH" ]; then
        rm -rf "$SIGNED_APP_PATH"
    fi
    
    cp -R "$APP_PATH" "$SIGNED_APP_PATH"
    print_message "✅ 应用已复制到签名目录" $GREEN
}

# 函数：签名应用
sign_app() {
    print_title "签名应用"
    
    print_message "开始签名应用..." $BLUE
    print_message "使用证书: $DEVELOPER_ID_APPLICATION" $BLUE
    
    # 签名应用（使用 Hardened Runtime）
    if codesign --force \
                --options runtime \
                --deep \
                --sign "$DEVELOPER_ID_APPLICATION" \
                --entitlements "./LifeTimer/LifeTimer.entitlements" \
                "$SIGNED_APP_PATH"; then
        print_message "✅ 应用签名完成" $GREEN
    else
        print_message "❌ 应用签名失败" $RED
        exit 1
    fi
}

# 函数：验证签名
verify_signature() {
    print_title "验证签名"
    
    print_message "验证代码签名..." $BLUE
    
    # 验证签名有效性
    if codesign --verify --verbose "$SIGNED_APP_PATH"; then
        print_message "✅ 签名验证通过" $GREEN
    else
        print_message "❌ 签名验证失败" $RED
        exit 1
    fi
    
    # 显示签名信息
    print_message "签名信息:" $BLUE
    codesign --display --verbose=4 "$SIGNED_APP_PATH" 2>&1 | head -10
    
    # 检查权限
    print_message "权限信息:" $BLUE
    codesign --display --entitlements - "$SIGNED_APP_PATH" 2>/dev/null | head -10
}

# 函数：创建公证用的 ZIP 包
create_notarization_zip() {
    print_title "创建公证用的 ZIP 包"
    
    # 删除已存在的 ZIP 文件
    rm -f "$ZIP_PATH"
    
    # 创建 ZIP 包
    print_message "创建 ZIP 包..." $BLUE
    if ditto -c -k --keepParent "$SIGNED_APP_PATH" "$ZIP_PATH"; then
        local zip_size=$(du -sh "$ZIP_PATH" | cut -f1)
        print_message "✅ ZIP 包创建完成: $ZIP_PATH ($zip_size)" $GREEN
    else
        print_message "❌ ZIP 包创建失败" $RED
        exit 1
    fi
}

# 函数：提交公证
submit_notarization() {
    print_title "提交公证"
    
    if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        print_message "⚠️  跳过公证（Apple ID 或密码未配置）" $YELLOW
        return 0
    fi
    
    print_message "提交应用进行公证..." $BLUE
    print_message "这可能需要几分钟时间..." $YELLOW
    
    local notary_args="--apple-id $APPLE_ID --password $APP_SPECIFIC_PASSWORD"
    if [ -n "$TEAM_ID" ]; then
        notary_args="$notary_args --team-id $TEAM_ID"
    fi
    
    # 提交公证
    if xcrun notarytool submit "$ZIP_PATH" $notary_args --wait; then
        print_message "✅ 公证完成" $GREEN
    else
        print_message "❌ 公证失败" $RED
        print_message "请检查 Apple ID、密码和网络连接" $YELLOW
        exit 1
    fi
}

# 函数：装订公证票据
staple_notarization() {
    print_title "装订公证票据"
    
    if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        print_message "⚠️  跳过装订（未进行公证）" $YELLOW
        return 0
    fi
    
    print_message "装订公证票据到应用..." $BLUE
    
    # 装订公证票据
    if xcrun stapler staple "$SIGNED_APP_PATH"; then
        print_message "✅ 公证票据装订完成" $GREEN
    else
        print_message "❌ 公证票据装订失败" $RED
        exit 1
    fi
    
    # 验证装订结果
    print_message "验证装订结果..." $BLUE
    if xcrun stapler validate "$SIGNED_APP_PATH"; then
        print_message "✅ 装订验证通过" $GREEN
    else
        print_message "❌ 装订验证失败" $RED
        exit 1
    fi
}

# 函数：验证 Gatekeeper
verify_gatekeeper() {
    print_title "验证 Gatekeeper"
    
    print_message "检查 Gatekeeper 状态..." $BLUE
    
    # 检查应用是否能通过 Gatekeeper
    if spctl --assess --type exec "$SIGNED_APP_PATH"; then
        print_message "✅ Gatekeeper 验证通过" $GREEN
    else
        print_message "⚠️  Gatekeeper 验证失败" $YELLOW
        print_message "应用可能需要用户手动允许运行" $YELLOW
    fi
}

# 函数：创建安装包
create_installer() {
    print_title "创建安装包"
    
    if [ -z "$DEVELOPER_ID_INSTALLER" ]; then
        print_message "⚠️  跳过安装包创建（DEVELOPER_ID_INSTALLER 未配置）" $YELLOW
        return 0
    fi
    
    print_message "创建 PKG 安装包..." $BLUE
    
    # 创建安装包
    if pkgbuild --root "$SIGNED_APP_PATH" \
                --identifier "com.yourcompany.LifeTimer" \
                --version "1.0" \
                --install-location "/Applications" \
                --sign "$DEVELOPER_ID_INSTALLER" \
                "$PKG_PATH"; then
        local pkg_size=$(du -sh "$PKG_PATH" | cut -f1)
        print_message "✅ PKG 安装包创建完成: $PKG_PATH ($pkg_size)" $GREEN
    else
        print_message "❌ PKG 安装包创建失败" $RED
    fi
}

# 函数：显示签名结果
show_signing_results() {
    print_title "签名结果"
    
    print_message "🎉 签名完成！" $GREEN
    print_message "" $NC
    print_message "📁 签名产物位置:" $BLUE
    print_message "" $NC
    
    if [ -d "$SIGNED_APP_PATH" ]; then
        local app_size=$(du -sh "$SIGNED_APP_PATH" | cut -f1)
        print_message "📱 已签名应用: $SIGNED_APP_PATH ($app_size)" $GREEN
    fi
    
    if [ -f "$ZIP_PATH" ]; then
        local zip_size=$(du -sh "$ZIP_PATH" | cut -f1)
        print_message "📦 公证用 ZIP: $ZIP_PATH ($zip_size)" $GREEN
    fi
    
    if [ -f "$PKG_PATH" ]; then
        local pkg_size=$(du -sh "$PKG_PATH" | cut -f1)
        print_message "📦 PKG 安装包: $PKG_PATH ($pkg_size)" $GREEN
    fi
    
    print_message "" $NC
    print_message "🚀 应用已准备好分发！" $PURPLE
}

# 函数：完整签名流程
full_signing() {
    print_message "🔒 LifeTimer 应用签名工具" $PURPLE
    
    # 执行完整签名流程
    check_config
    prepare_signing_env
    sign_app
    verify_signature
    create_notarization_zip
    submit_notarization
    staple_notarization
    verify_gatekeeper
    create_installer
    show_signing_results
}

# 函数：显示帮助信息
show_help() {
    echo "LifeTimer 应用签名工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  full           执行完整签名流程"
    echo "  sign           仅签名应用"
    echo "  verify         验证签名"
    echo "  notarize       提交公证"
    echo "  staple         装订公证票据"
    echo "  gatekeeper     验证 Gatekeeper"
    echo "  installer      创建安装包"
    echo "  help           显示此帮助信息"
    echo ""
    echo "配置说明:"
    echo "  请在脚本开头配置以下变量："
    echo "  - DEVELOPER_ID_APPLICATION: 应用签名证书"
    echo "  - DEVELOPER_ID_INSTALLER: 安装包签名证书"
    echo "  - APPLE_ID: Apple ID"
    echo "  - APP_SPECIFIC_PASSWORD: App 专用密码"
    echo "  - TEAM_ID: 团队 ID"
    echo ""
    echo "示例:"
    echo "  $0 full        # 执行完整签名流程"
    echo "  $0 sign        # 仅签名应用"
    echo "  $0 verify      # 验证签名"
}

# 主函数
main() {
    case "$1" in
        "full"|"")
            full_signing
            ;;
        "sign")
            check_config
            prepare_signing_env
            sign_app
            ;;
        "verify")
            verify_signature
            ;;
        "notarize")
            create_notarization_zip
            submit_notarization
            ;;
        "staple")
            staple_notarization
            ;;
        "gatekeeper")
            verify_gatekeeper
            ;;
        "installer")
            create_installer
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_message "❌ 未知选项: $1" $RED
            print_message "使用 '$0 help' 查看可用选项" $YELLOW
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
