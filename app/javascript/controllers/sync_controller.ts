import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="sync"
export default class extends Controller {
  static targets = ['icon']

  declare readonly hasIconTarget: boolean
  declare readonly iconTarget: HTMLElement

  // Add spinning animation when form is submitted
  submit(_event?: Event): void {
    if (this.hasIconTarget) {
      this.iconTarget.classList.add('animate-spin')
    }
  }
}
