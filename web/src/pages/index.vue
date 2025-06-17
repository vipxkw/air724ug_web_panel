<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { showToast } from 'vant'
import request from '@/utils/request'
import { useRouter } from 'vue-router'

interface Device {
  imei: string
  phone: string
  connected: boolean
  lastSeen: number
}

const deviceList = ref<Device[]>([])
const loading = ref(false)
const router = useRouter()
const searchQuery = ref('')

// 过滤后的设备列表
const filteredDevices = computed(() => {
  if (!searchQuery.value)
    return deviceList.value

  const query = searchQuery.value.toLowerCase()
  return deviceList.value.filter(device =>
    device.imei.toLowerCase().includes(query)
    || (device.phone && device.phone.toLowerCase().includes(query)),
  )
})

// 跳转到控制页面
function goToControl(device: Device) {
  router.push({
    path: '/control',
    query: { device: JSON.stringify(device) },
  })
}

// 获取设备列表
async function fetchDeviceList() {
  loading.value = true
  try {
    const response = await request.get<Device[]>('/userPool')
    deviceList.value = response as unknown as Device[]
  }
  catch (error) {
    showToast('获取设备列表失败')
    console.error('获取设备列表失败:', error)
  }
  finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchDeviceList()
})
</script>

<template>
  <div class="device-list">
    <template v-if="deviceList.length > 0">
      <van-search v-model="searchQuery" class="search-bar" placeholder="搜索 IMEI 或手机号" />
      <van-pull-refresh v-model="loading" @refresh="fetchDeviceList">
        <van-cell-group :inset="true">
          <van-cell v-if="loading" center>
            <template #title>
              <van-loading type="spinner" size="24px">
                加载中...
              </van-loading>
            </template>
          </van-cell>
          <template v-else>
            <van-cell
              v-for="device in filteredDevices" :key="device.imei" :title="device.imei"
              :label="`No: ${device.phone || '未设置'}`" is-link @click="goToControl(device)"
            >
              <template #right-icon>
                <van-tag :type="device.connected ? 'success' : 'danger'" size="medium" round class="status-tag">
                  <span class="status-dot" :style="{ background: device.connected ? '#4ade80' : '#f56c6c' }" />
                  {{ device.connected ? 'ONLINE' : 'OFFLINE' }}
                </van-tag>
              </template>
            </van-cell>
          </template>
        </van-cell-group>
      </van-pull-refresh>
    </template>
    <template v-if="deviceList.length === 0">
      <van-empty class="custom-empty" description="暂无设备数据">
        <template #bottom>
          <van-button round type="primary" size="small" @click="fetchDeviceList">
            刷新
          </van-button>
        </template>
      </van-empty>
    </template>
  </div>
</template>

<route lang="json5">
{
  name: 'home',
  meta: {
    title: '设备列表',
  },
}
</route>

<style scoped>
.device-list {
  display: flex;
  flex-direction: column;
  height: calc(100vh - var(--van-nav-bar-height) - var(--van-tabbar-height) - 32px);
}

.van-pull-refresh {
  flex: 1;
}

.search-bar {
  margin: -16px;
  margin-bottom: 16px;
}
.van-cell {
  padding-top: 8px;
  padding-bottom: 8px;
}

.status-tag {
  display: flex;
  align-items: center;
  font-size: 13px;
  padding: 0 8px;
  border-radius: 999px;
  font-weight: 500;
  box-shadow: 0 0px 2px rgba(0, 0, 0, 0.1);
  height: 20px;
}

.status-dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  margin-right: 4px;
}

.van-tag--success {
  background-color: #4ade80;
}

.van-tag--danger {
  background-color: #f56c6c;
}

.custom-empty {
  padding: 32px 0;
  background-color: #fff;
}
</style>
