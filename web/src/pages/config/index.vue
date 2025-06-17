<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { showToast } from 'vant'
import MonacoEditor, { loader } from '@guolao/vue-monaco-editor'
import request from '@/utils/request'

import * as monaco from 'monaco-editor'
import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker'
import JsonWorker from 'monaco-editor/esm/vs/language/json/json.worker?worker'
import CssWorker from 'monaco-editor/esm/vs/language/css/css.worker?worker'
import HtmlWorker from 'monaco-editor/esm/vs/language/html/html.worker?worker'
import TsWorker from 'monaco-editor/esm/vs/language/typescript/ts.worker?worker'

// 使用 globalThis
(globalThis as any).MonacoEnvironment = {
  getWorker(_, label) {
    if (label === 'json') {
      return new JsonWorker()
    }
    if (label === 'css' || label === 'scss' || label === 'less') {
      return new CssWorker()
    }
    if (label === 'html' || label === 'handlebars' || label === 'razor') {
      return new HtmlWorker()
    }
    if (label === 'typescript' || label === 'javascript') {
      return new TsWorker()
    }
    return new EditorWorker()
  },
}

loader.config({ monaco })

const route = useRoute()
const router = useRouter()
const device = ref<any>(route.query.device ? JSON.parse(route.query.device as string) : {})
const configText = ref('')
const loading = ref(false)

// 获取配置
enum FetchStatus { INIT, LOADING, DONE }
const fetchStatus = ref(FetchStatus.INIT)
async function fetchConfig() {
  if (!device.value?.imei)
    return
  loading.value = true
  try {
    const response = await request.post('/executeTask', {
      imei: device.value.imei,
      task: 'get_config',
    }) as any
    if (response.success) {
      configText.value = response.result || ''
    }
    else {
      showToast('获取配置失败')
    }
  }
  catch {
    showToast('获取配置失败')
  }
  finally {
    loading.value = false
    fetchStatus.value = FetchStatus.DONE
  }
}

// 保存配置
async function saveConfig() {
  if (!device.value?.imei)
    return
  loading.value = true
  try {
    const response = await request.post('/executeTask', {
      imei: device.value.imei,
      task: 'set_config',
      configText: configText.value,
    }) as any
    if (response.success) {
      showToast('保存成功')
      router.back()
    }
    else {
      showToast('保存失败')
    }
  }
  catch {
    showToast('保存失败')
  }
  finally {
    loading.value = false
  }
}

fetchConfig()
</script>

<template>
  <div class="config-edit-page">
    <div class="editor-container">
      <MonacoEditor v-model:value="configText" language="lua" theme="vs-dark" :options="{ fontSize: 14 }" />
    </div>
    <div class="footer">
      <van-button block type="primary" :loading="loading" @click="saveConfig">
        保存配置
      </van-button>
    </div>
  </div>
</template>

<style scoped>
.config-edit-page {
  display: flex;
  flex-direction: column;
  height: calc(100vh - var(--van-nav-bar-height));
  margin: -16px;
}

.editor-container {
  flex: 1 1 0;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.editor-container :deep(.monaco-editor) {
  flex: 1 1 0;
  height: 100% !important;
}

.footer {
  flex-shrink: 0;
  padding: 12px;
  background: #fff;
}
</style>

<route lang="json5">
{
  name: 'config',
  meta: {
    title: '设备配置',
  }
}
</route>
