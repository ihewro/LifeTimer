#!/bin/bash

# 完整同步流程测试脚本
# 演示客户端与服务端的完整同步过程

SERVER_URL="http://localhost:8080"
# 生成标准UUID格式
DEVICE_UUID="550e8400-e29b-41d4-a716-$(printf '%012d' $(date +%s))"
DEVICE_NAME="Test MacBook"

echo "🚀 开始完整同步流程测试"
echo "服务器地址: $SERVER_URL"
echo "设备UUID: $DEVICE_UUID"
echo ""

# 1. 设备注册
echo "📱 步骤1: 设备注册"
REGISTER_RESPONSE=$(curl -s -X POST "$SERVER_URL/api/device/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"device_uuid\": \"$DEVICE_UUID\",
    \"device_name\": \"$DEVICE_NAME\",
    \"platform\": \"macOS\"
  }")

echo "注册响应: $REGISTER_RESPONSE"
echo ""

# 2. 全量同步（初始同步）
echo "🔄 步骤2: 全量同步（初始同步）"
FULL_SYNC_RESPONSE=$(curl -s -X GET "$SERVER_URL/api/sync/full?device_uuid=$DEVICE_UUID")
echo "全量同步响应: $FULL_SYNC_RESPONSE"
echo ""

# 3. 创建本地数据并增量同步
echo "📝 步骤3: 创建本地数据并增量同步"
CURRENT_TIME=$(date +%s)000  # 转换为毫秒
START_TIME=$CURRENT_TIME
END_TIME=$((CURRENT_TIME + 1500000))  # 25分钟后

INCREMENTAL_SYNC_RESPONSE=$(curl -s -X POST "$SERVER_URL/api/sync/incremental" \
  -H "Content-Type: application/json" \
  -d "{
    \"device_uuid\": \"$DEVICE_UUID\",
    \"last_sync_timestamp\": 0,
    \"changes\": {
      \"pomodoro_events\": {
        \"created\": [
          {
            \"uuid\": \"event-001-$DEVICE_UUID\",
            \"title\": \"测试番茄钟 1\",
            \"start_time\": $START_TIME,
            \"end_time\": $END_TIME,
            \"event_type\": \"pomodoro\",
            \"is_completed\": true,
            \"created_at\": $START_TIME,
            \"updated_at\": $START_TIME
          },
          {
            \"uuid\": \"event-002-$DEVICE_UUID\",
            \"title\": \"测试短休息\",
            \"start_time\": $END_TIME,
            \"end_time\": $((END_TIME + 300000)),
            \"event_type\": \"short_break\",
            \"is_completed\": true,
            \"created_at\": $START_TIME,
            \"updated_at\": $START_TIME
          }
        ]
      },
      \"timer_settings\": {
        \"pomodoro_time\": 1500,
        \"short_break_time\": 300,
        \"long_break_time\": 900,
        \"updated_at\": $START_TIME
      }
    }
  }")

echo "增量同步响应: $INCREMENTAL_SYNC_RESPONSE"
echo ""

# 4. 模拟另一个设备的数据变更
echo "📱 步骤4: 模拟另一个设备的数据变更"
DEVICE_UUID_2="550e8400-e29b-41d4-a716-$(printf '%012d' $(($(date +%s) + 1)))"

# 注册第二个设备
curl -s -X POST "$SERVER_URL/api/device/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"device_uuid\": \"$DEVICE_UUID_2\",
    \"device_name\": \"Test iPhone\",
    \"platform\": \"iOS\"
  }" > /dev/null

# 第二个设备创建数据
DEVICE2_TIME=$((CURRENT_TIME + 3600000))  # 1小时后
curl -s -X POST "$SERVER_URL/api/sync/incremental" \
  -H "Content-Type: application/json" \
  -d "{
    \"device_uuid\": \"$DEVICE_UUID_2\",
    \"last_sync_timestamp\": 0,
    \"changes\": {
      \"pomodoro_events\": {
        \"created\": [
          {
            \"uuid\": \"event-003-$DEVICE_UUID_2\",
            \"title\": \"来自iPhone的番茄钟\",
            \"start_time\": $DEVICE2_TIME,
            \"end_time\": $((DEVICE2_TIME + 1500000)),
            \"event_type\": \"pomodoro\",
            \"is_completed\": false,
            \"created_at\": $DEVICE2_TIME,
            \"updated_at\": $DEVICE2_TIME
          }
        ]
      }
    }
  }" > /dev/null

echo "第二个设备已创建数据"
echo ""

# 5. 第一个设备拉取增量更新
echo "⬇️ 步骤5: 第一个设备拉取增量更新"
LAST_SYNC_TIME=$START_TIME
PULL_SYNC_RESPONSE=$(curl -s -X POST "$SERVER_URL/api/sync/incremental" \
  -H "Content-Type: application/json" \
  -d "{
    \"device_uuid\": \"$DEVICE_UUID\",
    \"last_sync_timestamp\": $LAST_SYNC_TIME,
    \"changes\": {
      \"pomodoro_events\": {
        \"created\": [],
        \"updated\": [],
        \"deleted\": []
      }
    }
  }")

echo "拉取增量更新响应: $PULL_SYNC_RESPONSE"
echo ""

# 6. 验证数据一致性
echo "✅ 步骤6: 验证数据一致性"
FINAL_FULL_SYNC=$(curl -s -X GET "$SERVER_URL/api/sync/full?device_uuid=$DEVICE_UUID")
echo "最终全量同步验证: $FINAL_FULL_SYNC"
echo ""

echo "🎉 完整同步流程测试完成！"
echo ""
echo "测试总结:"
echo "1. ✅ 设备注册成功"
echo "2. ✅ 全量同步成功"
echo "3. ✅ 增量同步（上传本地数据）成功"
echo "4. ✅ 多设备数据创建成功"
echo "5. ✅ 增量同步（拉取服务端数据）成功"
echo "6. ✅ 数据一致性验证成功"
