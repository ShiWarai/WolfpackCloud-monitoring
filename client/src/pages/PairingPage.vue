<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { pairingApi } from '@/api'
import { useRobotsStore } from '@/stores'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import type { PairCodeInfo } from '@/types'

const router = useRouter()
const robotsStore = useRobotsStore()

const code = ref('')
const robotName = ref('')
const codeInfo = ref<PairCodeInfo | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)
const success = ref(false)

const codeInputs = ref<string[]>(['', '', '', '', '', '', '', ''])

function handleCodeInput(index: number, event: Event) {
  const input = event.target as HTMLInputElement
  const value = input.value.toUpperCase().replace(/[^A-Z0-9]/g, '')
  
  codeInputs.value[index] = value.slice(0, 1)
  
  if (value && index < 7) {
    const nextInput = document.getElementById(`code-${index + 1}`)
    nextInput?.focus()
  }
  
  code.value = codeInputs.value.join('')
  
  if (code.value.length === 8) {
    fetchCodeInfo()
  }
}

function handleKeyDown(index: number, event: KeyboardEvent) {
  if (event.key === 'Backspace' && !codeInputs.value[index] && index > 0) {
    const prevInput = document.getElementById(`code-${index - 1}`)
    prevInput?.focus()
  }
}

function handlePaste(event: ClipboardEvent) {
  event.preventDefault()
  const pastedText = event.clipboardData?.getData('text').toUpperCase().replace(/[^A-Z0-9]/g, '') || ''
  
  for (let i = 0; i < 8; i++) {
    codeInputs.value[i] = pastedText[i] || ''
  }
  
  code.value = codeInputs.value.join('')
  
  if (code.value.length === 8) {
    fetchCodeInfo()
  }
}

async function fetchCodeInfo() {
  if (code.value.length !== 8) return
  
  loading.value = true
  error.value = null
  codeInfo.value = null
  
  try {
    codeInfo.value = await pairingApi.getCodeInfo(code.value)
    
    if (codeInfo.value.robot) {
      robotName.value = codeInfo.value.robot.name
    }
  } catch (e: unknown) {
    const err = e as { response?: { data?: { detail?: string } } }
    error.value = err.response?.data?.detail || 'Код не найден'
  } finally {
    loading.value = false
  }
}

async function confirmPairing() {
  loading.value = true
  error.value = null
  
  try {
    await pairingApi.confirm(code.value, robotName.value || undefined)
    success.value = true
    
    await robotsStore.fetchRobots()
    
    setTimeout(() => {
      router.push('/robots')
    }, 2000)
  } catch (e: unknown) {
    const err = e as { response?: { data?: { detail?: string } } }
    error.value = err.response?.data?.detail || 'Ошибка подтверждения'
  } finally {
    loading.value = false
  }
}

function reset() {
  code.value = ''
  codeInputs.value = ['', '', '', '', '', '', '', '']
  robotName.value = ''
  codeInfo.value = null
  error.value = null
  success.value = false
  
  const firstInput = document.getElementById('code-0')
  firstInput?.focus()
}
</script>

<template>
  <DefaultLayout>
    <div class="max-w-lg mx-auto space-y-6">
      <div class="text-center">
        <h1 class="text-2xl font-bold text-gray-900">Привязка робота</h1>
        <p class="text-gray-500 mt-1">
          Введите 8-значный код с экрана робота
        </p>
      </div>

      <div v-if="success" class="card bg-green-50 border-green-200 text-center">
        <svg class="mx-auto h-12 w-12 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
        </svg>
        <p class="mt-4 text-lg font-medium text-green-700">Робот успешно привязан!</p>
        <p class="text-green-600">Перенаправление...</p>
      </div>

      <div v-else class="card space-y-6">
        <div v-if="error" class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
          {{ error }}
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-3 text-center">
            Код привязки
          </label>
          <div class="flex justify-center gap-2" @paste="handlePaste">
            <input
              v-for="(_, index) in codeInputs"
              :id="`code-${index}`"
              :key="index"
              v-model="codeInputs[index]"
              type="text"
              maxlength="1"
              class="w-10 h-12 text-center text-xl font-mono font-bold border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent uppercase"
              @input="handleCodeInput(index, $event)"
              @keydown="handleKeyDown(index, $event)"
            />
          </div>
        </div>

        <div v-if="loading" class="text-center py-4">
          <div class="inline-block animate-spin rounded-full h-6 w-6 border-4 border-primary-500 border-t-transparent"></div>
          <p class="mt-2 text-sm text-gray-500">Проверка кода...</p>
        </div>

        <div v-else-if="codeInfo" class="space-y-4">
          <div class="bg-gray-50 rounded-lg p-4">
            <h3 class="text-sm font-medium text-gray-700 mb-2">Информация о роботе</h3>
            <dl class="space-y-1 text-sm">
              <div class="flex justify-between">
                <dt class="text-gray-500">Hostname:</dt>
                <dd class="font-medium text-gray-900">{{ codeInfo.robot?.hostname }}</dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-gray-500">IP-адрес:</dt>
                <dd class="font-medium text-gray-900">{{ codeInfo.robot?.ip_address || '—' }}</dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-gray-500">Архитектура:</dt>
                <dd class="font-medium text-gray-900">{{ codeInfo.robot?.architecture }}</dd>
              </div>
            </dl>
          </div>

          <div v-if="codeInfo.status === 'pending'">
            <label for="robotName" class="block text-sm font-medium text-gray-700 mb-1">
              Имя робота (опционально)
            </label>
            <input
              id="robotName"
              v-model="robotName"
              type="text"
              class="input"
              placeholder="Введите понятное имя для робота"
            />
          </div>

          <div v-if="codeInfo.status === 'pending'" class="flex gap-3">
            <button
              type="button"
              @click="reset"
              class="btn-secondary flex-1"
            >
              Отмена
            </button>
            <button
              type="button"
              @click="confirmPairing"
              :disabled="loading"
              class="btn-primary flex-1"
            >
              Подтвердить привязку
            </button>
          </div>

          <div v-else-if="codeInfo.status === 'confirmed'" class="bg-yellow-50 border border-yellow-200 text-yellow-700 px-4 py-3 rounded-lg text-center">
            Этот код уже был использован
          </div>

          <div v-else-if="codeInfo.status === 'expired'" class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-center">
            Срок действия кода истёк
          </div>
        </div>
      </div>

      <div class="card bg-blue-50 border-blue-200">
        <h3 class="text-sm font-medium text-blue-800 mb-2">Как получить код?</h3>
        <ol class="text-sm text-blue-700 space-y-1 list-decimal list-inside">
          <li>Установите агент на робота</li>
          <li>Запустите команду установки</li>
          <li>Код появится в терминале</li>
          <li>Введите код здесь в течение 15 минут</li>
        </ol>
      </div>
    </div>
  </DefaultLayout>
</template>
