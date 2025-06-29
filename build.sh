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
PROJECT_NAME="PomodoroTimer"
SCHEME_NAME="PomodoroTimer"
PROJECT_PATH="./PomodoroTimer.xcodeproj"

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
    xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME_NAME" clean
    print_message "✓ 构建缓存已清理" $GREEN
}

# 函数：构建 macOS 版本
build_macos() {
    print_message "开始构建 macOS 版本..." $BLUE
    xcodebuild -project "$PROJECT_PATH" \
               -scheme "$SCHEME_NAME" \
               -destination 'platform=macOS' \
               -configuration Release \
               build
    print_message "✓ macOS 版本构建完成" $GREEN
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
    echo "选项:"
    echo "  build-all      构建所有平台版本"
    echo "  build-macos    构建 macOS 版本"
    echo "  build-ios      构建 iOS 版本"
    echo "  build-ipados   构建 iPadOS 版本"
    echo "  run-macos      运行 macOS 版本"
    echo "  run-ios        运行 iOS 模拟器版本"
    echo "  run-ipados     运行 iPadOS 模拟器版本"
    echo "  clean          清理构建缓存"
    echo "  open           在 Xcode 中打开项目"
    echo "  help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build-macos    # 构建 macOS 版本"
    echo "  $0 run-ios        # 运行 iOS 模拟器版本"
    echo "  $0 clean          # 清理构建缓存"
}

# 函数：在 Xcode 中打开项目
open_xcode() {
    print_message "在 Xcode 中打开项目..." $BLUE
    open "$PROJECT_PATH"
    print_message "✓ 项目已在 Xcode 中打开" $GREEN
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