// Import and register all your controllers using Vite's glob import
import { application } from 'controllers/application'

// Auto-register all Stimulus controllers using Vite's glob import
// This replaces @hotwired/stimulus-loading which was only available via importmap
const controllerModules = import.meta.glob('./*_controller.ts', { eager: true })

// Register each controller with Stimulus
Object.entries(controllerModules).forEach(([path, module]) => {
  // Extract controller name from path (e.g., './hello_controller.ts' -> 'hello')
  const controllerName = path
    .replace('./', '')
    .replace('_controller.ts', '')
    .replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())
  
  // Get the default export (the controller class)
  const ControllerClass = (module as { default: typeof import('@hotwired/stimulus').Controller }).default
  
  if (ControllerClass) {
    application.register(controllerName, ControllerClass)
  }
})
