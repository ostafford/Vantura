import { Controller } from "@hotwired/stimulus"

/**
 * Dropdown Controller
 * 
 * Manages dropdown menu open/close state with click-outside handling.
 * 
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["button", "menu"]
  static classes = ["open", "closed"]

  connect() {
    // Close dropdown when clicking outside
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.boundHandleClickOutside)
    
    // Close dropdown on escape key
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.boundHandleEscape)
    
    // Initialize as closed
    this.isOpen = false
    this.updateState()
  }

  disconnect() {
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleEscape)
  }

  toggle(event) {
    event?.preventDefault()
    event?.stopPropagation()
    
    this.isOpen = !this.isOpen
    this.updateState()
  }

  open() {
    this.isOpen = true
    this.updateState()
  }

  close() {
    this.isOpen = false
    this.updateState()
  }

  updateState() {
    if (!this.hasMenuTarget) return

    if (this.isOpen) {
      this.menuTarget.classList.remove('hidden')
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute('aria-expanded', 'true')
      }
    } else {
      this.menuTarget.classList.add('hidden')
      if (this.hasButtonTarget) {
        this.buttonTarget.setAttribute('aria-expanded', 'false')
      }
    }
  }

  handleClickOutside(event) {
    if (!this.isOpen) return
    
    // Close if clicking outside the dropdown
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === 'Escape' && this.isOpen) {
      this.close()
    }
  }
}

