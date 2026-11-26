<script setup lang="ts">
import { Activity, ExternalLink } from '@lucide/vue'
import { computed } from 'vue'

import type { ApiHealth } from '@/composables/useApiHealth'

const props = defineProps<{
  health: ApiHealth
  grafanaUrl?: string
}>()

const healthLabel = computed(
  () =>
    ({ checking: 'Checking API…', online: 'API online', offline: 'API unreachable' })[props.health],
)
</script>

<template>
  <header class="header">
    <div class="brand">
      <span class="logo" aria-hidden="true"><Activity :size="20" /></span>
      <div>
        <h1>Observability Lab</h1>
        <p>Every click becomes a request, a metric and a log line.</p>
      </div>
    </div>

    <div class="tools">
      <span class="health" :class="health" role="status">
        <span class="dot" aria-hidden="true" />
        {{ healthLabel }}
      </span>
      <a v-if="grafanaUrl" class="btn" :href="grafanaUrl" target="_blank" rel="noopener">
        Open Grafana
        <ExternalLink :size="14" aria-hidden="true" />
      </a>
    </div>
  </header>
</template>

<style scoped>
.header {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  align-items: center;
  justify-content: space-between;
}

.brand {
  display: flex;
  gap: 12px;
  align-items: center;
}

.logo {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--accent);
  color: var(--accent-contrast);
}

h1 {
  font-size: 18px;
  font-weight: 650;
  letter-spacing: -0.01em;
}

.brand p {
  color: var(--text-muted);
}

.tools {
  display: flex;
  gap: 12px;
  align-items: center;
}

.health {
  display: inline-flex;
  gap: 8px;
  align-items: center;
  height: 34px;
  padding: 0 12px;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: var(--surface);
  color: var(--text-muted);
  font-weight: 500;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--neutral);
}

.online .dot {
  background: var(--success);
  box-shadow: 0 0 0 3px var(--success-soft);
}

.offline .dot {
  background: var(--danger);
  box-shadow: 0 0 0 3px var(--danger-soft);
}
</style>
