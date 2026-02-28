<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores'

const router = useRouter()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const showPassword = ref(false)

async function handleSubmit() {
  try {
    await authStore.login({ email: email.value, password: password.value })
    router.push('/dashboard')
  } catch {
    // error is handled in store
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8">
      <div class="text-center">
        <h1 class="text-3xl font-bold text-primary-600">WolfpackCloud</h1>
        <h2 class="mt-2 text-xl text-gray-600">Monitoring</h2>
        <p class="mt-4 text-gray-500">Войдите в систему</p>
      </div>

      <form @submit.prevent="handleSubmit" class="card space-y-6">
        <div v-if="authStore.error" class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
          {{ authStore.error }}
        </div>

        <div>
          <label for="email" class="block text-sm font-medium text-gray-700 mb-1">
            Email
          </label>
          <input
            id="email"
            v-model="email"
            type="email"
            required
            autocomplete="email"
            class="input"
            placeholder="example@email.com"
          />
        </div>

        <div>
          <label for="password" class="block text-sm font-medium text-gray-700 mb-1">
            Пароль
          </label>
          <div class="relative">
            <input
              id="password"
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              required
              autocomplete="current-password"
              class="input pr-10"
              placeholder="••••••••"
            />
            <button
              type="button"
              @click="showPassword = !showPassword"
              class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
            >
              <span class="text-sm">{{ showPassword ? 'Скрыть' : 'Показать' }}</span>
            </button>
          </div>
        </div>

        <button
          type="submit"
          :disabled="authStore.loading"
          class="btn-primary w-full"
        >
          <span v-if="authStore.loading">Вход...</span>
          <span v-else>Войти</span>
        </button>

        <p class="text-center text-sm text-gray-600">
          Нет аккаунта?
          <RouterLink to="/register" class="text-primary-600 hover:text-primary-700 font-medium">
            Зарегистрироваться
          </RouterLink>
        </p>
      </form>
    </div>
  </div>
</template>
