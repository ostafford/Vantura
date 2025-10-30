import { defineConfig } from 'vite'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  resolve: {
    // Add alias for cleaner imports
    alias: {
      '@': fileURLToPath(new URL('./app/javascript', import.meta.url)),
      // Importmap-style aliases for backward compatibility
      'controllers': fileURLToPath(new URL('./app/javascript/controllers', import.meta.url)),
      'helpers': fileURLToPath(new URL('./app/javascript/helpers', import.meta.url)),
      'utils': fileURLToPath(new URL('./app/javascript/utils', import.meta.url)),
      'pwa': fileURLToPath(new URL('./app/javascript/pwa.ts', import.meta.url)),
    },
  },
  build: {
    // Output to Rails asset directory (vite_ruby handles this)
    manifest: true,
    rollupOptions: {
      input: 'app/javascript/application.ts',
    },
    sourcemap: true,
  },
  server: {
    // Vite dev server configuration
    host: true,
    port: 3036,
  },
  test: {
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      statements: 65,
      branches: 55,
      functions: 60,
      lines: 65,
      include: ['app/javascript/**/*.{ts,tsx}'],
      exclude: ['**/__tests__/**', 'node_modules/**']
    }
  }
})

