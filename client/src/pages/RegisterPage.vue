<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores'

const router = useRouter()
const authStore = useAuthStore()

const name = ref('')
const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const localError = ref<string | null>(null)

async function handleSubmit() {
  localError.value = null
  
  if (password.value !== confirmPassword.value) {
    localError.value = 'Пароли не совпадают'
    return
  }

  if (password.value.length < 8) {
    localError.value = 'Пароль должен содержать минимум 8 символов'
    return
  }

  try {
    await authStore.register({
      name: name.value,
      email: email.value,
      password: password.value,
    })
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
        <p class="mt-4 text-gray-500">Создайте аккаунт</p>
      </div>

      <form @submit.prevent="handleSubmit" class="card space-y-6">
        <div v-if="authStore.error || localError" class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg">
          {{ localError || authStore.error }}
        </div>

        <div>
          <label for="name" class="block text-sm font-medium text-gray-700 mb-1">
            Имя
          </label>
          <input
            id="name"
            v-model="name"
            type="text"
            required
            autocomplete="name"
            class="input"
            placeholder="Ваше имя"
          />
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
              minlength="8"
              autocomplete="new-password"
              class="input pr-10"
              placeholder="Минимум 8 символов"
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

        <div>
          <label for="confirmPassword" class="block text-sm font-medium text-gray-700 mb-1">
            Подтверждение пароля
          </label>
          <input
            id="confirmPassword"
            v-model="confirmPassword"
            :type="showPassword ? 'text' : 'password'"
            required
            autocomplete="new-password"
            class="input"
            placeholder="Повторите пароль"
          />
        </div>

        <button
          type="submit"
          :disabled="authStore.loading"
          class="btn-primary w-full"
        >
          <span v-if="authStore.loading">Регистрация...</span>
          <span v-else>Зарегистрироваться</span>
        </button>

        <p class="text-center text-sm text-gray-600">
          Уже есть аккаунт?
          <RouterLink to="/login" class="text-primary-600 hover:text-primary-700 font-medium">
            Войти
          </RouterLink>
        </p>
      </form>
    </div>
  </div>
</template>
