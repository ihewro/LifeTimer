#!/bin/bash

# 生成应用图标脚本
# 将 SVG 图标转换为各种尺寸的 PNG 文件

# 检查是否有可用的转换工具，优先使用 macOS 内置工具
if command -v qlmanage &> /dev/null && command -v sips &> /dev/null; then
    CONVERTER="qlmanage_sips"
elif command -v rsvg-convert &> /dev/null; then
    CONVERTER="rsvg-convert"
elif command -v inkscape &> /dev/null; then
    # 测试 inkscape 是否真的可用
    if inkscape --version &> /dev/null; then
        CONVERTER="inkscape"
    else
        echo "警告: inkscape 已安装但无法正常工作，使用 macOS 内置工具"
        CONVERTER="qlmanage_sips"
    fi
else
    echo "错误: 需要安装图像转换工具"
    echo "可用选项:"
    echo "  brew install librsvg  # 安装 rsvg-convert"
    echo "  brew install inkscape  # 安装 inkscape"
    echo "  或使用 macOS 内置工具 (qlmanage + sips)"
    exit 1
fi

# 源 SVG 文件
SVG_FILE="app_icon.svg"
# 目标目录
ICON_DIR="PomodoroTimer/Assets.xcassets/AppIcon.appiconset"

# 检查源文件是否存在
if [ ! -f "$SVG_FILE" ]; then
    echo "错误: 找不到源文件 $SVG_FILE"
    exit 1
fi

# 创建目标目录（如果不存在）
mkdir -p "$ICON_DIR"

echo "开始生成应用图标..."

# 图标文件名和尺寸列表
icon_list=(
    "icon_16x16.png:16"
    "icon_16x16@2x.png:32"
    "icon_32x32.png:32"
    "icon_32x32@2x.png:64"
    "icon_128x128.png:128"
    "icon_128x128@2x.png:256"
    "icon_256x256.png:256"
    "icon_256x256@2x.png:512"
    "icon_512x512.png:512"
    "icon_512x512@2x.png:1024"
    "icon_20x20.png:20"
    "icon_20x20@2x.png:40"
    "icon_20x20@3x.png:60"
    "icon_29x29.png:29"
    "icon_29x29@2x.png:58"
    "icon_29x29@3x.png:87"
    "icon_40x40.png:40"
    "icon_40x40@2x.png:80"
    "icon_40x40@3x.png:120"
    "icon_60x60@2x.png:120"
    "icon_60x60@3x.png:180"
    "icon_76x76.png:76"
    "icon_76x76@2x.png:152"
    "icon_83.5x83.5@2x.png:167"
    "icon_1024x1024.png:1024"
)

# 生成函数
generate_icon() {
    local filename=$1
    local size=$2
    local output_path="$ICON_DIR/$filename"

    if [ "$CONVERTER" = "rsvg-convert" ]; then
        rsvg-convert -w $size -h $size "$SVG_FILE" -o "$output_path"
    elif [ "$CONVERTER" = "inkscape" ]; then
        inkscape --export-png="$output_path" --export-width=$size --export-height=$size "$SVG_FILE"
    elif [ "$CONVERTER" = "qlmanage_sips" ]; then
        # 使用 qlmanage 生成临时 PNG，然后用 sips 调整尺寸
        local temp_file="/tmp/temp_icon_$$.png"
        qlmanage -t -s 1024 -o /tmp "$SVG_FILE" > /dev/null 2>&1
        local ql_output="/tmp/$(basename "$SVG_FILE").png"
        if [ -f "$ql_output" ]; then
            sips -z $size $size "$ql_output" --out "$output_path" > /dev/null 2>&1
            rm -f "$ql_output"
        else
            return 1
        fi
    fi

    if [ $? -eq 0 ] && [ -f "$output_path" ]; then
        echo "✓ 生成 $filename (${size}x${size})"
    else
        echo "✗ 生成 $filename 失败"
        return 1
    fi
}

# 生成所有图标
echo "生成应用图标..."
for item in "${icon_list[@]}"; do
    filename="${item%:*}"
    size="${item#*:}"
    generate_icon "$filename" "$size"
done

echo "图标生成完成！"
echo "生成的文件位于: $ICON_DIR"

# 验证生成的文件
echo ""
echo "验证生成的文件:"
ls -la "$ICON_DIR"/*.png 2>/dev/null | wc -l | xargs echo "共生成了" | sed 's/$/ 个图标文件/'
