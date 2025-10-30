import { apiPost } from '../client'

vi.mock('../../offline/queue-manager', () => ({
  enqueueMutation: vi.fn().mockResolvedValue('mutation-123')
}))
vi.mock('../../offline/mutation-serializer', () => ({
  serializeMutation: vi.fn((url: string, method: string, body: unknown) => ({ url, method, body }))
}))

describe('api client offline queuing', () => {
  const originalNavigator = global.navigator

  beforeEach(() => {
    Object.defineProperty(global, 'navigator', {
      value: { onLine: false },
      configurable: true
    })
  })

  afterEach(() => {
    Object.defineProperty(global, 'navigator', {
      value: originalNavigator,
      configurable: true
    })
  })

  it('queues mutation when offline and returns queued response', async () => {
    const res = await apiPost<{ queued: boolean; mutation_id: string }>(
      '/api/v1/filters',
      { filter: { name: 'Test', filter_types: ['category'], filter_params: { categories: ['groceries'] } } }
    )

    expect(res.data).toMatchObject({ queued: true, mutation_id: 'mutation-123' })
    expect(res.meta.version).toBe('v1')
  })
})


