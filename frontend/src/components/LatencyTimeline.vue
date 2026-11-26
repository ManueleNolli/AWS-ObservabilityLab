<script setup lang="ts">
import { computed } from 'vue'

import type { RequestRecord } from '@/api/client'
import { formatLatency, outcomeOf } from '@/lib/stats'

const props = withDefaults(defineProps<{ records: readonly RequestRecord[]; size?: number }>(), {
  size: 60,
})

const LEGEND = [
  { outcome: 'success', label: '2xx' },
  { outcome: 'client-error', label: '4xx' },
  { outcome: 'server-error', label: '5xx' },
] as const

/** Lower bound for the scale, so a handful of fast requests don't fill the chart. */
const MIN_SCALE_MS = 500

// Oldest on the left, newest on the right.
const bars = computed(() => props.records.slice(0, props.size).reverse())

const scaleMs = computed(() =>
  Math.max(MIN_SCALE_MS, ...bars.value.map((record) => record.latencyMs)),
)

function heightOf(record: RequestRecord): string {
  // Square-root scale keeps fast requests visible next to slow checkouts.
  return `${Math.max(4, Math.sqrt(record.latencyMs / scaleMs.value) * 100)}%`
}

function describe(record: RequestRecord): string {
  const status = record.status === 0 ? 'no response' : record.status
  return `${record.method} ${record.url} · ${status} · ${formatLatency(record.latencyMs)}`
}
</script>

<template>
  <section class="timeline card" aria-labelledby="timeline-title">
    <header>
      <h3 id="timeline-title">Latency of the last {{ size }} requests</h3>
      <span class="scale">max {{ formatLatency(scaleMs) }}</span>
    </header>

    <div v-if="bars.length" class="bars" role="img" :aria-label="`${bars.length} requests`">
      <span
        v-for="record in bars"
        :key="record.id"
        class="bar"
        :class="outcomeOf(record.status)"
        :style="{ height: heightOf(record) }"
        :title="describe(record)"
      />
    </div>
    <p v-else class="empty">Send some requests to see them here.</p>

    <ul class="legend">
      <li v-for="item in LEGEND" :key="item.label">
        <span class="swatch" :class="item.outcome" aria-hidden="true" />{{ item.label }}
      </li>
    </ul>
  </section>
</template>

<style scoped>
.timeline {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
}

header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
}

h3 {
  font-size: 13px;
  font-weight: 600;
}

.scale {
  color: var(--text-subtle);
  font-size: 12px;
  font-variant-numeric: tabular-nums;
}

.bars,
.empty {
  height: 120px;
}

.bars {
  display: flex;
  gap: 3px;
  align-items: flex-end;
  padding-bottom: 1px;
  border-bottom: 1px solid var(--border);
}

.bar {
  flex: 1 1 0;
  max-width: 14px;
  min-width: 2px;
  border-radius: 3px 3px 0 0;
  transition: height 200ms ease-out;
}

.empty {
  display: grid;
  place-items: center;
  border: 1px dashed var(--border);
  border-radius: var(--radius-sm);
  color: var(--text-subtle);
}

.legend {
  display: flex;
  gap: 16px;
  margin: 0;
  padding: 0;
  list-style: none;
  color: var(--text-muted);
  font-size: 12px;
}

.legend li {
  display: flex;
  gap: 6px;
  align-items: center;
}

.swatch {
  width: 8px;
  height: 8px;
  border-radius: 2px;
}

.success {
  background: var(--success);
}

.client-error {
  background: var(--warning);
}

.server-error {
  background: var(--danger);
}

.network-error {
  background: var(--neutral);
}
</style>
