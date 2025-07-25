#!/bin/bash

# 生成应用图标脚本
# 将 PNG 图标转换为各种尺寸的 PNG 文件

# 检查是否有 sips 工具（macOS 内置）
if ! command -v sips &> /dev/null; then
    echo "错误: 需要 sips 工具 (macOS 内置)"
    exit 1
fi

# 源 PNG 文件
SOURCE_PNG="icons/icon.png"
# 目标目录
ICON_DIR="LifeTimer/Assets.xcassets/AppIcon.appiconset"

# 检查源文件是否存在
if [ ! -f "$SOURCE_PNG" ]; then
    echo "错误: 找不到源文件 $SOURCE_PNG"
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

    # 使用 sips 调整尺寸
    sips -z $size $size "$SOURCE_PNG" --out "$output_path" > /dev/null 2>&1

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
