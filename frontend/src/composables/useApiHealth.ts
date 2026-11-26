import { onMounted, onUnmounted, ref } from 'vue'

import { isHealthy } from '@/api/client'
import { HEALTH_PATH } from '@/api/endpoints'

export type ApiHealth = 'checking' | 'online' | 'offline'

export const HEALTH_POLL_INTERVAL_MS = 10_000

/** Poll the health endpoint, which the backend leaves out of its metrics and logs. */
export function useApiHealth(intervalMs = HEALTH_POLL_INTERVAL_MS) {
  const health = ref<ApiHealth>('checking')
  let timer: ReturnType<typeof setInterval> | undefined

  async function check(): Promise<void> {
    health.value = (await isHealthy(HEALTH_PATH)) ? 'online' : 'offline'
  }

  onMounted(() => {
    void check()
    timer = setInterval(check, intervalMs)
  })
  onUnmounted(() => clearInterval(timer))

  return health
}
