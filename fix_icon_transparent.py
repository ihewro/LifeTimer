#!/usr/bin/env python3
"""
修复图标透明背景脚本
为图标添加适当的内边距，并确保背景是透明的
"""

import os
import sys
from PIL import Image, ImageOps
import shutil

def fix_icon_padding(input_path, output_path, padding_percent=15):
    """
    为图标添加内边距并确保透明背景
    
    Args:
        input_path: 输入图标路径
        output_path: 输出图标路径
        padding_percent: 内边距百分比 (默认15%)
    """
    try:
        # 打开原始图标
        print(f"📖 读取原始图标: {input_path}")
        original = Image.open(input_path)
        
        # 确保图像有alpha通道（透明度）
        if original.mode != 'RGBA':
            print("🔄 转换为RGBA模式以支持透明度...")
            original = original.convert('RGBA')
        
        # 获取原始尺寸
        original_width, original_height = original.size
        print(f"📏 原始尺寸: {original_width}x{original_height}")
        
        # 计算新的内容尺寸（减去内边距）
        content_size = int(min(original_width, original_height) * (100 - padding_percent) / 100)
        print(f"🎯 内容尺寸: {content_size}x{content_size} (内边距: {padding_percent}%)")
        
        # 调整图标内容大小
        print("🔄 调整图标内容大小...")
        resized = original.resize((content_size, content_size), Image.Resampling.LANCZOS)
        
        # 创建新的2048x2048透明画布
        canvas_size = 2048
        print(f"🎨 创建 {canvas_size}x{canvas_size} 透明画布...")
        new_image = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
        
        # 计算居中位置
        x = (canvas_size - content_size) // 2
        y = (canvas_size - content_size) // 2
        print(f"📍 居中位置: ({x}, {y})")
        
        # 将调整后的图标粘贴到画布中心
        new_image.paste(resized, (x, y), resized)
        
        # 保存新图标
        print(f"💾 保存新图标: {output_path}")
        new_image.save(output_path, 'PNG')
        
        # 验证保存的图像
        saved_image = Image.open(output_path)
        print(f"✅ 验证: {saved_image.size}, 模式: {saved_image.mode}")
        
        return True
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        return False

def main():
    print("🔧 开始修复图标透明背景和内边距...")
    
    input_file = "icon.png"
    backup_file = "icon_original_backup.png"
    output_file = "icon_fixed_transparent.png"
    
    # 检查输入文件
    if not os.path.exists(input_file):
        print(f"❌ 错误：找不到源图标文件 {input_file}")
        sys.exit(1)
    
    # 创建备份（如果还没有的话）
    if not os.path.exists(backup_file):
        print(f"📦 创建备份: {backup_file}")
        shutil.copy2(input_file, backup_file)
    else:
        print(f"📦 备份已存在: {backup_file}")
    
    # 修复图标
    success = fix_icon_padding(input_file, output_file, padding_percent=15)
    
    if success:
        print("✅ 图标修复成功！")
        
        # 替换原始文件
        print(f"🔄 替换原始文件...")
        shutil.move(output_file, input_file)
        
        # 更新icons目录
        icons_dir = "icons"
        if os.path.exists(icons_dir):
            icons_file = os.path.join(icons_dir, "icon.png")
            print(f"🔄 更新 {icons_file}")
            shutil.copy2(input_file, icons_file)
        
        print("")
        print("📋 修复详情：")
        print("   • 图标内容缩小到85%")
        print("   • 在四周添加了15%的透明内边距")
        print("   • 背景完全透明")
        print("   • 总尺寸保持2048x2048像素")
        print("")
        print("🔄 请运行以下命令重新生成应用图标：")
        print("   ./generate_app_icons.sh && ./refresh_app_icon.sh")
        
    else:
        print("❌ 图标修复失败")
        sys.exit(1)

if __name__ == "__main__":
    main()
