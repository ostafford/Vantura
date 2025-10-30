import React from 'react'
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import RecurringTransactionTable from '../RecurringTransactionTable'

describe('RecurringTransactionTable', () => {
  it('renders empty state', () => {
    render(<RecurringTransactionTable />)
    expect(screen.getByText('Loading')).toBeTruthy()
  })
})


