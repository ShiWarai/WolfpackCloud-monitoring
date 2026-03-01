<script setup lang="ts">
defineProps<{
  robotId?: number
}>()

const grafanaUrl = import.meta.env.VITE_GRAFANA_URL || 'http://localhost:9200'
const supersetUrl = import.meta.env.VITE_SUPERSET_URL || 'http://localhost:9300'
</script>

<template>
  <div class="term-card">
    <h2>Внешние сервисы</h2>
    <div class="term-external-links">
      <a
        :href="grafanaUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="term-btn"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 1rem; height: 1rem;">
          <path d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        </svg>
        Grafana
      </a>
      <a
        :href="supersetUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="term-btn"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 1rem; height: 1rem;">
          <path d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" />
          <path d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" />
        </svg>
        Superset
      </a>
    </div>
    <p class="term-text-dim term-mt-1 term-fs-2xs">
      Дашборды и BI-аналитика для мониторинга роботов
    </p>
  </div>
</template>
