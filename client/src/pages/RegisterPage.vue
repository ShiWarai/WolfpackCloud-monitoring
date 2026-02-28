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
  <div class="term-auth-page">
    <div class="term-auth-container">
      <div class="term-auth-header">
        <img src="/icon.svg" alt="" style="height: 3rem; margin-bottom: 1rem;">
        <h1>WolfpackCloud</h1>
        <p>Monitoring · Регистрация</p>
      </div>

      <form @submit.prevent="handleSubmit" class="term-card">
        <div v-if="authStore.error || localError" class="term-alert term-alert-error">
          {{ localError || authStore.error }}
        </div>

        <div class="term-form">
          <div class="term-field">
            <label for="name">Имя</label>
            <input
              id="name"
              v-model="name"
              type="text"
              required
              autocomplete="name"
              class="term-input"
              style="max-width: none;"
              placeholder="Ваше имя"
            />
          </div>

          <div class="term-field">
            <label for="email">Email</label>
            <input
              id="email"
              v-model="email"
              type="email"
              required
              autocomplete="email"
              class="term-input"
              style="max-width: none;"
              placeholder="operator@example.com"
            />
          </div>

          <div class="term-field">
            <label for="password">Пароль</label>
            <div style="position: relative;">
              <input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                required
                minlength="8"
                autocomplete="new-password"
                class="term-input"
                style="max-width: none; padding-right: 5rem;"
                placeholder="Минимум 8 символов"
              />
              <button
                type="button"
                @click="showPassword = !showPassword"
                style="position: absolute; right: 0.5rem; top: 50%; transform: translateY(-50%); background: none; border: none; color: var(--text-dim); cursor: pointer; font-size: var(--fs-2xs);"
              >
                {{ showPassword ? 'Скрыть' : 'Показать' }}
              </button>
            </div>
          </div>

          <div class="term-field">
            <label for="confirmPassword">Подтверждение пароля</label>
            <input
              id="confirmPassword"
              v-model="confirmPassword"
              :type="showPassword ? 'text' : 'password'"
              required
              autocomplete="new-password"
              class="term-input"
              style="max-width: none;"
              placeholder="Повторите пароль"
            />
          </div>

          <button
            type="submit"
            :disabled="authStore.loading"
            class="term-btn term-btn-primary"
            style="width: 100%; margin-top: 0.5rem;"
          >
            <span v-if="authStore.loading">Регистрация...</span>
            <span v-else>Зарегистрироваться</span>
          </button>
        </div>
      </form>

      <p class="term-text-dim" style="text-align: center; margin-top: 1rem;">
        Уже есть аккаунт?
        <RouterLink to="/login" class="term-btn" style="margin-left: 0.5rem;">
          Войти
        </RouterLink>
      </p>
    </div>
    
    <footer class="term-footer" style="position: fixed; bottom: 0; left: 0; right: 0;">
      WolfpackCloud — monitoring
    </footer>
  </div>
</template>
