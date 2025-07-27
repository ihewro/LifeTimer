#!/bin/bash

# LifeTimer 应用打包脚本
# 专门用于应用的打包和分发

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="LifeTimer"
SCHEME_NAME="LifeTimer"
PROJECT_PATH="./LifeTimer.xcodeproj"
BUILD_DIR="./build"
ARCHIVE_PATH="$BUILD_DIR/LifeTimer.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"

# 版本信息
VERSION=$(grep -A1 "MARKETING_VERSION" LifeTimer.xcodeproj/project.pbxproj | grep -o '[0-9]\+\.[0-9]\+' | head -1)
BUILD_NUMBER=$(grep -A1 "CURRENT_PROJECT_VERSION" LifeTimer.xcodeproj/project.pbxproj | grep -o '[0-9]\+' | head -1)

# 函数：打印带颜色的消息
print_message() {
    echo -e "${2}${1}${NC}"
}

# 函数：打印标题
print_title() {
    echo ""
    print_message "========================================" $CYAN
    print_message "$1" $CYAN
    print_message "========================================" $CYAN
}

# 函数：检查依赖
check_dependencies() {
    print_title "检查构建依赖"
    
    # 检查 Xcode
    if ! command -v xcodebuild &> /dev/null; then
        print_message "❌ 错误: 未找到 Xcode 命令行工具" $RED
        print_message "请安装 Xcode 并运行: xcode-select --install" $YELLOW
        exit 1
    fi
    print_message "✅ Xcode 命令行工具已安装" $GREEN
    
    # 检查项目文件
    if [ ! -f "$PROJECT_PATH/project.pbxproj" ]; then
        print_message "❌ 错误: 未找到项目文件 $PROJECT_PATH" $RED
        exit 1
    fi
    print_message "✅ 项目文件存在" $GREEN
    
    # 显示版本信息
    print_message "📱 应用版本: $VERSION ($BUILD_NUMBER)" $BLUE
    
    # 检查 hdiutil (用于创建 DMG)
    if ! command -v hdiutil &> /dev/null; then
        print_message "⚠️  警告: 未找到 hdiutil，无法创建 DMG 安装包" $YELLOW
    else
        print_message "✅ hdiutil 可用" $GREEN
    fi
}

