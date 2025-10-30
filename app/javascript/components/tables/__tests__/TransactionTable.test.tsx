import React from 'react'
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import TransactionTable from '../TransactionTable'

describe('TransactionTable', () => {
  it('renders headers', () => {
    render(<TransactionTable initialTransactions={[]} />)
    expect(screen.getByText('No transactions')).toBeInTheDocument()
  })
})


