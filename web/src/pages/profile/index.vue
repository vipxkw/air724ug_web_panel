<script setup lang="ts">
import router from '@/router'
import { useUserStore } from '@/stores'
import { ref } from 'vue'
import { showToast } from 'vant'
import request from '@/utils/request'

const userStore = useUserStore()
const userInfo = computed(() => userStore.userInfo)
const isLogin = computed(() => !!userInfo.value.name)

// 名言警句
const quote = computed(() => '生活不止眼前的苟且，还有诗和远方的田野')

// 修改用户信息弹窗相关数据
const showDialogPopup = ref(false)
const oldPassword = ref('')
const newUsername = ref('')
const newPassword = ref('')

function login() {
  if (isLogin.value)
    return

  router.push({ name: 'login', query: { redirect: 'profile' } })
}

function showChangeUserInfoDialog() {
  if (!isLogin.value) {
    login()
    return
  }
  // 初始化弹窗数据
  oldPassword.value = ''
  newUsername.value = userInfo.value.name || ''
  newPassword.value = ''
  showDialogPopup.value = true
}

async function changeUserInfo() {
  if (!oldPassword.value || !newUsername.value || !newPassword.value) {
    showToast('请填写完整信息')
    return
  }

  try {
    const res = await request.post('/change-user-info', {
      oldPassword: oldPassword.value,
      newUsername: newUsername.value,
      newPassword: newPassword.value,
    }) as { message: string, username: string, needRelogin: boolean }
    // 响应状态码 200 即为成功，处理响应体数据
    // 更新本地存储的用户信息，使用接口返回的最新用户名
    userStore.userInfo.name = res.username
    showToast(res.message || '用户信息修改成功') // 使用接口返回的 message 或默认提示
    showDialogPopup.value = false

    // 检查是否需要重新登录
    if (res.needRelogin) {
      showToast('用户信息已修改，请重新登录')
      // 跳转到登录页，并带上 redirect 参数指向当前页面，方便登录后返回
      router.push({ name: 'login', query: { redirect: router.currentRoute.value.fullPath } })
    }
  }
  catch (error) {
    showToast('请求失败，请稍后再试')
    console.error(error)
  }
}

// 处理注销登录
async function handleLogout() {
  try {
    await userStore.logout()
    showToast('注销成功')
    // 跳转到登录页
    router.push({ name: 'login' })
  }
  catch (error) {
    showToast('注销失败，请稍后再试')
    console.error(error)
  }
}
</script>

<template>
  <div>
    <VanCellGroup :inset="true">
      <van-cell
        center
        :is-link="!isLogin"
        @click="login"
      >
        <template #title>
          <span>{{ isLogin ? `${userInfo.name}` : $t('profile.login') }}</span>
        </template>
        <template #label>
          <span>{{ quote }}</span>
        </template>
      </van-cell>
    </VanCellGroup>

    <VanCellGroup :inset="true" class="!mt-16">
      <van-cell title="修改用户信息" icon="setting-o" is-link @click="showChangeUserInfoDialog">
        <template #icon>
          <div class="i-carbon:settings text-gray-400 mr-5 self-center" />
        </template>
      </van-cell>
      <van-cell title="注销登录" is-link @click="handleLogout">
        <template #icon>
          <div class="i-carbon:logout text-gray-400 mr-5 self-center" />
        </template>
      </van-cell>
    </VanCellGroup>

    <van-dialog
      v-model:show="showDialogPopup"
      title="修改用户信息"
      show-cancel-button
      @confirm="changeUserInfo"
    >
      <van-field
        v-model="newUsername"
        label="用户名"
        placeholder="请输入新用户名"
      />
      <van-field
        v-model="oldPassword"
        label="旧密码"
        placeholder="请输入旧密码"
        type="password"
      />
      <van-field
        v-model="newPassword"
        label="新密码"
        placeholder="请输入新密码"
        type="password"
      />
    </van-dialog>
  </div>
</template>

<route lang="json5">
{
  name: 'profile',
  meta: {
    title: '个人中心'
  },
}
</route>
