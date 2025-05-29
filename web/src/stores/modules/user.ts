import { defineStore } from 'pinia'
import type { LoginData, UserState } from '@/api/user'
import { clearToken, setToken } from '@/utils/auth'

import {
  getEmailCode,
  resetPassword,
  login as userLogin,
  logout as userLogout,
  register as userRegister,
} from '@/api/user'

const InitUserInfo = {
  uid: 0,
  name: '',
  avatar: '',
}

export const useUserStore = defineStore('user', () => {
  const userInfo = ref<UserState>({ ...InitUserInfo })

  // Set user's information
  const setInfo = (partial: Partial<UserState>) => {
    userInfo.value = { ...partial }
  }

  const info = async () => {}

  const login = async (loginForm: LoginData) => {
    try {
      const { token } = await userLogin(loginForm)
      // 保存JWT token
      if (token) {
        setToken(token)
        // 登录成功后更新用户信息，使用登录表单的用户名
        userInfo.value = { ...userInfo.value, name: loginForm.username }
      }
    }
    catch (error) {
      clearToken()
      throw error
    }
  }

  const logout = async () => {
    try {
      await userLogout()
    }
    finally {
      clearToken()
      setInfo({ ...InitUserInfo })
    }
  }

  const getCode = async () => {
    try {
      const data = await getEmailCode()
      return data
    }
    catch {}
  }

  const reset = async () => {
    try {
      const data = await resetPassword()
      return data
    }
    catch {}
  }

  const register = async () => {
    try {
      const data = await userRegister()
      return data
    }
    catch {}
  }

  return {
    userInfo,
    info,
    login,
    logout,
    getCode,
    reset,
    register,
  }
}, {
  persist: true,
})

export default useUserStore
