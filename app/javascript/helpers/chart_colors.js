/**
 * Chart Color Palette Helper
 * 
 * Provides semantic color palette for charts (ApexCharts, etc.)
 * Maps design system semantic tokens to hex colors for chart library compatibility.
 * 
 * Note: Chart libraries require hex colors, but our design system uses OKLCH tokens.
 * This helper provides a bridge between the two.
 * 
 * For server-side color generation (recommended), see app/helpers/charts_helper.rb
 */

/**
 * Get default chart color palette using semantic design system colors
 * 
 * @returns {string[]} Array of hex color codes in semantic order
 */
export function getChartColorPalette() {
  // Default palette using semantic color order
  // These hex values are derived from OKLCH tokens in application.css
  // Primary-500, Expense-500, Success-500, Warning-500, Info-500, Planning-500, Income-500, Coral-500, Neutral-500
  
  return [
    '#3B82F6', // primary-500 (blue)
    '#EF4444', // expense-500 (red) - Note: using standard red, design system uses custom expense palette
    '#10B981', // success-500 (green)
    '#F59E0B', // warning-500 (amber)
    '#06B6D4', // info-500 (cyan)
    '#8B5CF6', // planning-500 (purple)
    '#14B8A6', // income-500 (teal)
    '#F97316', // coral-500 (orange)
    '#6B7280'  // neutral-500 (gray)
  ]
}

/**
 * Get chart color for specific semantic token
 * 
 * @param {string} token - Semantic color token (e.g., 'primary-500', 'expense-600')
 * @returns {string} Hex color code
 */
export function getChartColor(token) {
  const colorMap = {
    // Primary palette
    'primary-50': '#EFF6FF',
    'primary-100': '#DBEAFE',
    'primary-200': '#BFDBFE',
    'primary-300': '#93C5FD',
    'primary-400': '#60A5FA',
    'primary-500': '#3B82F6',
    'primary-600': '#2563EB',
    'primary-700': '#1D4ED8',
    'primary-800': '#1E40AF',
    'primary-900': '#1E3A8A',
    
    // Expense palette (red-based)
    'expense-50': '#FEF2F2',
    'expense-100': '#FEE2E2',
    'expense-200': '#FECACA',
    'expense-300': '#FCA5A5',
    'expense-400': '#F87171',
    'expense-500': '#EF4444',
    'expense-600': '#DC2626',
    'expense-700': '#B91C1C',
    'expense-800': '#991B1B',
    'expense-900': '#7F1D1D',
    
    // Success palette (green-based)
    'success-50': '#F0FDF4',
    'success-100': '#DCFCE7',
    'success-200': '#BBF7D0',
    'success-300': '#86EFAC',
    'success-400': '#4ADE80',
    'success-500': '#10B981',
    'success-600': '#059669',
    'success-700': '#047857',
    'success-800': '#065F46',
    'success-900': '#064E3B',
    
    // Warning palette (amber-based)
    'warning-50': '#FFFBEB',
    'warning-100': '#FEF3C7',
    'warning-200': '#FDE68A',
    'warning-300': '#FCD34D',
    'warning-400': '#FBBF24',
    'warning-500': '#F59E0B',
    'warning-600': '#D97706',
    'warning-700': '#B45309',
    'warning-800': '#92400E',
    'warning-900': '#78350F',
    
    // Info palette (cyan-based)
    'info-50': '#ECFEFF',
    'info-100': '#CFFAFE',
    'info-200': '#A5F3FC',
    'info-300': '#67E8F9',
    'info-400': '#22D3EE',
    'info-500': '#06B6D4',
    'info-600': '#0891B2',
    'info-700': '#0E7490',
    'info-800': '#155E75',
    'info-900': '#164E63',
    
    // Planning palette (purple-based)
    'planning-50': '#FAF5FF',
    'planning-100': '#F3E8FF',
    'planning-200': '#E9D5FF',
    'planning-300': '#D8B4FE',
    'planning-400': '#C084FC',
    'planning-500': '#8B5CF6',
    'planning-600': '#7C3AED',
    'planning-700': '#6D28D9',
    'planning-800': '#5B21B6',
    'planning-900': '#4C1D95',
    
    // Income palette (teal-based)
    'income-50': '#F0FDFA',
    'income-100': '#CCFBF1',
    'income-200': '#99F6E4',
    'income-300': '#5EEAD4',
    'income-400': '#2DD4BF',
    'income-500': '#14B8A6',
    'income-600': '#0D9488',
    'income-700': '#0F766E',
    'income-800': '#115E59',
    'income-900': '#134E4A',
    
    // Coral palette (orange-based)
    'coral-50': '#FFF7ED',
    'coral-100': '#FFEDD5',
    'coral-200': '#FED7AA',
    'coral-300': '#FDBA74',
    'coral-400': '#FB923C',
    'coral-500': '#F97316',
    'coral-600': '#EA580C',
    'coral-700': '#C2410C',
    'coral-800': '#9A3412',
    'coral-900': '#7C2D12',
    
    // Neutral palette (gray-based)
    'neutral-50': '#F9FAFB',
    'neutral-100': '#F3F4F6',
    'neutral-200': '#E5E7EB',
    'neutral-300': '#D1D5DB',
    'neutral-400': '#9CA3AF',
    'neutral-500': '#6B7280',
    'neutral-600': '#4B5563',
    'neutral-700': '#374151',
    'neutral-800': '#1F2937',
    'neutral-900': '#111827'
  }
  
  return colorMap[token] || '#6B7280' // Default to neutral-500
}

