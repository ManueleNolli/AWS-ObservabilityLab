<script setup lang="ts">
import { ENDPOINTS } from '@/api/endpoints'
import ActionCard from '@/components/ActionCard.vue'
import ActivityLog from '@/components/ActivityLog.vue'
import AppHeader from '@/components/AppHeader.vue'
import BurstCard from '@/components/BurstCard.vue'
import LatencyTimeline from '@/components/LatencyTimeline.vue'
import SessionStats from '@/components/SessionStats.vue'
import { useActivity } from '@/composables/useActivity'
import { useApiHealth } from '@/composables/useApiHealth'

const grafanaUrl = import.meta.env.VITE_GRAFANA_URL || undefined

const health = useApiHealth()
const { records, stats, byEndpoint, burst, run, fireBurst, clear } = useActivity()
</script>

<template>
  <div class="page">
    <AppHeader :health="health" :grafana-url="grafanaUrl" />

    <div class="columns">
      <section aria-labelledby="traffic-title">
        <h2 id="traffic-title" class="section-title">Send traffic</h2>
        <div class="actions">
          <ActionCard
            v-for="endpoint in ENDPOINTS"
            :key="endpoint.id"
            :endpoint="endpoint"
            :stats="byEndpoint[endpoint.id]"
            @send="run(endpoint)"
          />
        </div>
        <BurstCard :burst="burst" @fire="fireBurst" />
      </section>

      <section aria-labelledby="session-title">
        <h2 id="session-title" class="section-title">This session</h2>
        <SessionStats :stats="stats" />
        <LatencyTimeline :records="records" />
      </section>
    </div>

    <ActivityLog :records="records" @clear="clear" />
  </div>
</template>

<style scoped>
.page {
  display: flex;
  flex-direction: column;
  gap: 28px;
  max-width: 1180px;
  margin: 0 auto;
  padding: 28px 16px 48px;
}

.columns {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 28px;
}

@media (width >= 960px) {
  .columns {
    grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr);
  }
}

.columns section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.section-title {
  color: var(--text-muted);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.actions {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
}
</style>
