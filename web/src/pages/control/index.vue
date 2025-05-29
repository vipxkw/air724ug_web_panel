<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { showToast } from 'vant'
import dayjs from 'dayjs'
import request from '@/utils/request'

interface Device {
  imei: string
  phone: string
  connected: boolean
  lastSeen: number
}

interface ConfigResponse {
  success: boolean
  result: Record<string, any>
}

const route = useRoute()
const device = ref<Device>()
const config = ref<Record<string, any>>()
const loading = ref(false)

// 编辑相关
const showEditPopup = ref(false)
const currentEditKey = ref('')
const editValue = ref<any>('')
const originalConfig = ref<Record<string, any>>({}) // 用于存储原始配置
const changedConfigs = ref<Record<string, any>>({}) // 用于存储变更的配置

// 新增字段相关
const showAddPopup = ref(false)
const newFieldName = ref('')
const newFieldValue = ref('')

// 短信相关
const showSmsPopup = ref(false)
const smsRecipients = ref('')
const smsContent = ref('')

// 打开编辑弹窗
function openEdit(key: string, value: any) {
  currentEditKey.value = key
  // 判断是否为布尔类型
  if (typeof value === 'boolean') {
    editValue.value = value
  }
  // 判断是否为数字类型
  else if (typeof value === 'number') {
    editValue.value = value
  }
  // 其他类型（包括对象、数组等）都转换为JSON字符串显示
  else {
    editValue.value = JSON.stringify(value, null, 2)
  }
  showEditPopup.value = true
}

// 保存编辑到变更记录
function saveEdit() {
  let valueToSave = editValue.value

  // 检查原始值类型并转换
  const originalValue = originalConfig.value[currentEditKey.value]
  if (typeof originalValue === 'number') {
    // 如果是数字类型，尝试转换为数字
    const numValue = Number(valueToSave)
    if (Number.isNaN(numValue)) {
      showToast('请输入有效的数字')
      return
    }
    valueToSave = numValue
  }
  else if (typeof originalValue === 'boolean') {
    // 如果是布尔类型，直接使用布尔值
    valueToSave = Boolean(valueToSave)
  }
  else if (typeof originalValue === 'object') {
    // 如果是对象类型，尝试解析JSON
    try {
      valueToSave = JSON.parse(valueToSave)
    }
    catch {
      showToast('请输入有效的JSON格式')
      return
    }
  }

  // 检查新值是否与原始值相同
  if (JSON.stringify(valueToSave) === JSON.stringify(originalValue)) {
    // 如果值恢复为原始值，从变更记录中移除
    delete changedConfigs.value[currentEditKey.value]
  }
  else {
    // 如果值与原始值不同，更新变更记录
    changedConfigs.value[currentEditKey.value] = valueToSave
  }

  // 更新config对象中的值
  if (config.value) {
    config.value[currentEditKey.value] = valueToSave
  }
  showEditPopup.value = false
}

// 打开新增字段弹窗
function openAddField() {
  newFieldName.value = ''
  newFieldValue.value = ''
  showAddPopup.value = true
}

// 保存新增字段
function saveNewField() {
  if (!newFieldName.value) {
    showToast('请输入字段名')
    return
  }
  if (newFieldName.value.startsWith('_')) {
    showToast('字段名不能以下划线开头')
    return
  }
  if (newFieldName.value in config.value) {
    showToast('字段名已存在')
    return
  }

  // 更新变更记录
  changedConfigs.value[newFieldName.value] = newFieldValue.value
  // 更新config对象，使新增字段立即显示在列表中
  if (config.value) {
    config.value[newFieldName.value] = newFieldValue.value
  }
  showAddPopup.value = false
}

// 保存所有配置
async function saveAllConfigs() {
  if (!device.value?.imei || Object.keys(changedConfigs.value).length === 0)
    return

  try {
    const response = await request.post<ConfigResponse>('/executeTask', {
      imei: device.value.imei,
      task: 'set_config',
      configs: changedConfigs.value,
    }) as unknown as ConfigResponse

    if (response.success) {
      showToast('保存成功')
      // 清空变更记录
      changedConfigs.value = {}
      // 重新获取配置
      fetchConfig()
    }
    else {
      showToast('保存失败')
    }
  }
  catch (error) {
    showToast('保存失败')
    console.error('保存失败:', error)
  }
}

// 删除字段
function deleteField(key: string) {
  // 如果字段在变更记录中，直接删除
  if (key in changedConfigs.value) {
    delete changedConfigs.value[key]
  }
  // 如果字段在原始配置中，标记为删除
  else if (config.value && key in config.value) {
    changedConfigs.value[key] = null
  }
  // 从配置中移除
  if (config.value) {
    delete config.value[key]
  }
}

// 发送短信
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
    const response = await request.post<ConfigResponse>('/executeTask', {
      imei: device.value.imei,
      task: 'send_sms',
      rcv_phone: smsRecipients.value,
      content: smsContent.value,
    }) as unknown as ConfigResponse

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

onMounted(() => {
  const deviceStr = route.query.device as string
  if (deviceStr) {
    device.value = JSON.parse(deviceStr)
    fetchConfig()
  }
})

