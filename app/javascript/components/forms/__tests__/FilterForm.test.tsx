import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import FilterForm from '../../forms/FilterForm'

vi.mock('../../../hooks/useFilters', () => ({
  useCreateFilter: () => ({ mutateAsync: vi.fn().mockResolvedValue({}), isPending: false }),
  useUpdateFilter: () => ({ mutateAsync: vi.fn().mockResolvedValue({}), isPending: false })
}))

describe('FilterForm', () => {
  it('validates required fields before submit', async () => {
    render(<FilterForm availableCategories={['groceries']} availableMerchants={['Woolworths']} availableStatuses={['SETTLED']} />)

    const submit = screen.getByRole('button', { name: /save filter/i })
    fireEvent.click(submit)

    expect(await screen.findByText(/Filter name is required/i)).toBeInTheDocument()
    expect(await screen.findByText(/At least one filter type must be selected/i)).toBeInTheDocument()
  })

  it('submits when valid with selected types and params', async () => {
    const onSuccess = vi.fn()
    render(
      <FilterForm
        availableCategories={['groceries']}
        availableMerchants={['Woolworths']}
        availableStatuses={['SETTLED']}
        onSuccess={onSuccess}
      />
    )

    fireEvent.change(screen.getByLabelText(/Filter Name/i), { target: { value: 'Grocery Spree' } })

    // select category type
    const categoryCheckbox = screen.getByText(/category/i).closest('label')!.querySelector('input')!
    fireEvent.click(categoryCheckbox)

    // pick a category
    const categoriesSelect = await screen.findByLabelText(/Categories/i)
    fireEvent.change(categoriesSelect, { target: { selectedOptions: [{ value: 'groceries' }] } })

    fireEvent.click(screen.getByRole('button', { name: /save filter/i }))

    await waitFor(() => expect(onSuccess).toHaveBeenCalled())
  })
})


