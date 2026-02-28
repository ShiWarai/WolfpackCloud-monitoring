<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores'

const router = useRouter()
const authStore = useAuthStore()

const user = computed(() => authStore.user)
const isAdmin = computed(() => authStore.isAdmin)

function handleLogout() {
  authStore.logout()
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen flex flex-col">
    <header class="bg-white border-b border-gray-200 sticky top-0 z-10">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <div class="flex items-center space-x-8">
            <RouterLink to="/" class="flex items-center space-x-2">
              <span class="text-xl font-bold text-primary-600">WolfpackCloud</span>
              <span class="text-gray-500">Monitoring</span>
            </RouterLink>
            
            <nav class="hidden md:flex space-x-4">
              <RouterLink 
                to="/dashboard" 
                class="px-3 py-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-colors"
                active-class="bg-primary-50 text-primary-700"
              >
                Dashboard
              </RouterLink>
              <RouterLink 
                to="/robots" 
                class="px-3 py-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-colors"
                active-class="bg-primary-50 text-primary-700"
              >
                Роботы
              </RouterLink>
              <RouterLink 
                to="/pairing" 
                class="px-3 py-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-colors"
                active-class="bg-primary-50 text-primary-700"
              >
                Привязка
              </RouterLink>
            </nav>
          </div>

          <div class="flex items-center space-x-4">
            <div v-if="user" class="flex items-center space-x-3">
              <div class="text-right">
                <p class="text-sm font-medium text-gray-900">{{ user.name }}</p>
                <p class="text-xs text-gray-500">
                  {{ isAdmin ? 'Администратор' : 'Пользователь' }}
                </p>
              </div>
              <button
                @click="handleLogout"
                class="px-3 py-2 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
              >
                Выйти
              </button>
            </div>
          </div>
        </div>
      </div>
    </header>

    <main class="flex-1 bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <slot />
      </div>
    </main>

    <footer class="bg-white border-t border-gray-200 py-4">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <p class="text-center text-sm text-gray-500">
          WolfpackCloud Monitoring &copy; {{ new Date().getFullYear() }}
        </p>
      </div>
    </footer>
  </div>
</template>
