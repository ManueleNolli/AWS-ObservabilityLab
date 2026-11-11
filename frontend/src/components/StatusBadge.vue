<script setup lang="ts">
import { computed } from 'vue'

import { outcomeOf } from '@/lib/stats'

const props = defineProps<{ status: number }>()

const outcome = computed(() => outcomeOf(props.status))
</script>

<template>
  <span class="badge" :class="outcome" :title="status === 0 ? 'No response' : undefined">
    {{ status === 0 ? 'ERR' : status }}
  </span>
</template>

<style scoped>
.badge {
  display: inline-block;
  min-width: 44px;
  padding: 2px 8px;
  border-radius: 999px;
  font-family: var(--font-mono);
  font-size: 12px;
  font-weight: 600;
  text-align: center;
}

.success {
  background: var(--success-soft);
  color: var(--success);
}

.client-error {
  background: var(--warning-soft);
  color: var(--warning);
}

.server-error {
  background: var(--danger-soft);
  color: var(--danger);
}

.network-error {
  background: var(--neutral-soft);
  color: var(--neutral);
}
</style>
