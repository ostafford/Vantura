import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter"
export default class extends Controller {
  static values = {
    url: String
  }

  // Navigate to filtered results when selection changes
  change(event) {
    const filterValue = event.target.value
    const url = this.urlValue + '?filter=' + filterValue
    window.location.href = url
  }
}

