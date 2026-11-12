<script setup lang="ts">
import { LoaderCircle, Zap } from '@lucide/vue'
import { computed, ref } from 'vue'

import { BURST_SIZES, type BurstProgress } from '@/composables/useActivity'

const props = defineProps<{ burst: BurstProgress }>()

defineEmits<{ fire: [size: number] }>()

const size = ref<number>(BURST_SIZES[0])

const progress = computed(() =>
  props.burst.total === 0 ? 0 : (props.burst.done / props.burst.total) * 100,
)
</script>

<template>
  <article class="burst card">
    <span class="icon" aria-hidden="true"><Zap :size="18" /></span>
    <div class="text">
      <h3>Random burst</h3>
      <p>{{ size }} mixed requests over a few seconds, a quick way to fill the dashboards.</p>
      <div
        v-if="burst.running"
        class="progress"
        role="progressbar"
        :aria-valuenow="burst.done"
        :aria-valuemax="burst.total"
        aria-label="Burst progress"
      >
        <span :style="{ width: `${progress}%` }" />
      </div>
    </div>
    <div class="segmented" role="group" aria-label="Burst size">
      <button
        v-for="option in BURST_SIZES"
        :key="option"
        type="button"
        :aria-pressed="size === option"
        :disabled="burst.running"
        @click="size = option"
      >
        {{ option }}
      </button>
    </div>
    <button
      type="button"
      class="btn btn-primary"
      :disabled="burst.running"
      @click="$emit('fire', size)"
    >
      <LoaderCircle v-if="burst.running" :size="14" class="spin" aria-hidden="true" />
      <template v-if="burst.running">{{ burst.done }} / {{ burst.total }}</template>
      <template v-else>Fire burst</template>
    </button>
  </article>
</template>

<style scoped>
.burst {
  display: flex;
  gap: 14px;
  align-items: center;
  padding: 16px;
  background: linear-gradient(
    120deg,
    var(--accent-soft),
    color-mix(in srgb, var(--accent-soft) 30%, var(--surface)) 70%
  );
}

.icon {
  display: grid;
  flex: none;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--accent);
  color: var(--accent-contrast);
}

.text {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

h3 {
  font-size: 15px;
  font-weight: 600;
}

p {
  color: var(--text-muted);
}

.progress {
  height: 4px;
  margin-top: 8px;
  overflow: hidden;
  border-radius: 999px;
  background: color-mix(in srgb, var(--accent) 18%, transparent);
}

.progress span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--accent);
  transition: width 150ms ease-out;
}

.btn {
  flex: none;
  min-width: 112px;
  font-variant-numeric: tabular-nums;
}

@media (width < 640px) {
  .burst {
    flex-wrap: wrap;
  }

  .text {
    flex-basis: calc(100% - 54px);
  }

  .btn {
    flex: 1;
  }
}
</style>
