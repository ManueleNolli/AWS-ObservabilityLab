<script setup lang="ts">
import { computed } from 'vue'

import { MAX_RECORDS, type SessionStats } from '@/composables/useActivity'
import { formatLatency, formatPercent } from '@/lib/stats'

import StatTile from './StatTile.vue'

const props = defineProps<{ stats: SessionStats }>()

const errors = computed(() => {
  const { outcomes } = props.stats
  return outcomes['client-error'] + outcomes['server-error'] + outcomes['network-error']
})

const errorHint = computed(() => {
  const { outcomes } = props.stats
  const parts = [`${outcomes['client-error']} × 4xx`, `${outcomes['server-error']} × 5xx`]
  if (outcomes['network-error'] > 0) parts.push(`${outcomes['network-error']} network`)
  return parts.join(' · ')
})

const successTone = computed(() => {
  const rate = props.stats.successRate
  if (rate === null) return undefined
  if (rate >= 0.95) return 'success'
  return rate >= 0.8 ? 'warning' : 'danger'
})
</script>

<template>
  <div class="stats">
    <StatTile label="Requests" :value="String(stats.sent)" hint="this session" />
    <StatTile
      label="Success rate"
      :value="formatPercent(stats.successRate)"
      :tone="successTone"
      hint="2xx responses"
    />
    <StatTile
      label="Errors"
      :value="String(errors)"
      :tone="errors > 0 ? 'danger' : undefined"
      :hint="errorHint"
    />
    <StatTile
      label="p95 latency"
      :value="formatLatency(stats.p95LatencyMs)"
      :hint="`last ${MAX_RECORDS} requests`"
    />
  </div>
</template>

<style scoped>
.stats {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}
</style>
