/**
 * Global type declarations for libraries available via Rails/importmap
 */

declare global {
  // Turbo is available globally via @hotwired/turbo-rails
  const Turbo: {
    visit: (url: string, options?: { frame?: string; action?: string }) => void
    renderStreamMessage: (html: string) => void
  }

  // Stimulus is available globally
  interface Window {
    Stimulus: import('@hotwired/stimulus').Application
  }

  // Vite import.meta.glob
  interface ImportMeta {
    glob: (pattern: string, options?: { eager?: boolean }) => Record<string, () => Promise<unknown>>
  }
}

export {}
