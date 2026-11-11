<script setup lang="ts">
import { Check, Copy, Inbox, Trash2 } from '@lucide/vue'
import { computed, ref } from 'vue'

import type { RequestRecord } from '@/api/client'
import { formatLatency, isFailure } from '@/lib/stats'

import StatusBadge from './StatusBadge.vue'

const props = defineProps<{ records: readonly RequestRecord[] }>()

defineEmits<{ clear: [] }>()

type Filter = 'all' | 'success' | 'failed'

const FILTERS: { value: Filter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'success', label: 'Success' },
  { value: 'failed', label: 'Failed' },
]

const filter = ref<Filter>('all')
const copiedId = ref<string | null>(null)

const visible = computed(() =>
  filter.value === 'all'
    ? props.records
    : props.records.filter((r) => isFailure(r.status) === (filter.value === 'failed')),
)

const timeFormat = new Intl.DateTimeFormat(undefined, {
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
})

async function copyRequestId(requestId: string): Promise<void> {
  await navigator.clipboard.writeText(requestId)
  copiedId.value = requestId
  setTimeout(() => {
    if (copiedId.value === requestId) copiedId.value = null
  }, 1500)
}
</script>

<template>
  <section class="log card" aria-labelledby="activity-title">
    <header>
      <div>
        <h2 id="activity-title">Activity</h2>
        <p>Copy a request ID and search for it in the Grafana logs dashboard.</p>
      </div>
      <div class="controls">
        <div class="segmented" role="group" aria-label="Filter requests">
          <button
            v-for="option in FILTERS"
            :key="option.value"
            type="button"
            :aria-pressed="filter === option.value"
            @click="filter = option.value"
          >
            {{ option.label }}
          </button>
        </div>
        <button
          type="button"
          class="btn btn-ghost"
          :disabled="records.length === 0"
          @click="$emit('clear')"
        >
          <Trash2 :size="14" aria-hidden="true" />
          Clear
        </button>
      </div>
    </header>

    <div v-if="visible.length" class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Status</th>
            <th>Request</th>
            <th class="num">Latency</th>
            <th>Time</th>
            <th>Request ID</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="record in visible" :key="record.id">
            <td><StatusBadge :status="record.status" /></td>
            <td class="mono request">
              <span class="method">{{ record.method }}</span> {{ record.url }}
            </td>
            <td class="num">{{ formatLatency(record.latencyMs) }}</td>
            <td class="muted">{{ timeFormat.format(record.timestamp) }}</td>
            <td>
              <button
                v-if="record.requestId"
                type="button"
                class="request-id mono"
                :title="`Copy ${record.requestId}`"
                @click="copyRequestId(record.requestId)"
              >
                {{ record.requestId.slice(0, 8) }}
                <Check v-if="copiedId === record.requestId" :size="13" aria-label="Copied" />
                <Copy v-else :size="13" aria-hidden="true" />
              </button>
              <span v-else class="muted">–</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="empty">
      <Inbox :size="22" aria-hidden="true" />
      <p v-if="records.length">
        No {{ filter === 'failed' ? 'failed' : 'successful' }} requests yet.
      </p>
      <p v-else>No requests yet. Pick an action above to get started.</p>
    </div>
  </section>
</template>

<style scoped>
.log {
  overflow: hidden;
}

header {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  border-bottom: 1px solid var(--border);
}

h2 {
  font-size: 15px;
  font-weight: 600;
}

header p {
  color: var(--text-muted);
  font-size: 13px;
}

.controls {
  display: flex;
  gap: 8px;
  align-items: center;
}

.segmented {
  display: inline-flex;
  padding: 3px;
  border-radius: var(--radius-sm);
  background: var(--surface-muted);
}

.segmented button {
  height: 28px;
  padding: 0 12px;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: var(--text-muted);
  font-weight: 500;
  cursor: pointer;
}

.segmented button[aria-pressed='true'] {
  background: var(--surface);
  box-shadow: var(--shadow);
  color: var(--text);
}

.table-wrap {
  max-height: 420px;
  overflow: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-variant-numeric: tabular-nums;
}

th {
  position: sticky;
  top: 0;
  padding: 8px 16px;
  background: var(--surface-muted);
  color: var(--text-muted);
  font-size: 12px;
  font-weight: 500;
  text-align: left;
  white-space: nowrap;
}

td {
  padding: 8px 16px;
  border-top: 1px solid var(--border);
  white-space: nowrap;
}

tbody tr:first-child td {
  border-top: none;
}

tbody tr:hover {
  background: var(--surface-muted);
}

.num {
  text-align: right;
}

.request {
  width: 100%;
}

.method {
  color: var(--text-subtle);
}

.muted {
  color: var(--text-subtle);
}

.request-id {
  display: inline-flex;
  gap: 6px;
  align-items: center;
  padding: 2px 6px;
  border: 1px solid transparent;
  border-radius: 6px;
  background: none;
  color: var(--text-muted);
  cursor: pointer;
}

.request-id:hover {
  border-color: var(--border);
  background: var(--surface);
  color: var(--text);
}

.empty {
  display: flex;
  flex-direction: column;
  gap: 8px;
  align-items: center;
  padding: 40px 16px;
  color: var(--text-subtle);
}
</style>
