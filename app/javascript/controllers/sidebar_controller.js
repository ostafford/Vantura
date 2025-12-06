import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop"]

  connect() {
    // Sidebar is controlled by Flowbite's drawer component
    // This controller handles any additional custom behavior if needed
  }

  toggle() {
    const sidebar = document.getElementById('sidebar')
    const backdrop = this.backdropTarget
    
    if (sidebar.classList.contains('-translate-x-full')) {
      sidebar.classList.remove('-translate-x-full')
      backdrop.classList.remove('hidden')
    } else {
      sidebar.classList.add('-translate-x-full')
      backdrop.classList.add('hidden')
    }
  }

  close() {
    const sidebar = document.getElementById('sidebar')
    const backdrop = this.backdropTarget
    
    sidebar.classList.add('-translate-x-full')
    backdrop.classList.add('hidden')
  }
}

