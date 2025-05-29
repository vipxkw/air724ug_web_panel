<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores'

import logo from '~/images/logo.svg'
import logoDark from '~/images/logo-dark.svg'

const { t } = useI18n()
const router = useRouter()
const userStore = useUserStore()
const loading = ref(false)

const dark = ref<boolean>(isDark.value)

watch(
  () => isDark.value,
  (newMode) => {
    dark.value = newMode
  },
)

const postData = reactive({
  username: '',
  password: '',
})

const rules = reactive({
  username: [
    { required: true, message: t('login.pleaseEnterUsername') },
  ],
  password: [
    { required: true, message: t('login.pleaseEnterPassword') },
  ],
})

async function login(values: any) {
  try {
    loading.value = true
    await userStore.login({ ...postData, ...values })
    const { redirect, ...othersQuery } = router.currentRoute.value.query

    if (redirect) {
      router.push({
        path: redirect as string,
        query: {
          ...othersQuery,
        },
      })
    }
    else {
      router.push({
        name: 'home',
        query: {
          ...othersQuery,
        },
      })
    }
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="m-x-a text-center w-7xl">
    <div class="mb-32 mt-20">
      <van-image :src="dark ? logoDark : logo" class="h-120 w-120" alt="brand logo" />
    </div>

    <van-form :model="postData" :rules="rules" validate-trigger="onSubmit" @submit="login">
      <div class="rounded-3xl overflow-hidden">
        <van-field
          v-model="postData.username"
          :rules="rules.username"
          name="username"
          :placeholder="$t('login.username')"
        />
      </div>

      <div class="mt-16 rounded-3xl overflow-hidden">
        <van-field
          v-model="postData.password"
          type="password"
          :rules="rules.password"
          name="password"
          :placeholder="$t('login.password')"
        />
      </div>

      <div class="mt-16">
        <van-button
          :loading="loading"
          type="primary"
          native-type="submit"
          round block
        >
          {{ $t('login.login') }}
        </van-button>
      </div>
    </van-form>
  </div>
</template>

<route lang="json5">
{
  name: 'login',
  meta: {
    i18n: 'menus.login'
  },
}
</route>
