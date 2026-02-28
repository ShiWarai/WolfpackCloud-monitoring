<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useRobotsStore } from '@/stores'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import type { RobotStatus } from '@/types'

const route = useRoute()
const router = useRouter()
const robotsStore = useRobotsStore()

const editing = ref(false)
const editName = ref('')
const editDescription = ref('')
const showDeleteConfirm = ref(false)

const robot = computed(() => robotsStore.currentRobot)
const robotId = computed(() => Number(route.params.id))

const statusConfig: Record<RobotStatus, { label: string; color: string; bg: string }> = {
  active: { label: 'Активен', color: 'text-green-700', bg: 'bg-green-100' },
  pending: { label: 'Ожидание', color: 'text-yellow-700', bg: 'bg-yellow-100' },
  inactive: { label: 'Неактивен', color: 'text-gray-700', bg: 'bg-gray-100' },
  error: { label: 'Ошибка', color: 'text-red-700', bg: 'bg-red-100' },
}

function startEditing() {
  if (robot.value) {
    editName.value = robot.value.name
    editDescription.value = robot.value.description || ''
    editing.value = true
  }
}

async function saveChanges() {
  try {
    await robotsStore.updateRobot(robotId.value, {
      name: editName.value,
      description: editDescription.value || undefined,
    })
    editing.value = false
  } catch {
    // error handled in store
  }
}

function cancelEditing() {
  editing.value = false
}

async function deleteRobot() {
  try {
    await robotsStore.deleteRobot(robotId.value)
    router.push('/robots')
  } catch {
    // error handled in store
  }
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleString('ru-RU')
}

onMounted(() => {
  robotsStore.fetchRobot(robotId.value)
})
</script>

<template>
  <DefaultLayout>
    <div class="space-y-6">
      <div class="flex items-center gap-4">
        <button
          @click="router.back()"
          class="p-2 hover:bg-gray-100 rounded-lg transition-colors"
        >
          <svg class="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 class="text-2xl font-bold text-gray-900">
          {{ robot?.name || 'Загрузка...' }}
        </h1>
      </div>

      <div v-if="robotsStore.loading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-primary-500 border-t-transparent"></div>
      </div>

      <div v-else-if="robotsStore.error" class="card bg-red-50 border-red-200">
        <p class="text-red-700">{{ robotsStore.error }}</p>
      </div>

      <template v-else-if="robot">
        <div class="card">
          <div class="flex items-start justify-between mb-6">
            <div>
              <span
                :class="[statusConfig[robot.status].color, statusConfig[robot.status].bg]"
                class="px-3 py-1 rounded-full text-sm font-medium"
              >
                {{ statusConfig[robot.status].label }}
              </span>
            </div>
            <div class="flex gap-2">
              <button
                v-if="!editing"
                @click="startEditing"
                class="btn-secondary text-sm"
              >
                Редактировать
              </button>
              <button
                @click="showDeleteConfirm = true"
                class="btn-danger text-sm"
              >
                Удалить
              </button>
            </div>
          </div>

          <form v-if="editing" @submit.prevent="saveChanges" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Имя</label>
              <input v-model="editName" type="text" required class="input" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Описание</label>
              <textarea v-model="editDescription" rows="3" class="input"></textarea>
            </div>
            <div class="flex gap-3">
              <button type="button" @click="cancelEditing" class="btn-secondary">
                Отмена
              </button>
              <button type="submit" class="btn-primary">
                Сохранить
              </button>
            </div>
          </form>

          <dl v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <dt class="text-sm text-gray-500">Имя</dt>
              <dd class="mt-1 text-gray-900 font-medium">{{ robot.name }}</dd>
            </div>
            <div>
              <dt class="text-sm text-gray-500">Hostname</dt>
              <dd class="mt-1 text-gray-900 font-medium font-mono">{{ robot.hostname }}</dd>
            </div>
            <div>
              <dt class="text-sm text-gray-500">IP-адрес</dt>
              <dd class="mt-1 text-gray-900 font-medium font-mono">{{ robot.ip_address || '—' }}</dd>
            </div>
            <div>
              <dt class="text-sm text-gray-500">Архитектура</dt>
              <dd class="mt-1 text-gray-900 font-medium">{{ robot.architecture }}</dd>
            </div>
            <div class="md:col-span-2">
              <dt class="text-sm text-gray-500">Описание</dt>
              <dd class="mt-1 text-gray-900">{{ robot.description || '—' }}</dd>
            </div>
            <div>
              <dt class="text-sm text-gray-500">Создан</dt>
              <dd class="mt-1 text-gray-900">{{ formatDate(robot.created_at) }}</dd>
            </div>
            <div>
              <dt class="text-sm text-gray-500">Последняя активность</dt>
              <dd class="mt-1 text-gray-900">{{ formatDate(robot.last_seen_at) }}</dd>
            </div>
          </dl>
        </div>

        <div v-if="robot.influxdb_token" class="card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Токен InfluxDB</h3>
          <div class="bg-gray-100 rounded-lg p-4 font-mono text-sm break-all">
            {{ robot.influxdb_token }}
          </div>
          <p class="mt-2 text-sm text-gray-500">
            Этот токен используется роботом для отправки метрик
          </p>
        </div>
      </template>

      <div
        v-if="showDeleteConfirm"
        class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
        @click.self="showDeleteConfirm = false"
      >
        <div class="bg-white rounded-xl p-6 max-w-md w-full mx-4">
          <h3 class="text-lg font-medium text-gray-900 mb-2">Удалить робота?</h3>
          <p class="text-gray-500 mb-6">
            Это действие нельзя отменить. Все данные робота будут удалены.
          </p>
          <div class="flex gap-3">
            <button
              @click="showDeleteConfirm = false"
              class="btn-secondary flex-1"
            >
              Отмена
            </button>
            <button
              @click="deleteRobot"
              class="btn-danger flex-1"
            >
              Удалить
            </button>
          </div>
        </div>
      </div>
    </div>
  </DefaultLayout>
</template>
