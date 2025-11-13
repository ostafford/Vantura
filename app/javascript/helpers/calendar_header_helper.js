/**
 * Calendar Header Helper
 * 
 * Pure formatting utilities for calendar header data.
 * Used by calendar_header_controller.js to format balance amounts and header data.
 */

/**
 * Format balance amount with color coding
 * 
 * @param {number} amount - Balance amount to format
 * @returns {Object} Object with formatted text and color class
 */
export function formatBalance(amount) {
  const isNegative = amount < 0
  const formatted = Math.abs(amount).toLocaleString('en-US', { 
    minimumFractionDigits: 2, 
    maximumFractionDigits: 2 
  })
  const colorClass = isNegative 
    ? 'text-red-700 dark:text-red-200' 
    : 'text-green-700 dark:text-green-200'
  
  return { 
    text: `${isNegative ? '-' : ''}$${formatted}`, 
    colorClass 
  }
}

/**
 * Format complete header data for display
 * 
 * @param {number} currentBalance - Current account balance
 * @param {number} periodBalance - End of period balance
 * @param {string} periodDate - Formatted period end date
 * @param {string} periodLabel - Label for period (e.g., "End of Week", "End of Month")
 * @returns {Object} Formatted header data with all values and classes
 */
export function formatHeaderData(currentBalance, periodBalance, periodDate, periodLabel) {
  const currentBalanceData = formatBalance(currentBalance)
  const periodBalanceData = formatBalance(periodBalance)
  
  return {
    currentBalance: {
      text: currentBalanceData.text,
      colorClass: currentBalanceData.colorClass
    },
    period: {
      label: `${periodLabel} (${periodDate}):`,
      amount: periodBalanceData.text,
      colorClass: periodBalanceData.colorClass
    }
  }
}