# 函数：准备构建环境
prepare_build_env() {
    print_title "准备构建环境"
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR"
    print_message "✅ 构建目录已创建: $BUILD_DIR" $GREEN
    
    # 清理旧的构建产物
    rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
    rm -f "$BUILD_DIR"/*.dmg "$BUILD_DIR"/*.zip
    print_message "✅ 旧的构建产物已清理" $GREEN
}

# 函数：创建导出选项文件
create_export_options() {
    print_message "创建导出选项文件..." $BLUE
    
    cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
EOF
    
    print_message "✅ 导出选项文件已创建" $GREEN
}

# 函数：清理构建缓存
clean_build() {
    print_title "清理构建缓存"
    
    if xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" clean; then
        print_message "✅ 构建缓存已清理" $GREEN
    else
        print_message "❌ 清理构建缓存失败" $RED
        exit 1
    fi
}

# 函数：归档应用
archive_app() {
    print_title "归档应用"
    
    print_message "开始归档 macOS 版本..." $BLUE
    print_message "这可能需要几分钟时间..." $YELLOW
    
    if xcodebuild -project "$PROJECT_PATH" \
                  -scheme "$SCHEME_NAME" \
                  -destination 'platform=macOS' \
                  -configuration Release \
                  -archivePath "$ARCHIVE_PATH" \
                  archive; then
        print_message "✅ 应用归档完成" $GREEN
        print_message "📦 归档位置: $ARCHIVE_PATH" $BLUE
    else
        print_message "❌ 应用归档失败" $RED
        exit 1
    fi
}

# 函数：导出应用
export_app() {
    print_title "导出应用"
    
    # 检查归档是否存在
    if [ ! -d "$ARCHIVE_PATH" ]; then
        print_message "❌ 错误: 未找到归档文件" $RED
        print_message "请先运行归档步骤" $YELLOW
        exit 1
    fi
    
    print_message "开始导出应用..." $BLUE
    
    if xcodebuild -exportArchive \
                  -archivePath "$ARCHIVE_PATH" \
                  -exportPath "$EXPORT_PATH" \
                  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"; then
        print_message "✅ 应用导出完成" $GREEN
        print_message "📱 应用位置: $EXPORT_PATH/LifeTimer.app" $BLUE
    else
        print_message "❌ 应用导出失败" $RED
        exit 1
    fi
}

# 函数：验证应用
verify_app() {
    print_title "验证应用"
    
    local app_path="$EXPORT_PATH/LifeTimer.app"
    
    if [ ! -d "$app_path" ]; then
        print_message "❌ 错误: 未找到导出的应用" $RED
        return 1
    fi
    
    # 检查应用信息
    print_message "📋 应用信息:" $BLUE
    print_message "  路径: $app_path" $BLUE
    
    # 获取应用版本
    local app_version=$(defaults read "$app_path/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "未知")
    local app_build=$(defaults read "$app_path/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "未知")
    print_message "  版本: $app_version ($app_build)" $BLUE
    
    # 获取应用大小
    local app_size=$(du -sh "$app_path" | cut -f1)
    print_message "  大小: $app_size" $BLUE
    
    # 检查代码签名
    if codesign -v "$app_path" 2>/dev/null; then
        print_message "✅ 代码签名验证通过" $GREEN
    else
        print_message "⚠️  代码签名验证失败" $YELLOW
    fi
    
    print_message "✅ 应用验证完成" $GREEN
}

# 函数：创建 DMG 安装包
create_dmg() {
    print_title "创建 DMG 安装包"
    
    local app_path="$EXPORT_PATH/LifeTimer.app"
    local dmg_path="$BUILD_DIR/LifeTimer-$VERSION.dmg"
    local temp_dmg_path="$BUILD_DIR/temp.dmg"
    local volume_name="LifeTimer $VERSION"
    local dmg_size="200m"
    
    # 检查应用是否存在
    if [ ! -d "$app_path" ]; then
        print_message "❌ 错误: 未找到导出的应用" $RED
        return 1
    fi
    
    print_message "开始创建 DMG 安装包..." $BLUE
    
    # 删除已存在的 DMG 文件
    rm -f "$dmg_path" "$temp_dmg_path"
    
    # 创建临时 DMG
    print_message "创建临时 DMG..." $BLUE
    if ! hdiutil create -srcfolder "$app_path" -volname "$volume_name" -fs HFS+ \
            -fsargs "-c c=64,a=16,e=16" -format UDRW -size "$dmg_size" "$temp_dmg_path"; then
        print_message "❌ 创建临时 DMG 失败" $RED
        return 1
    fi
    
    # 挂载 DMG
    print_message "挂载 DMG 进行自定义..." $BLUE
    local device=$(hdiutil attach -readwrite -noverify -noautoopen "$temp_dmg_path" | \
                   egrep '^/dev/' | sed 1q | awk '{print $1}')
    
    if [ -z "$device" ]; then
        print_message "❌ 挂载 DMG 失败" $RED
        return 1
    fi
    
    # 创建应用程序链接
    ln -s /Applications "/Volumes/$volume_name/Applications"
    
    # 卸载 DMG
    print_message "卸载临时 DMG..." $BLUE
    hdiutil detach "$device"
    
    # 转换为只读 DMG
    print_message "转换为最终 DMG..." $BLUE
    if hdiutil convert "$temp_dmg_path" -format UDZO -imagekey zlib-level=9 -o "$dmg_path"; then
        # 清理临时文件
        rm -f "$temp_dmg_path"
        
        local dmg_size=$(du -sh "$dmg_path" | cut -f1)
        print_message "✅ DMG 安装包创建完成" $GREEN
        print_message "💿 DMG 位置: $dmg_path" $BLUE
        print_message "📏 文件大小: $dmg_size" $BLUE
    else
        print_message "❌ DMG 安装包创建失败" $RED
        rm -f "$temp_dmg_path"
        return 1
    fi
}

# 函数：创建 ZIP 分发包
create_zip() {
    print_title "创建 ZIP 分发包"
    
    local app_path="$EXPORT_PATH/LifeTimer.app"
    local zip_path="$BUILD_DIR/LifeTimer-$VERSION.zip"
    
    # 检查应用是否存在
    if [ ! -d "$app_path" ]; then
        print_message "❌ 错误: 未找到导出的应用" $RED
        return 1
    fi
    
    print_message "开始创建 ZIP 分发包..." $BLUE
    
    # 删除已存在的 ZIP 文件
    rm -f "$zip_path"
    
    # 创建 ZIP 包
    cd "$EXPORT_PATH"
    if zip -r "../LifeTimer-$VERSION.zip" "LifeTimer.app"; then
        cd "../.."
        
        local zip_size=$(du -sh "$zip_path" | cut -f1)
        print_message "✅ ZIP 分发包创建完成" $GREEN
        print_message "📦 ZIP 位置: $zip_path" $BLUE
        print_message "📏 文件大小: $zip_size" $BLUE
    else
        cd "../.."
        print_message "❌ ZIP 分发包创建失败" $RED
        return 1
    fi
}

# 函数：生成发布说明
generate_release_notes() {
    print_title "生成发布说明"

    local release_notes_path="$BUILD_DIR/RELEASE_NOTES.md"
    local current_date=$(date "+%Y-%m-%d")

    cat > "$release_notes_path" << EOF
# LifeTimer v$VERSION 发布说明

**发布日期**: $current_date
**版本号**: $VERSION ($BUILD_NUMBER)

## 📦 下载

- **DMG 安装包**: LifeTimer-$VERSION.dmg
- **ZIP 压缩包**: LifeTimer-$VERSION.zip

## 🔧 系统要求

- **macOS**: 13.0 或更高版本
- **处理器**: Intel 或 Apple Silicon
- **存储空间**: 至少 50MB 可用空间

## 📋 安装说明

### DMG 安装包
1. 下载 \`LifeTimer-$VERSION.dmg\` 文件
2. 双击打开 DMG 文件
3. 将 LifeTimer.app 拖拽到 Applications 文件夹
4. 从 Applications 文件夹启动应用

### ZIP 压缩包
1. 下载 \`LifeTimer-$VERSION.zip\` 文件
2. 解压缩文件
3. 将 LifeTimer.app 移动到 Applications 文件夹
4. 从 Applications 文件夹启动应用

## ⚠️ 安全提示

首次运行时，macOS 可能会显示安全警告。请按以下步骤操作：

1. 如果看到"无法打开应用"的提示，请前往 **系统偏好设置** > **安全性与隐私**
2. 在 **通用** 标签页中，点击 **仍要打开** 按钮
3. 或者在 Finder 中右键点击应用，选择 **打开**，然后点击 **打开** 确认

## 🚀 主要功能

- 🍅 番茄钟计时器
- ⏰ 自定义计时模式
- 🎵 背景音乐播放
- 📅 日历事件管理
- 📊 专注统计
- 🌙 深色模式支持
- 💻 菜单栏集成

## 📞 技术支持

如果您在使用过程中遇到问题，请通过以下方式联系我们：

- 邮箱: support@example.com
- 项目地址: https://github.com/yourname/LifeTimer

---

**感谢使用 LifeTimer！🍅**
EOF

    print_message "✅ 发布说明已生成: $release_notes_path" $GREEN
}

# 函数：显示打包结果
show_package_results() {
    print_title "打包结果"

    print_message "🎉 打包完成！" $GREEN
    print_message "" $NC
    print_message "📁 构建产物位置: $BUILD_DIR" $BLUE
    print_message "" $NC

    # 显示文件列表
    if [ -d "$EXPORT_PATH/LifeTimer.app" ]; then
        local app_size=$(du -sh "$EXPORT_PATH/LifeTimer.app" | cut -f1)
        print_message "📱 应用程序: $EXPORT_PATH/LifeTimer.app ($app_size)" $GREEN
    fi

    if [ -f "$BUILD_DIR/LifeTimer-$VERSION.dmg" ]; then
        local dmg_size=$(du -sh "$BUILD_DIR/LifeTimer-$VERSION.dmg" | cut -f1)
        print_message "💿 DMG 安装包: $BUILD_DIR/LifeTimer-$VERSION.dmg ($dmg_size)" $GREEN
    fi

    if [ -f "$BUILD_DIR/LifeTimer-$VERSION.zip" ]; then
        local zip_size=$(du -sh "$BUILD_DIR/LifeTimer-$VERSION.zip" | cut -f1)
        print_message "📦 ZIP 分发包: $BUILD_DIR/LifeTimer-$VERSION.zip ($zip_size)" $GREEN
    fi

    if [ -f "$BUILD_DIR/RELEASE_NOTES.md" ]; then
        print_message "📋 发布说明: $BUILD_DIR/RELEASE_NOTES.md" $GREEN
    fi

    print_message "" $NC
    print_message "🚀 准备分发！" $PURPLE
}

# 函数：完整打包流程
full_package() {
    print_message "🍅 LifeTimer 应用打包工具" $PURPLE
    print_message "版本: $VERSION ($BUILD_NUMBER)" $BLUE

    # 执行完整打包流程
    check_dependencies
    prepare_build_env
    create_export_options
    clean_build
    archive_app
    export_app
    verify_app

    # 创建分发包
    local dmg_success=false
    local zip_success=false

    if command -v hdiutil &> /dev/null; then
        if create_dmg; then
            dmg_success=true
        fi
    else
        print_message "⚠️  跳过 DMG 创建（hdiutil 不可用）" $YELLOW
    fi

    if create_zip; then
        zip_success=true
    fi

    # 生成发布说明
    generate_release_notes

    # 显示结果
    show_package_results

    # 检查是否至少有一个分发包创建成功
    if [ "$dmg_success" = true ] || [ "$zip_success" = true ]; then
        print_message "✅ 打包流程完成" $GREEN
        return 0
    else
        print_message "❌ 打包流程失败" $RED
        return 1
    fi
}

# 函数：显示帮助信息
show_help() {
    echo "LifeTimer 应用打包工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  full           执行完整打包流程"
    echo "  archive        仅归档应用"
    echo "  export         仅导出应用"
    echo "  dmg            仅创建 DMG 安装包"
    echo "  zip            仅创建 ZIP 分发包"
    echo "  verify         验证已导出的应用"
    echo "  clean          清理构建产物"
    echo "  help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 full        # 执行完整打包流程"
    echo "  $0 dmg         # 仅创建 DMG 安装包"
    echo "  $0 clean       # 清理构建产物"
}

# 函数：清理构建产物
clean_all() {
    print_title "清理构建产物"

    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_message "✅ 构建产物已清理" $GREEN
    else
        print_message "ℹ️  没有需要清理的构建产物" $BLUE
    fi
}

# 主函数
main() {
    case "$1" in
        "full"|"")
            full_package
            ;;
        "archive")
            check_dependencies
            prepare_build_env
            create_export_options
            clean_build
            archive_app
            ;;
        "export")
            check_dependencies
            prepare_build_env
            create_export_options
            export_app
            ;;
        "dmg")
            create_dmg
            ;;
        "zip")
            create_zip
            ;;
        "verify")
            verify_app
            ;;
        "clean")
            clean_all
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
