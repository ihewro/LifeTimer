#!/bin/bash

# LifeTimer 资源验证脚本
# 验证应用图标和其他资源文件是否完整

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 路径配置
ASSETS_PATH="./LifeTimer/Assets.xcassets"
APPICON_PATH="$ASSETS_PATH/AppIcon.appiconset"
CONTENTS_JSON="$APPICON_PATH/Contents.json"

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

# 函数：验证应用图标
verify_app_icons() {
    print_title "验证应用图标"
    
    # 检查 AppIcon.appiconset 目录是否存在
    if [ ! -d "$APPICON_PATH" ]; then
        print_message "❌ 错误: AppIcon.appiconset 目录不存在" $RED
        return 1
    fi
    print_message "✅ AppIcon.appiconset 目录存在" $GREEN
    
    # 检查 Contents.json 文件是否存在
    if [ ! -f "$CONTENTS_JSON" ]; then
        print_message "❌ 错误: Contents.json 文件不存在" $RED
        return 1
    fi
    print_message "✅ Contents.json 文件存在" $GREEN
    
    # 从 Contents.json 中提取所需的图标文件列表
    local required_icons=($(grep -o '"filename" : "[^"]*"' "$CONTENTS_JSON" | sed 's/"filename" : "//g' | sed 's/"//g'))
    
    print_message "检查图标文件..." $BLUE
    local missing_icons=()
    local total_icons=${#required_icons[@]}
    local found_icons=0
    
    for icon in "${required_icons[@]}"; do
        if [ -f "$APPICON_PATH/$icon" ]; then
            print_message "  ✅ $icon" $GREEN
            found_icons=$((found_icons + 1))
        else
            print_message "  ❌ $icon (缺失)" $RED
            missing_icons+=("$icon")
        fi
    done
    
    print_message "" $NC
    print_message "图标文件统计:" $BLUE
    print_message "  总计: $total_icons" $BLUE
    print_message "  找到: $found_icons" $GREEN
    print_message "  缺失: ${#missing_icons[@]}" $RED
    
    if [ ${#missing_icons[@]} -eq 0 ]; then
        print_message "✅ 所有应用图标文件完整" $GREEN
        return 0
    else
        print_message "❌ 发现缺失的图标文件:" $RED
        for icon in "${missing_icons[@]}"; do
            print_message "    - $icon" $RED
        done
        return 1
    fi
}

# 函数：验证图标文件大小
verify_icon_sizes() {
    print_title "验证图标文件大小"

    # 函数：获取预期尺寸
    get_expected_size() {
        case "$1" in
            "icon_16x16.png") echo "16x16" ;;
            "icon_16x16@2x.png") echo "32x32" ;;
            "icon_20x20.png") echo "20x20" ;;
            "icon_20x20@2x.png") echo "40x40" ;;
            "icon_20x20@3x.png") echo "60x60" ;;
            "icon_29x29.png") echo "29x29" ;;
            "icon_29x29@2x.png") echo "58x58" ;;
            "icon_29x29@3x.png") echo "87x87" ;;
            "icon_32x32.png") echo "32x32" ;;
            "icon_32x32@2x.png") echo "64x64" ;;
            "icon_40x40.png") echo "40x40" ;;
            "icon_40x40@2x.png") echo "80x80" ;;
            "icon_40x40@3x.png") echo "120x120" ;;
            "icon_60x60@2x.png") echo "120x120" ;;
            "icon_60x60@3x.png") echo "180x180" ;;
            "icon_76x76.png") echo "76x76" ;;
            "icon_76x76@2x.png") echo "152x152" ;;
            "icon_83.5x83.5@2x.png") echo "167x167" ;;
            "icon_128x128.png") echo "128x128" ;;
            "icon_128x128@2x.png") echo "256x256" ;;
            "icon_256x256.png") echo "256x256" ;;
            "icon_256x256@2x.png") echo "512x512" ;;
            "icon_512x512.png") echo "512x512" ;;
            "icon_512x512@2x.png") echo "1024x1024" ;;
            "icon_1024x1024.png") echo "1024x1024" ;;
            *) echo "" ;;
        esac
    }
    
    local size_errors=0
    
    # 检查是否安装了 ImageMagick 或 sips
    if command -v sips &> /dev/null; then
        print_message "使用 sips 验证图标尺寸..." $BLUE

        for icon_file in "$APPICON_PATH"/*.png; do
            if [ -f "$icon_file" ]; then
                local filename=$(basename "$icon_file")
                local expected_size=$(get_expected_size "$filename")

                if [ -n "$expected_size" ]; then
                    local actual_size=$(sips -g pixelWidth -g pixelHeight "$icon_file" 2>/dev/null | grep -E "pixelWidth|pixelHeight" | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')

                    if [ "$actual_size" = "$expected_size" ]; then
                        print_message "  ✅ $filename ($actual_size)" $GREEN
                    else
                        print_message "  ❌ $filename (实际: $actual_size, 预期: $expected_size)" $RED
                        size_errors=$((size_errors + 1))
                    fi
                fi
            fi
        done
    elif command -v identify &> /dev/null; then
        print_message "使用 ImageMagick 验证图标尺寸..." $BLUE

        for icon_file in "$APPICON_PATH"/*.png; do
            if [ -f "$icon_file" ]; then
                local filename=$(basename "$icon_file")
                local expected_size=$(get_expected_size "$filename")

                if [ -n "$expected_size" ]; then
                    local actual_size=$(identify -format "%wx%h" "$icon_file" 2>/dev/null)

                    if [ "$actual_size" = "$expected_size" ]; then
                        print_message "  ✅ $filename ($actual_size)" $GREEN
                    else
                        print_message "  ❌ $filename (实际: $actual_size, 预期: $expected_size)" $RED
                        size_errors=$((size_errors + 1))
                    fi
                fi
            fi
        done
    else
        print_message "⚠️  警告: 未找到 sips 或 ImageMagick，跳过尺寸验证" $YELLOW
        return 0
    fi
    
    if [ $size_errors -eq 0 ]; then
        print_message "✅ 所有图标尺寸正确" $GREEN
        return 0
    else
        print_message "❌ 发现 $size_errors 个尺寸错误的图标" $RED
        return 1
    fi
}

# 函数：验证图标文件格式
verify_icon_formats() {
    print_title "验证图标文件格式"
    
    local format_errors=0
    
    if command -v file &> /dev/null; then
        print_message "检查图标文件格式..." $BLUE
        
        for icon_file in "$APPICON_PATH"/*.png; do
            if [ -f "$icon_file" ]; then
                local file_info=$(file "$icon_file")
                local filename=$(basename "$icon_file")
                
                if echo "$file_info" | grep -q "PNG image data"; then
                    print_message "  ✅ $filename (PNG)" $GREEN
                else
                    print_message "  ❌ $filename (非PNG格式)" $RED
                    format_errors=$((format_errors + 1))
                fi
            fi
        done
    else
        print_message "⚠️  警告: 未找到 file 命令，跳过格式验证" $YELLOW
        return 0
    fi
    
    if [ $format_errors -eq 0 ]; then
        print_message "✅ 所有图标格式正确" $GREEN
        return 0
    else
        print_message "❌ 发现 $format_errors 个格式错误的图标" $RED
        return 1
    fi
}

# 函数：验证其他资源文件
verify_other_resources() {
    print_title "验证其他资源文件"
    
    # 检查 Assets.xcassets 目录
    if [ ! -d "$ASSETS_PATH" ]; then
        print_message "❌ 错误: Assets.xcassets 目录不存在" $RED
        return 1
    fi
    print_message "✅ Assets.xcassets 目录存在" $GREEN
    
    # 检查 Contents.json
    local main_contents="$ASSETS_PATH/Contents.json"
    if [ -f "$main_contents" ]; then
        print_message "✅ Assets.xcassets/Contents.json 存在" $GREEN
    else
        print_message "❌ Assets.xcassets/Contents.json 不存在" $RED
    fi
    
    # 检查其他可能的资源
    local other_resources=(
        "AccentColor.colorset"
        "LaunchScreen.storyboard"
    )
    
    for resource in "${other_resources[@]}"; do
        if [ -e "$ASSETS_PATH/$resource" ]; then
            print_message "✅ $resource 存在" $GREEN
        else
            print_message "ℹ️  $resource 不存在（可选）" $BLUE
        fi
    done
    
    return 0
}

# 函数：生成资源报告
generate_resource_report() {
    print_title "生成资源报告"
    
    local report_path="./build/resource_report.txt"
    mkdir -p "./build"
    
    {
        echo "LifeTimer 资源验证报告"
        echo "生成时间: $(date)"
        echo "========================================"
        echo ""
        
        echo "应用图标文件:"
        for icon_file in "$APPICON_PATH"/*.png; do
            if [ -f "$icon_file" ]; then
                local filename=$(basename "$icon_file")
                local file_size=$(du -h "$icon_file" | cut -f1)
                echo "  $filename ($file_size)"
            fi
        done
        
        echo ""
        echo "资源目录结构:"
        if command -v tree &> /dev/null; then
            tree "$ASSETS_PATH"
        else
            find "$ASSETS_PATH" -type f | sort
        fi
        
    } > "$report_path"
    
    print_message "✅ 资源报告已生成: $report_path" $GREEN
}

# 函数：完整资源验证
full_verification() {
    print_message "🔍 LifeTimer 资源验证工具" $PURPLE
    
    local verification_errors=0
    
    # 执行各项验证
    if ! verify_app_icons; then
        verification_errors=$((verification_errors + 1))
    fi

    if ! verify_icon_sizes; then
        verification_errors=$((verification_errors + 1))
    fi

    if ! verify_icon_formats; then
        verification_errors=$((verification_errors + 1))
    fi

    if ! verify_other_resources; then
        verification_errors=$((verification_errors + 1))
    fi
    
    # 生成报告
    generate_resource_report
    
    # 显示结果
    print_title "验证结果"
    
    if [ $verification_errors -eq 0 ]; then
        print_message "🎉 所有资源验证通过！" $GREEN
        print_message "应用资源已准备好用于分发" $GREEN
        return 0
    else
        print_message "❌ 发现 $verification_errors 个验证错误" $RED
        print_message "请修复上述问题后重新验证" $YELLOW
        return 1
    fi
}

# 函数：显示帮助信息
show_help() {
    echo "LifeTimer 资源验证工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  full           执行完整资源验证"
    echo "  icons          仅验证应用图标"
    echo "  sizes          仅验证图标尺寸"
    echo "  formats        仅验证图标格式"
    echo "  other          验证其他资源文件"
    echo "  report         生成资源报告"
    echo "  help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 full        # 执行完整资源验证"
    echo "  $0 icons       # 仅验证应用图标"
    echo "  $0 report      # 生成资源报告"
}

# 主函数
main() {
    case "$1" in
        "full"|"")
            full_verification
            ;;
        "icons")
            verify_app_icons
            ;;
        "sizes")
            verify_icon_sizes
            ;;
        "formats")
            verify_icon_formats
            ;;
        "other")
            verify_other_resources
            ;;
        "report")
            generate_resource_report
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
