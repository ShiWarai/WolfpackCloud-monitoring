<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useRobotsStore } from '@/stores'
import RobotCard from '@/components/RobotCard.vue'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import type { RobotStatus } from '@/types'

const router = useRouter()
const robotsStore = useRobotsStore()

const search = ref('')
const statusFilter = ref<RobotStatus | ''>('')
const searchTimeout = ref<number>()

const statusOptions: { value: RobotStatus | ''; label: string }[] = [
  { value: '', label: 'Все статусы' },
  { value: 'active', label: 'Активные' },
  { value: 'pending', label: 'Ожидающие' },
  { value: 'inactive', label: 'Неактивные' },
  { value: 'error', label: 'С ошибками' },
]

function fetchRobots() {
  robotsStore.fetchRobots({
    search: search.value || undefined,
    status: statusFilter.value || undefined,
  })
}

watch(search, () => {
  clearTimeout(searchTimeout.value)
  searchTimeout.value = window.setTimeout(fetchRobots, 300)
})

watch(statusFilter, fetchRobots)

function goToRobot(id: number) {
  router.push(`/robots/${id}`)
}

onMounted(fetchRobots)
</script>

<template>
  <DefaultLayout>
    <div class="space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Роботы</h1>
          <p class="text-gray-500 mt-1">
            Всего: {{ robotsStore.total }}
          </p>
        </div>
        
        <RouterLink to="/pairing" class="btn-primary">
          <svg class="w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Привязать робота
        </RouterLink>
      </div>

      <div class="card">
        <div class="flex flex-col sm:flex-row gap-4">
          <div class="flex-1">
            <input
              v-model="search"
              type="text"
              placeholder="Поиск по имени или hostname..."
              class="input"
            />
          </div>
          <select
            v-model="statusFilter"
            class="input sm:w-48"
          >
            <option
              v-for="option in statusOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </div>
      </div>

      <div v-if="robotsStore.loading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-primary-500 border-t-transparent"></div>
        <p class="mt-2 text-gray-500">Загрузка...</p>
      </div>

      <div v-else-if="robotsStore.error" class="card bg-red-50 border-red-200">
        <p class="text-red-700">{{ robotsStore.error }}</p>
      </div>

      <div v-else-if="robotsStore.robots.length === 0" class="card text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z" />
        </svg>
        <p class="mt-4 text-gray-500">Роботы не найдены</p>
        <RouterLink to="/pairing" class="btn-primary mt-4 inline-block">
          Привязать первого робота
        </RouterLink>
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <RobotCard
          v-for="robot in robotsStore.robots"
          :key="robot.id"
          :robot="robot"
          @click="goToRobot(robot.id)"
        />
      </div>
    </div>
  </DefaultLayout>
</template>
