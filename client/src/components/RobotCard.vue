<script setup lang="ts">
import { computed } from 'vue'
import type { Robot, RobotStatus } from '@/types'

const props = defineProps<{
  robot: Robot
}>()

defineEmits<{
  click: []
}>()

const statusConfig: Record<RobotStatus, { label: string; color: string; bg: string }> = {
  active: { label: 'Активен', color: 'text-green-700', bg: 'bg-green-100' },
  pending: { label: 'Ожидание', color: 'text-yellow-700', bg: 'bg-yellow-100' },
  inactive: { label: 'Неактивен', color: 'text-gray-700', bg: 'bg-gray-100' },
  error: { label: 'Ошибка', color: 'text-red-700', bg: 'bg-red-100' },
}

const statusInfo = computed(() => statusConfig[props.robot.status])

const lastSeenFormatted = computed(() => {
  if (!props.robot.last_seen_at) return 'Никогда'
  const date = new Date(props.robot.last_seen_at)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const minutes = Math.floor(diff / 60000)
  
  if (minutes < 1) return 'Только что'
  if (minutes < 60) return `${minutes} мин. назад`
  
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours} ч. назад`
  
  const days = Math.floor(hours / 24)
  return `${days} дн. назад`
})
</script>

<template>
  <div
    class="card hover:shadow-md transition-shadow cursor-pointer"
    @click="$emit('click')"
  >
    <div class="flex items-start justify-between">
      <div class="flex-1 min-w-0">
        <h3 class="text-lg font-medium text-gray-900 truncate">
          {{ robot.name }}
        </h3>
        <p class="text-sm text-gray-500 truncate">
          {{ robot.hostname }}
        </p>
      </div>
      <span
        :class="[statusInfo.color, statusInfo.bg]"
        class="ml-2 px-2.5 py-0.5 rounded-full text-xs font-medium"
      >
        {{ statusInfo.label }}
      </span>
    </div>

    <div class="mt-4 grid grid-cols-2 gap-4 text-sm">
      <div>
        <p class="text-gray-500">IP-адрес</p>
        <p class="font-medium text-gray-900">{{ robot.ip_address || '—' }}</p>
      </div>
      <div>
        <p class="text-gray-500">Архитектура</p>
        <p class="font-medium text-gray-900">{{ robot.architecture }}</p>
      </div>
      <div class="col-span-2">
        <p class="text-gray-500">Последняя активность</p>
        <p class="font-medium text-gray-900">{{ lastSeenFormatted }}</p>
      </div>
    </div>
  </div>
</template>
