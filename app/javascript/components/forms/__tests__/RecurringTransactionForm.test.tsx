import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import RecurringTransactionForm from '../../forms/RecurringTransactionForm'

vi.mock('../../../hooks/useRecurringMutations', () => ({
  useCreateRecurringTransaction: () => ({ mutateAsync: vi.fn().mockResolvedValue({}), isPending: false })
}))

describe('RecurringTransactionForm', () => {
  it('validates required fields', async () => {
    render(<RecurringTransactionForm />)

    fireEvent.click(screen.getByRole('button', { name: /create pattern/i }))

    expect(await screen.findByText(/Description is required/i)).toBeInTheDocument()
    expect(await screen.findByText(/Next occurrence date is required/i)).toBeInTheDocument()
  })

  it('auto-calculates next occurrence when frequency changes', async () => {
    const transactionDate = '2025-01-10'
    render(<RecurringTransactionForm transactionDate={transactionDate} description="Gym" amount={-50} />)

    const frequencySelect = screen.getByLabelText(/How often does this occur\?/i)
    fireEvent.change(frequencySelect, { target: { value: 'weekly' } })

    const nextDateInput = await screen.findByLabelText(/When is the next occurrence\?/i)
    expect(nextDateInput).toHaveValue('2025-01-17')
  })
})


