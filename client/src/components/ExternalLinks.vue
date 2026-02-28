<script setup lang="ts">
const grafanaUrl = import.meta.env.VITE_GRAFANA_URL || 'http://localhost:9200'
const supersetUrl = import.meta.env.VITE_SUPERSET_URL || 'http://localhost:9300'
</script>

<template>
  <div class="card">
    <h3 class="text-lg font-medium text-gray-900 mb-4">Внешние сервисы</h3>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <a
        :href="grafanaUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center p-4 bg-orange-50 rounded-lg hover:bg-orange-100 transition-colors group"
      >
        <div class="flex-shrink-0 w-10 h-10 bg-orange-500 rounded-lg flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
          </svg>
        </div>
        <div class="ml-4">
          <p class="text-sm font-medium text-gray-900 group-hover:text-orange-700">Grafana</p>
          <p class="text-xs text-gray-500">Дашборды и графики</p>
        </div>
        <svg class="w-5 h-5 text-gray-400 ml-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
      </a>

      <a
        :href="supersetUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center p-4 bg-cyan-50 rounded-lg hover:bg-cyan-100 transition-colors group"
      >
        <div class="flex-shrink-0 w-10 h-10 bg-cyan-500 rounded-lg flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" />
          </svg>
        </div>
        <div class="ml-4">
          <p class="text-sm font-medium text-gray-900 group-hover:text-cyan-700">Superset</p>
          <p class="text-xs text-gray-500">BI-аналитика</p>
        </div>
        <svg class="w-5 h-5 text-gray-400 ml-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
      </a>
    </div>
  </div>
</template>
