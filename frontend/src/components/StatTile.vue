<script setup lang="ts">
defineProps<{
  label: string
  value: string
  hint?: string
  tone?: 'success' | 'warning' | 'danger'
}>()
</script>

<template>
  <div class="tile card">
    <span class="label">{{ label }}</span>
    <span class="value" :class="tone">{{ value }}</span>
    <span v-if="hint" class="hint">{{ hint }}</span>
  </div>
</template>

<style scoped>
.tile {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 14px 16px;
}

.label {
  color: var(--text-muted);
  font-size: 13px;
  font-weight: 500;
}

.value {
  font-size: 24px;
  font-weight: 650;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.02em;
}

.success {
  color: var(--success);
}

.warning {
  color: var(--warning);
}

.danger {
  color: var(--danger);
}

.hint {
  color: var(--text-subtle);
  font-size: 12px;
}
</style>
