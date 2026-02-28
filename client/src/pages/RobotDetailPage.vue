<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useRobotsStore } from '@/stores'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import ExternalLinks from '@/components/ExternalLinks.vue'
import type { RobotStatus } from '@/types'

const route = useRoute()
const router = useRouter()
const robotsStore = useRobotsStore()

const activeTab = ref<'info' | 'metrics' | 'logs'>('info')
const editing = ref(false)
const editName = ref('')
const editDescription = ref('')
const showDeleteConfirm = ref(false)

const robot = computed(() => robotsStore.currentRobot)
const robotId = computed(() => Number(route.params.id))

function getStatusDotClass(status: RobotStatus): string {
  switch (status) {
    case 'active': return 'term-status-dot-active'
    case 'pending': return 'term-status-dot-pending'
    case 'error': return 'term-status-dot-error'
    default: return 'term-status-dot-inactive'
  }
}

function getStatusLabel(status: RobotStatus): string {
  switch (status) {
    case 'active': return 'Активен'
    case 'pending': return 'Ожидание'
    case 'error': return 'Ошибка'
    default: return 'Неактивен'
  }
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
    <div class="term-page-title-row">
      <div style="display: flex; align-items: center; gap: 0.75rem;">
        <button @click="router.back()" class="term-btn term-btn-icon" title="Назад">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M15 19l-7-7 7-7"/>
          </svg>
        </button>
        <h1 class="term-page-title">{{ robot?.name || 'Загрузка...' }}</h1>
        <span v-if="robot" class="term-status-cell" style="margin-left: 0.5rem;">
          <span class="term-status-dot" :class="getStatusDotClass(robot.status)"></span>
          <span class="term-text-dim term-fs-2xs">{{ getStatusLabel(robot.status) }}</span>
        </span>
      </div>
      <div v-if="robot && !editing" style="display: flex; gap: 0.5rem;">
        <button @click="startEditing" class="term-btn">Редактировать</button>
        <button @click="showDeleteConfirm = true" class="term-btn term-btn-delete">Удалить</button>
      </div>
    </div>

    <div v-if="robotsStore.loading" class="term-card" style="text-align: center; padding: 2rem;">
      <p class="term-text-dim">Загрузка...</p>
    </div>

    <div v-else-if="robotsStore.error" class="term-alert term-alert-error">
      {{ robotsStore.error }}
    </div>

    <template v-else-if="robot">
      <div class="term-robot-layout">
        <nav class="term-robot-sidebar">
          <a
            href="#"
            @click.prevent="activeTab = 'info'"
            :class="{ 'term-active': activeTab === 'info' }"
          >
            <span class="term-tab-icon">
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5">
                <circle cx="10" cy="10" r="7"/>
                <path d="M10 7v0m0 3v4"/>
              </svg>
            </span>
            Информация
          </a>
          <a
            href="#"
            @click.prevent="activeTab = 'metrics'"
            :class="{ 'term-active': activeTab === 'metrics' }"
          >
            <span class="term-tab-icon">
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M3 17V8l4 3v6M9 17V5l4 5v7M15 17v-6l3 2v4"/>
              </svg>
            </span>
            Метрики
          </a>
          <a
            href="#"
            @click.prevent="activeTab = 'logs'"
            :class="{ 'term-active': activeTab === 'logs' }"
          >
            <span class="term-tab-icon">
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5">
                <path d="M3 5h14M3 10h10M3 15h7"/>
              </svg>
            </span>
            Логи
          </a>
        </nav>
        
        <div class="term-robot-content">
          <div v-show="activeTab === 'info'" class="term-robot-panel term-active">
            <form v-if="editing" @submit.prevent="saveChanges" class="term-form">
              <div class="term-field">
                <label for="editName">Имя</label>
                <input id="editName" v-model="editName" type="text" required class="term-input" style="max-width: none;"/>
              </div>
              <div class="term-field">
                <label for="editDescription">Описание</label>
                <textarea id="editDescription" v-model="editDescription" rows="3" class="term-input" style="max-width: none; resize: vertical;"></textarea>
              </div>
              <div style="display: flex; gap: 0.5rem;">
                <button type="button" @click="cancelEditing" class="term-btn">Отмена</button>
                <button type="submit" class="term-btn term-btn-primary">Сохранить</button>
              </div>
            </form>

            <div v-else>
              <table class="term-table" style="margin-bottom: 1rem;">
                <tbody>
                  <tr>
                    <td style="color: var(--text-dim); width: 35%;">Имя</td>
                    <td>{{ robot.name }}</td>
                  </tr>
                  <tr>
                    <td style="color: var(--text-dim);">Hostname</td>
                    <td>{{ robot.hostname }}</td>
                  </tr>
                  <tr>
                    <td style="color: var(--text-dim);">IP-адрес</td>
                    <td>{{ robot.ip_address || '—' }}</td>
                  </tr>
                  <tr>
                    <td style="color: var(--text-dim);">Архитектура</td>
                    <td>{{ robot.architecture }}</td>
                  </tr>
                  <tr>
                    <td style="color: var(--text-dim);">Описание</td>
                    <td>{{ robot.description || '—' }}</td>
                  </tr>
                  <tr>
                    <td style="color: var(--text-dim);">Создан</td>
                    <td>{{ formatDate(robot.created_at) }}</td>
                  </tr>
                  <tr>
                    <td style="color: var(--text-dim);">Последняя активность</td>
                    <td>{{ formatDate(robot.last_seen_at) }}</td>
                  </tr>
                </tbody>
              </table>

              <div v-if="robot.influxdb_token" class="term-card" style="margin-top: 1rem;">
                <h2>Токен InfluxDB</h2>
                <pre class="term-log" style="min-height: auto;">{{ robot.influxdb_token }}</pre>
                <p class="term-text-dim term-mt-1 term-fs-2xs">
                  Этот токен используется роботом для отправки метрик
                </p>
              </div>
            </div>
          </div>
          
          <div v-show="activeTab === 'metrics'" class="term-robot-panel term-active">
            <ExternalLinks :robot-id="robotId" />
            
            <div class="term-widget term-mt-1">
              <h2>Графики метрик</h2>
              <div class="term-widget-fill">
                Графики будут загружены из Grafana
              </div>
            </div>
          </div>
          
          <div v-show="activeTab === 'logs'" class="term-robot-panel term-active">
            <div class="term-card">
              <h2>Логи робота</h2>
              <pre class="term-log">[info] Agent started...
[info] Connected to monitoring server
[info] Metrics collection enabled
[warn] High CPU usage detected
[info] Heartbeat sent</pre>
            </div>
          </div>
        </div>
      </div>
    </template>

    <div
      v-if="showDeleteConfirm"
      class="term-modal-overlay"
      @click.self="showDeleteConfirm = false"
    >
      <div class="term-modal">
        <h3 style="font-size: 1rem; margin: 0 0 0.5rem;">Удалить робота?</h3>
        <p class="term-text-dim term-mb-1">
          Это действие нельзя отменить. Все данные робота будут удалены.
        </p>
        <div style="display: flex; gap: 0.5rem;">
          <button @click="showDeleteConfirm = false" class="term-btn" style="flex: 1;">
            Отмена
          </button>
          <button @click="deleteRobot" class="term-btn term-btn-delete" style="flex: 1;">
            Удалить
          </button>
        </div>
      </div>
    </div>
  </DefaultLayout>
</template>

<style scoped>
.term-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 200;
}

.term-modal {
  background: var(--bg-card);
  border: 1px solid var(--border);
  padding: 1.5rem;
  max-width: 24rem;
  width: calc(100% - 2rem);
}
</style>
