#!/bin/bash

# 番茄钟应用构建脚本
# 支持 iOS、iPadOS、macOS 平台编译

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="LifeTimer"
SCHEME_NAME="LifeTimer"
PROJECT_PATH="./LifeTimer.xcodeproj"

# 函数：打印带颜色的消息
print_message() {
    echo -e "${2}${1}${NC}"
}

# 函数：检查 Xcode 是否安装
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_message "错误: 未找到 Xcode 命令行工具" $RED
        print_message "请安装 Xcode 并运行: xcode-select --install" $YELLOW
        exit 1
    fi
    print_message "✓ Xcode 命令行工具已安装" $GREEN
}

# 函数：清理构建缓存
clean_build() {
    print_message "清理构建缓存..." $BLUE
    if xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" clean; then
        print_message "✓ 构建缓存已清理" $GREEN
    else
        print_message "✗ 清理构建缓存失败" $RED
        exit 1
    fi
}

# 函数：构建 macOS 版本
build_macos() {
    print_message "开始构建 macOS 版本..." $BLUE
    if xcodebuild -project "$PROJECT_PATH" \
                  -scheme "$SCHEME_NAME" \
                  -destination 'platform=macOS' \
                  -configuration Release \
                  build; then
        print_message "✓ macOS 版本构建完成" $GREEN
        print_message "应用位置: $(find ~/Library/Developer/Xcode/DerivedData -name "LifeTimer.app" -path "*/Release/*" 2>/dev/null | head -1)" $BLUE
    else
        print_message "✗ macOS 版本构建失败" $RED
        exit 1
    fi
}

# 函数：构建 iOS 版本
build_ios() {
    print_message "开始构建 iOS 版本..." $BLUE
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$SCHEME_NAME" \
               -destination 'platform=iOS Simulator,name=iPhone 15' \
               -configuration Release \
               build
    print_message "✓ iOS 版本构建完成" $GREEN
}

# 函数：构建 iPadOS 版本
build_ipados() {
    print_message "开始构建 iPadOS 版本..." $BLUE
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$SCHEME_NAME" \
               -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
               -configuration Release \
               build
    print_message "✓ iPadOS 版本构建完成" $GREEN
}

# 函数：运行 macOS 版本
run_macos() {
    print_message "启动 macOS 版本..." $BLUE
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$SCHEME_NAME" \
               -destination 'platform=macOS' \
               -configuration Debug \
               run
}

# 函数：运行 iOS 模拟器版本
run_ios() {
    print_message "启动 iOS 模拟器版本..." $BLUE
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$SCHEME_NAME" \
               -destination 'platform=iOS Simulator,name=iPhone 15' \
               -configuration Debug \
               run
}

# 函数：运行 iPadOS 模拟器版本
run_ipados() {
    print_message "启动 iPadOS 模拟器版本..." $BLUE
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$SCHEME_NAME" \
               -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
               -configuration Debug \
               run
}

# 函数：显示帮助信息
show_help() {
    echo "番茄钟应用构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "构建选项:"
    echo "  build-all      构建所有平台版本"
    echo "  build-macos    构建 macOS 版本"
    echo "  build-ios      构建 iOS 版本"
    echo "  build-ipados   构建 iPadOS 版本"
    echo ""
    echo "运行选项:"
    echo "  run-macos      运行 macOS 版本"
    echo "  run-ios        运行 iOS 模拟器版本"
    echo "  run-ipados     运行 iPadOS 模拟器版本"
    echo "  test-macos     测试 macOS 版本（构建并运行）"
    echo ""
    echo "打包选项:"
    echo "  archive        归档 macOS 版本"
    echo "  export         导出应用"
    echo "  create-dmg     创建 DMG 安装包"
    echo "  create-zip     创建 ZIP 分发包"
    echo "  package        完整打包流程（归档+导出+创建安装包）"
    echo ""
    echo "其他选项:"
    echo "  clean          清理构建缓存"
    echo "  open           在 Xcode 中打开项目"
    echo "  help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build-macos    # 构建 macOS 版本"
    echo "  $0 package        # 完整打包流程"
    echo "  $0 create-dmg     # 创建 DMG 安装包"
    echo "  $0 clean          # 清理构建缓存"
}

# 函数：在 Xcode 中打开项目
open_xcode() {
    print_message "在 Xcode 中打开项目..." $BLUE
    open "$PROJECT_PATH"
    print_message "✓ 项目已在 Xcode 中打开" $GREEN
}

# 函数：测试 macOS 版本（构建并运行）
test_macos() {
    print_message "测试 macOS 版本（构建并运行）..." $BLUE
    build_macos

    # 查找构建的应用
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "LifeTimer.app" -path "*/Release/*" 2>/dev/null | head -1)

    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        print_message "启动应用: $APP_PATH" $BLUE
        open "$APP_PATH"
        print_message "✓ 应用已启动" $GREEN
    else
        print_message "✗ 未找到构建的应用" $RED
        exit 1
    fi
}

# 函数：归档 macOS 版本
archive_macos() {
    print_message "开始归档 macOS 版本..." $BLUE

    # 创建归档目录
    ARCHIVE_PATH="./build/LifeTimer.xcarchive"
    mkdir -p "./build"

    if xcodebuild -project "$PROJECT_PATH" \
                  -scheme "$SCHEME_NAME" \
                  -destination 'platform=macOS' \
                  -configuration Release \
                  -archivePath "$ARCHIVE_PATH" \
                  archive; then
        print_message "✓ macOS 版本归档完成" $GREEN
        print_message "归档位置: $ARCHIVE_PATH" $BLUE
        return 0
    else
        print_message "✗ macOS 版本归档失败" $RED
        return 1
    fi
}

# 函数：导出应用
export_app() {
    print_message "开始导出应用..." $BLUE

    ARCHIVE_PATH="./build/LifeTimer.xcarchive"
    EXPORT_PATH="./build/export"
    EXPORT_OPTIONS_PLIST="./build/ExportOptions.plist"

    # 检查归档是否存在
    if [ ! -d "$ARCHIVE_PATH" ]; then
        print_message "错误: 未找到归档文件，请先运行归档" $RED
        return 1
    fi

    # 创建导出选项文件
    create_export_options_plist "$EXPORT_OPTIONS_PLIST"

    # 导出应用
    if xcodebuild -exportArchive \
                  -archivePath "$ARCHIVE_PATH" \
                  -exportPath "$EXPORT_PATH" \
                  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"; then
        print_message "✓ 应用导出完成" $GREEN
        print_message "导出位置: $EXPORT_PATH" $BLUE
        return 0
    else
        print_message "✗ 应用导出失败" $RED
        return 1
    fi
}

# 函数：创建导出选项文件
create_export_options_plist() {
    local plist_path="$1"

    cat > "$plist_path" << EOF
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

    print_message "✓ 导出选项文件已创建: $plist_path" $GREEN
}

# 函数：创建 DMG 安装包
create_dmg() {
    print_message "开始创建 DMG 安装包..." $BLUE

    local app_path="./build/export/LifeTimer.app"
    local dmg_path="./build/LifeTimer.dmg"
    local temp_dmg_path="./build/temp.dmg"
    local volume_name="LifeTimer"
    local dmg_size="100m"

    # 检查应用是否存在
    if [ ! -d "$app_path" ]; then
        print_message "错误: 未找到导出的应用，请先运行导出" $RED
        return 1
    fi

    # 删除已存在的 DMG 文件
    rm -f "$dmg_path" "$temp_dmg_path"

    # 创建临时 DMG
    print_message "创建临时 DMG..." $BLUE
    hdiutil create -srcfolder "$app_path" -volname "$volume_name" -fs HFS+ \
            -fsargs "-c c=64,a=16,e=16" -format UDRW -size "$dmg_size" "$temp_dmg_path"

    # 挂载 DMG
    print_message "挂载 DMG 进行自定义..." $BLUE
    local device=$(hdiutil attach -readwrite -noverify -noautoopen "$temp_dmg_path" | \
                   egrep '^/dev/' | sed 1q | awk '{print $1}')

    # 创建应用程序链接
    ln -s /Applications "/Volumes/$volume_name/Applications"

    # 设置 DMG 外观（如果有自定义背景图片）
    if [ -f "./assets/dmg-background.png" ]; then
        cp "./assets/dmg-background.png" "/Volumes/$volume_name/.background.png"
    fi

    # 卸载 DMG
    print_message "卸载临时 DMG..." $BLUE
    hdiutil detach "$device"

    # 转换为只读 DMG
    print_message "转换为最终 DMG..." $BLUE
    hdiutil convert "$temp_dmg_path" -format UDZO -imagekey zlib-level=9 -o "$dmg_path"

    # 清理临时文件
    rm -f "$temp_dmg_path"

    if [ -f "$dmg_path" ]; then
        print_message "✓ DMG 安装包创建完成: $dmg_path" $GREEN
        print_message "文件大小: $(du -h "$dmg_path" | cut -f1)" $BLUE
        return 0
    else
        print_message "✗ DMG 安装包创建失败" $RED
        return 1
    fi
}

# 函数：创建 ZIP 分发包
create_zip() {
    print_message "开始创建 ZIP 分发包..." $BLUE

    local app_path="./build/export/LifeTimer.app"
    local zip_path="./build/LifeTimer.zip"

    # 检查应用是否存在
    if [ ! -d "$app_path" ]; then
        print_message "错误: 未找到导出的应用，请先运行导出" $RED
        return 1
    fi

    # 删除已存在的 ZIP 文件
    rm -f "$zip_path"

    # 创建 ZIP 包
    cd "./build/export"
    zip -r "../LifeTimer.zip" "LifeTimer.app"
    cd "../.."

    if [ -f "$zip_path" ]; then
        print_message "✓ ZIP 分发包创建完成: $zip_path" $GREEN
        print_message "文件大小: $(du -h "$zip_path" | cut -f1)" $BLUE
        return 0
    else
        print_message "✗ ZIP 分发包创建失败" $RED
        return 1
    fi
}

# 函数：完整打包流程
package_app() {
    print_message "开始完整打包流程..." $BLUE
    print_message "==============================" $YELLOW

    # 清理之前的构建
    clean_build

    # 归档应用
    if ! archive_macos; then
        print_message "✗ 归档失败，停止打包流程" $RED
        exit 1
    fi

    # 导出应用
    if ! export_app; then
        print_message "✗ 导出失败，停止打包流程" $RED
        exit 1
    fi

    # 创建分发包
    print_message "创建分发包..." $BLUE
    create_dmg
    create_zip

    # 显示打包结果
    print_message "==============================" $YELLOW
    print_message "🎉 打包完成！" $GREEN
    print_message "构建产物位置:" $BLUE

    if [ -d "./build/export/LifeTimer.app" ]; then
        print_message "  应用程序: ./build/export/LifeTimer.app" $BLUE
    fi

    if [ -f "./build/LifeTimer.dmg" ]; then
        print_message "  DMG 安装包: ./build/LifeTimer.dmg" $BLUE
    fi

    if [ -f "./build/LifeTimer.zip" ]; then
        print_message "  ZIP 分发包: ./build/LifeTimer.zip" $BLUE
    fi

    print_message "==============================" $YELLOW
}

# 主函数
main() {
    print_message "🍅 番茄钟应用构建脚本" $YELLOW
    print_message "==============================" $YELLOW
    
    # 检查 Xcode
    check_xcode
    
    # 检查项目文件是否存在
    if [ ! -f "$PROJECT_PATH/project.pbxproj" ]; then
        print_message "错误: 未找到项目文件 $PROJECT_PATH" $RED
        exit 1
    fi
    
    case "$1" in
        "build-all")
            clean_build
            build_macos
            build_ios
            build_ipados
            print_message "🎉 所有平台构建完成!" $GREEN
            ;;
        "build-macos")
            build_macos
            ;;
        "build-ios")
            build_ios
            ;;
        "build-ipados")
            build_ipados
            ;;
        "run-macos")
            run_macos
            ;;
        "run-ios")
            run_ios
            ;;
        "run-ipados")
            run_ipados
            ;;
        "test-macos")
            test_macos
            ;;
        "archive")
            archive_macos
            ;;
        "export")
            export_app
            ;;
        "create-dmg")
            create_dmg
            ;;
        "create-zip")
            create_zip
            ;;
        "package")
            package_app
            ;;
        "clean")
            clean_build
            ;;
        "open")
            open_xcode
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            print_message "请指定操作选项，使用 '$0 help' 查看帮助" $YELLOW
            show_help
            ;;
        *)
            print_message "未知选项: $1" $RED
            print_message "使用 '$0 help' 查看可用选项" $YELLOW
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"