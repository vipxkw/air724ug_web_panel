<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { showToast } from 'vant'
import dayjs from 'dayjs'
import request from '@/utils/request'

interface Device {
  imei: string
  phone: string
  connected: boolean
  lastSeen: number
}

const route = useRoute()
const router = useRouter()
const device = ref<Device>()

// 短信相关
const showSmsPopup = ref(false)
const smsRecipients = ref('')
const smsContent = ref('')

onMounted(() => {
  const deviceStr = route.query.device as string
  if (deviceStr) {
    device.value = JSON.parse(deviceStr)
  }
})

function formatTime(timestamp: number) {
  return dayjs(timestamp).format('YYYY-MM-DD HH:mm:ss')
}

function goEditConfig() {
  router.push({
    path: '/config',
    query: { device: JSON.stringify(device.value) },
  })
}

async function sendSms() {
  if (!device.value?.imei)
    return
  if (!smsRecipients.value) {
    showToast('请输入收件人')
    return
  }
  if (!smsContent.value) {
    showToast('请输入短信内容')
    return
  }

  try {
    const response = await request.post<any>('/executeTask', {
      imei: device.value.imei,
      task: 'send_sms',
      rcv_phone: smsRecipients.value,
      content: smsContent.value,
    }) as any

    if (response.success) {
      showToast('发送成功')
      showSmsPopup.value = false
      // 清空输入
      smsRecipients.value = ''
      smsContent.value = ''
    }
    else {
      showToast('发送失败')
    }
  }
  catch (error) {
    showToast('发送失败')
    console.error('发送失败:', error)
  }
}
</script>

<template>
  <div class="control-page">
    <van-cell-group :inset="true">
      <van-cell title="IMEI" :value="device?.imei" />
      <van-cell title="手机号" :value="device?.phone || '未设置'" />
      <van-cell title="在线状态">
        <template #value>
          <van-tag :type="device?.connected ? 'success' : 'danger'" size="medium">
            {{ device?.connected ? '在线' : '离线' }}
          </van-tag>
        </template>
      </van-cell>
      <van-cell title="最后在线时间" :value="device?.lastSeen ? formatTime(device.lastSeen) : '-'" />
    </van-cell-group>

    <van-cell-group inset style="margin-top: 16px;">
      <van-cell title="修改配置" icon="setting-o" is-link @click="goEditConfig">
        <template #icon>
          <div class="i-carbon:settings text-gray-400 mr-5 self-center" />
        </template>
      </van-cell>
    </van-cell-group>

    <!-- 发送短信弹窗 -->
    <van-popup v-model:show="showSmsPopup" position="bottom" round>
      <div class="edit-popup">
        <div class="edit-header">
          <span class="edit-title">发送短信</span>
          <van-icon name="cross" @click="showSmsPopup = false" />
        </div>
        <div>
          <van-field
            v-model="smsRecipients" label="收件人" placeholder="请输入收件人手机号，多个收件人用逗号分隔"
            :rules="[{ required: true, message: '请输入收件人' }]"
          />
          <van-field
            v-model="smsContent" label="短信内容" type="textarea" rows="4" autosize maxlength="500" show-word-limit
            placeholder="请输入短信内容" :rules="[{ required: true, message: '请输入短信内容' }]"
          />
        </div>
        <div class="edit-footer">
          <van-button block type="primary" @click="sendSms">
            发送
          </van-button>
        </div>
      </div>
    </van-popup>

    <!-- 发送短信悬浮按钮 -->
    <div class="sms-fab" @click="showSmsPopup = true">
      <van-icon name="chat-o" size="24" />
    </div>
  </div>
</template>

<style scoped>
.control-page {
  padding-bottom: 32px;
}

.edit-popup {
  padding: 16px;
}

.edit-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.edit-title {
  font-size: 16px;
  font-weight: bold;
}

.edit-content {
  margin-bottom: 16px;
}

.edit-label {
  font-size: 14px;
  color: #646566;
  margin-bottom: 8px;
}

.edit-content :deep(.van-field__word-limit) {
  margin-top: 8px;
}

.edit-content :deep(.van-field__body) {
  min-height: 100px;
}

.edit-content :deep(.van-field) {
  padding: 0;
}

.edit-footer {
  padding: 16px 0;
}

.sms-fab {
  position: fixed;
  right: 16px;
  bottom: 16px;
  width: 48px;
  height: 48px;
  border-radius: 24px;
  background-color: #1989fa;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  cursor: pointer;
  z-index: 99;
}

.sms-fab:active {
  transform: scale(0.95);
}
</style>

<route lang="json5">
{
  name: 'control',
  meta: {
    title: '设备控制面板',
  },
}
</route>
