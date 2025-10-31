import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="expense-row"
export default class extends Controller {
  toggle(event) {
    // Prevent event if clicking on action links/buttons
    if (event.target.closest('a, button, form')) {
      return
    }

    // Find the contributions row (next sibling <tr> element)
    const contributionsRow = this.element.nextElementSibling
    if (!contributionsRow || !contributionsRow.hasAttribute('data-expense-row-target')) {
      return
    }
    
    const isHidden = contributionsRow.classList.contains('hidden')
    const chevron = this.element.querySelector('.chevron-icon')
    
    if (isHidden) {
      contributionsRow.classList.remove('hidden')
      // Update chevron icon to point down (rotate 90 degrees from right)
      if (chevron) {
        chevron.classList.add('rotate-90')
      }
    } else {
      contributionsRow.classList.add('hidden')
      // Update chevron icon to point right (remove rotation)
      if (chevron) {
        chevron.classList.remove('rotate-90')
      }
    }
  }
}

