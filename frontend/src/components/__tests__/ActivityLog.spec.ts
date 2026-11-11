import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'

import type { RequestRecord } from '@/api/client'

import ActivityLog from '../ActivityLog.vue'

function record(id: number, status: number): RequestRecord {
  return {
    id,
    endpointId: 'login',
    method: 'POST',
    url: '/api/login',
    status,
    latencyMs: 12,
    requestId: `request-${id}`,
    timestamp: new Date(),
  }
}

const records = [record(1, 200), record(2, 401), record(3, 500)]

describe('ActivityLog', () => {
  it('shows an empty state without records', () => {
    const wrapper = mount(ActivityLog, { props: { records: [] } })

    expect(wrapper.find('table').exists()).toBe(false)
    expect(wrapper.text()).toContain('No requests yet')
  })

  it('filters by outcome', async () => {
    const wrapper = mount(ActivityLog, { props: { records } })
    const rows = () => wrapper.findAll('tbody tr')
    const filterButton = (label: string) =>
      wrapper.findAll('[role="group"] button').find((b) => b.text() === label)!

    expect(rows()).toHaveLength(3)

    await filterButton('Failed').trigger('click')
    expect(rows()).toHaveLength(2)

    await filterButton('Success').trigger('click')
    expect(rows()).toHaveLength(1)
  })

  it('emits clear', async () => {
    const wrapper = mount(ActivityLog, { props: { records } })

    await wrapper.find('.btn-ghost').trigger('click')

    expect(wrapper.emitted('clear')).toHaveLength(1)
  })
})