// 获取设备配置
async function fetchConfig() {
  if (!device.value?.imei)
    return

  loading.value = true
  try {
    const response = await request.post<ConfigResponse>('/executeTask', {
      imei: device.value.imei,
      task: 'get_config',
    }) as unknown as ConfigResponse

    if (response.success) {
      config.value = response.result
      // 保存原始配置
      originalConfig.value = { ...response.result }
    }
    else {
      showToast('获取配置失败')
    }
  }
  catch (error) {
    showToast('获取配置失败')
    console.error('获取配置失败:', error)
  }
  finally {
    loading.value = false
  }
}

// 格式化时间
function formatTime(timestamp: number) {
  return dayjs(timestamp).format('YYYY-MM-DD HH:mm:ss')
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

    <van-cell-group :inset="true" title="设备配置">
      <van-cell v-if="loading" center>
        <template #title>
          <van-loading type="spinner" size="24px">
            加载中...
          </van-loading>
        </template>
      </van-cell>

      <template v-else-if="config">
        <van-cell
          v-for="(value, key) in config" v-show="!key.startsWith('_')" :key="key"
          :class="{ 'changed-field': key in changedConfigs }"
        >
          <template #title>
            <div class="cell-content">
              <div class="cell-left">
                <div class="cell-title">
                  {{ key }}
                </div>
                <div class="cell-label">
                  {{ value === null || value === undefined || value === '' ? '未配置' : (typeof value === 'object'
                    ? JSON.stringify(value) : String(value)) }}
                </div>
              </div>
              <div class="icon-group">
                <van-icon name="edit" class="edit-icon" @click.stop="openEdit(key, value)" />
                <van-icon name="delete" class="delete-icon" @click.stop="deleteField(key)" />
              </div>
            </div>
          </template>
        </van-cell>
      </template>

      <van-cell v-else title="暂无配置信息" />

      <van-cell>
        <template #title>
          <van-button plain block type="primary" @click="openAddField">
            新增字段
          </van-button>
        </template>
      </van-cell>

      <van-cell>
        <template #title>
          <van-button block type="primary" :disabled="Object.keys(changedConfigs).length === 0" @click="saveAllConfigs">
            保存所有配置
          </van-button>
        </template>
      </van-cell>
    </van-cell-group>

    <!-- 编辑弹窗 -->
    <van-popup v-model:show="showEditPopup" position="bottom" round>
      <div class="edit-popup">
        <div class="edit-header">
          <span class="edit-title">编辑配置</span>
          <van-icon name="cross" @click="showEditPopup = false" />
        </div>
        <div class="edit-content">
          <template v-if="typeof editValue === 'boolean'">
            <div class="boolean-edit">
              <span class="edit-label">{{ currentEditKey }}</span>
              <van-switch v-model="editValue" size="24" />
            </div>
          </template>
          <template v-else>
            <div class="edit-label">
              {{ currentEditKey }}
            </div>
            <van-field
              v-model="editValue"
              :type="typeof originalConfig[currentEditKey] === 'number' ? 'number' : 'textarea'" rows="4" autosize
              maxlength="500" show-word-limit placeholder="请输入配置值"
            />
          </template>
        </div>
        <div class="edit-footer">
          <van-button block type="primary" @click="saveEdit">
            确定
          </van-button>
        </div>
      </div>
    </van-popup>

    <!-- 新增字段弹窗 -->
    <van-popup v-model:show="showAddPopup" position="bottom" round>
      <div class="edit-popup">
        <div class="edit-header">
          <span class="edit-title">新增字段</span>
          <van-icon name="cross" @click="showAddPopup = false" />
        </div>
        <div>
          <van-field
            v-model="newFieldName" label="字段名" placeholder="请输入字段名"
            :rules="[{ required: true, message: '请输入字段名' }]"
          />
          <van-field v-model="newFieldValue" label="字段值" type="textarea" rows="4" autosize placeholder="请输入字段值" />
        </div>
        <div class="edit-footer">
          <van-button block type="primary" @click="saveNewField">
            确定
          </van-button>
        </div>
      </div>
    </van-popup>

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
.edit-icon {
  font-size: 18px;
  color: #1989fa;
  padding: 10px;
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

.boolean-edit {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
}

.boolean-edit .edit-label {
  margin-bottom: 0;
}

.van-button {
  width: 100%;
}

.changed-field {
  background-color: #f0f9ff;
}

.changed-field :deep(.van-cell__title) {
  color: #1989fa;
  font-weight: 500;
}

.changed-field :deep(.van-cell__label) {
  color: #1989fa;
}

.van-button--plain {
  margin: 8px 0;
}

.cell-content {
  display: flex;
  align-items: center;
  width: 100%;
  overflow: hidden;
}

:deep(.van-cell__title) {
  overflow: hidden;
}

.cell-left {
  flex: 1;
  margin-right: 8px;
  width: 70%;
}

.cell-title {
  font-size: 14px;
  color: #323233;
  margin-bottom: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cell-label {
  font-size: 12px;
  color: #969799;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.icon-group {
  display: flex;
  align-items: center;
  flex-shrink: 0;
}

.edit-icon,
.delete-icon {
  font-size: 18px;
  padding: 8px;
}

.edit-icon {
  color: #1989fa;
}

.delete-icon {
  color: #ee0a24;
}

.van-button--disabled {
  opacity: 0.5;
  cursor: not-allowed;
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
