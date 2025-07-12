#!/bin/bash

# 修复图标内边距脚本
# 为图标添加适当的内边距，使其与其他macOS应用图标大小一致

echo "🔧 开始修复图标内边距..."

# 检查源文件是否存在
if [ ! -f "icon.png" ]; then
    echo "❌ 错误：找不到源图标文件 icon.png"
    exit 1
fi

# 创建备份
echo "📦 创建原始图标备份..."
cp icon.png icon_original_backup.png

# 获取原始图标信息
echo "📊 分析原始图标..."
original_info=$(sips -g pixelWidth -g pixelHeight icon.png)
echo "原始图标信息: $original_info"

# 创建带内边距的新图标
# 将原始图标缩小到85%，然后居中放置在2048x2048的画布上
# 这样可以在四周留出约7.5%的内边距

echo "🎨 调整图标大小和内边距..."

# 第一步：将原始图标缩小到85%（约1740x1740）
sips --resampleWidth 1740 --resampleHeight 1740 icon.png --out icon_resized.png

# 第二步：创建带透明背景的2048x2048图标
# 使用更好的方法来处理透明背景
if command -v magick &> /dev/null; then
    echo "🎭 使用ImageMagick创建透明背景图标..."
    # 直接使用ImageMagick创建带透明背景的居中图标
    magick icon_resized.png -background transparent -gravity center -extent 2048x2048 icon_fixed.png
elif command -v convert &> /dev/null; then
    echo "🎭 使用ImageMagick convert创建透明背景图标..."
    # 使用convert命令（旧版ImageMagick）
    convert icon_resized.png -background transparent -gravity center -extent 2048x2048 icon_fixed.png
else
    echo "⚠️  ImageMagick未安装，安装ImageMagick以获得透明背景..."
    echo "🔧 正在尝试安装ImageMagick..."

    # 尝试使用Homebrew安装ImageMagick
    if command -v brew &> /dev/null; then
        echo "📦 使用Homebrew安装ImageMagick..."
        brew install imagemagick

        if command -v magick &> /dev/null; then
            echo "✅ ImageMagick安装成功，创建透明背景图标..."
            magick icon_resized.png -background transparent -gravity center -extent 2048x2048 icon_fixed.png
        else
            echo "❌ ImageMagick安装失败，使用备用方案..."
            # 备用方案：使用sips但警告用户
            echo "⚠️  警告：将使用白色背景，建议手动安装ImageMagick"
            sips --padToHeightWidth 2048 2048 --padColor FFFFFF icon_resized.png --out icon_fixed.png
        fi
    else
        echo "❌ 未找到Homebrew，无法自动安装ImageMagick"
        echo "⚠️  警告：将使用白色背景，建议手动安装ImageMagick"
        echo "💡 安装方法：brew install imagemagick"
        sips --padToHeightWidth 2048 2048 --padColor FFFFFF icon_resized.png --out icon_fixed.png
    fi
fi

# 验证新图标
if [ -f "icon_fixed.png" ]; then
    echo "✅ 图标调整完成"
    
    # 显示新图标信息
    new_info=$(sips -g pixelWidth -g pixelHeight icon_fixed.png)
    echo "新图标信息: $new_info"
    
    # 替换原始图标
    mv icon_fixed.png icon.png
    
    # 清理临时文件
    rm -f icon_resized.png icon_padded.png
    
    echo "🔄 更新icons目录中的图标..."
    cp icon.png icons/icon.png
    
    echo "✅ 图标内边距修复完成！"
    echo ""
    echo "📋 修复详情："
    echo "   • 原始图标已备份为 icon_original_backup.png"
    echo "   • 图标内容缩小到85%"
    echo "   • 在四周添加了7.5%的内边距"
    echo "   • 总尺寸保持2048x2048像素"
    echo ""
    echo "🔄 请运行以下命令重新生成应用图标："
    echo "   ./generate_app_icons.sh && ./refresh_app_icon.sh"
    
else
    echo "❌ 图标调整失败"
    exit 1
fi
