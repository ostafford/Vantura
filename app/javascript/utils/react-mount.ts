/**
 * Universal React island mounting utility
 * Mounts React components from data-react-mount attributes in ERB views
 *
 * Usage in ERB:
 *   <div data-react-mount="ComponentName" data-props='{"prop": "value"}'></div>
 *
 * Component must be exported from app/javascript/components/
 */

import React from 'react'
import { createRoot, Root } from 'react-dom/client'

// Component registry - maps component names to their imports
const componentRegistry = new Map<string, () => Promise<{ default: React.ComponentType<any> }>>()

// Root registry - tracks mounted React roots
const rootRegistry = new Map<Element, Root>()

/**
 * Register a React component for island mounting
 * @param name - Component name (used in data-react-mount attribute)
 * @param componentLoader - Async function that imports the component
 */
export function registerReactComponent(
  name: string,
  componentLoader: () => Promise<{ default: React.ComponentType<any> }>
): void {
  componentRegistry.set(name, componentLoader)
}

/**
 * Mount a React component on an element
 * @param element - DOM element to mount component on
 * @param componentName - Name of component (from data-react-mount)
 * @param props - Props to pass to component
 */
async function mountComponent(
  element: Element,
  componentName: string,
  props: Record<string, unknown>
): Promise<void> {
  const loader = componentRegistry.get(componentName)
  if (!loader) {
    console.error(`[React Mount] Component "${componentName}" not registered`)
    return
  }

  try {
    // Import the component
    const module = await loader()
    const Component = module.default

    // Create React root and render
    const root = createRoot(element)
    // eslint-disable-next-line react/react-in-jsx-scope
    root.render(React.createElement(Component, props))

    // Track root for cleanup
    rootRegistry.set(element, root)
  } catch (error) {
    console.error(`[React Mount] Failed to mount component "${componentName}":`, error)
  }
}

// Note: unmountComponent is intentionally not exported - cleanup happens via cleanupReactMounts

/**
 * Initialize React island mounting
 * Scans for data-react-mount attributes and mounts components
 */
export function initializeReactMounts(): void {
  // Find all elements with data-react-mount attribute
  const mountPoints = document.querySelectorAll('[data-react-mount]')

  mountPoints.forEach(async (element) => {
    const componentName = element.getAttribute('data-react-mount')
    if (!componentName) return

    // Parse props from data-props attribute
    let props: Record<string, unknown> = {}
    const propsAttr = element.getAttribute('data-props')
    if (propsAttr) {
      try {
        props = JSON.parse(propsAttr)
      } catch (error) {
        console.error(`[React Mount] Failed to parse props for "${componentName}":`, error)
      }
    }

    // Mount the component
    await mountComponent(element, componentName, props)
  })
}

/**
 * Clean up React mounts (unmount all components)
 */
export function cleanupReactMounts(): void {
  rootRegistry.forEach((root, element) => {
    root.unmount()
    rootRegistry.delete(element)
  })
  rootRegistry.clear()
}

/**
 * Re-initialize React mounts (useful after Turbo navigation)
 */
export function reinitializeReactMounts(): void {
  cleanupReactMounts()
  initializeReactMounts()
}

// Register React components
// Import components lazily to enable code-splitting
registerReactComponent('IncomeExpenseChart', () => import('../components/charts/IncomeExpenseChart'))
registerReactComponent('CategoryBreakdownChart', () => import('../components/charts/CategoryBreakdownChart'))
registerReactComponent('MerchantAnalysisChart', () => import('../components/charts/MerchantAnalysisChart'))
registerReactComponent('TransactionTable', () => import('../components/tables/TransactionTable'))
registerReactComponent('RecurringTransactionTable', () => import('../components/tables/RecurringTransactionTable'))
registerReactComponent('FilterForm', () => import('../components/forms/FilterForm'))
registerReactComponent('RecurringTransactionForm', () => import('../components/forms/RecurringTransactionForm'))
registerReactComponent('FilterDeleteBinder', () => import('../components/analysis/FilterDeleteBinder'))

// Auto-initialize on DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeReactMounts)
} else {
  initializeReactMounts()
}

// Re-initialize on Turbo navigation
document.addEventListener('turbo:load', reinitializeReactMounts)
document.addEventListener('turbo:frame-load', reinitializeReactMounts)

