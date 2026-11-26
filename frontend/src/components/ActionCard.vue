<script setup lang="ts">
import { Bug, LoaderCircle, LogIn, Search, ShoppingCart } from '@lucide/vue'
import type { Component } from 'vue'

import type { Endpoint, EndpointId } from '@/api/endpoints'
import type { EndpointStats } from '@/composables/useActivity'

defineProps<{
  endpoint: Endpoint
  stats: EndpointStats
}>()

defineEmits<{ send: [] }>()

const ICONS: Record<EndpointId, Component> = {
  login: LogIn,
  checkout: ShoppingCart,
  search: Search,
  error: Bug,
}
</script>

<template>
  <article class="action card" :class="{ danger: endpoint.id === 'error' }">
    <div class="top">
      <span class="icon" aria-hidden="true"><component :is="ICONS[endpoint.id]" :size="18" /></span>
      <code class="mono route">{{ endpoint.method }} {{ endpoint.path }}</code>
    </div>

    <div>
      <h3>{{ endpoint.label }}</h3>
      <p>{{ endpoint.description }}</p>
    </div>

    <div class="bottom">
      <span class="counts">
        <span>{{ stats.sent }} sent</span>
        <span v-if="stats.failed" class="failed">{{ stats.failed }} failed</span>
      </span>
      <button type="button" class="btn" @click="$emit('send')">
        <LoaderCircle v-if="stats.inFlight" :size="14" class="spin" aria-hidden="true" />
        Send
        <span class="visually-hidden">{{ endpoint.label }} request</span>
      </button>
    </div>
  </article>
</template>

<style scoped>
.action {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
  transition: border-color 120ms;
}

.action:hover {
  border-color: color-mix(in srgb, var(--accent) 45%, var(--border));
}

.top {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.icon {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border-radius: var(--radius-sm);
  background: var(--accent-soft);
  color: var(--accent);
}

.danger .icon {
  background: var(--danger-soft);
  color: var(--danger);
}

.route {
  color: var(--text-subtle);
}

h3 {
  font-size: 15px;
  font-weight: 600;
}

p {
  color: var(--text-muted);
}

.bottom {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: auto;
}

.counts {
  display: flex;
  gap: 8px;
  color: var(--text-subtle);
  font-size: 12px;
  font-variant-numeric: tabular-nums;
}

.failed {
  color: var(--danger);
}
</style>
