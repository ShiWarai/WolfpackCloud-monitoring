<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useAuthStore, useRobotsStore } from '@/stores'
import ExternalLinks from '@/components/ExternalLinks.vue'
import DefaultLayout from '@/layouts/DefaultLayout.vue'

const authStore = useAuthStore()
const robotsStore = useRobotsStore()

const user = computed(() => authStore.user)
const stats = computed(() => robotsStore.robotsByStatus)
const totalRobots = computed(() => robotsStore.total)

onMounted(() => {
  robotsStore.fetchRobots()
})
</script>

<template>
  <DefaultLayout>
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">
          Добро пожаловать, {{ user?.name }}!
        </h1>
        <p class="text-gray-500 mt-1">
          Обзор системы мониторинга роботов
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 w-12 h-12 bg-primary-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-500">Всего роботов</p>
              <p class="text-2xl font-bold text-gray-900">{{ totalRobots }}</p>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-500">Активных</p>
              <p class="text-2xl font-bold text-green-600">{{ stats.active }}</p>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-yellow-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-500">Ожидают</p>
              <p class="text-2xl font-bold text-yellow-600">{{ stats.pending }}</p>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-500">С ошибками</p>
              <p class="text-2xl font-bold text-red-600">{{ stats.error }}</p>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ExternalLinks />

        <div class="card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Быстрые действия</h3>
          <div class="space-y-3">
            <RouterLink
              to="/pairing"
              class="flex items-center p-3 bg-primary-50 rounded-lg hover:bg-primary-100 transition-colors group"
            >
              <div class="flex-shrink-0 w-10 h-10 bg-primary-500 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-900 group-hover:text-primary-700">
                  Привязать робота
                </p>
                <p class="text-xs text-gray-500">Введите код привязки</p>
              </div>
            </RouterLink>

            <RouterLink
              to="/robots"
              class="flex items-center p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors group"
            >
              <div class="flex-shrink-0 w-10 h-10 bg-gray-500 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-900 group-hover:text-gray-700">
                  Все роботы
                </p>
                <p class="text-xs text-gray-500">Управление роботами</p>
              </div>
            </RouterLink>
          </div>
        </div>
      </div>
    </div>
  </DefaultLayout>
</template>
