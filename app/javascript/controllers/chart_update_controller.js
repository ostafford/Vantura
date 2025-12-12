import { Controller } from "@hotwired/stimulus"

// Chart Update Controller
// Handles Turbo Stream updates for Chartkick charts
// Chartkick automatically re-renders charts when the DOM is updated via Turbo Stream replace
export default class extends Controller {
  connect() {
    // Chartkick automatically initializes charts on connect
    // This controller handles Turbo Stream updates
    // When Turbo Stream replaces the chart container, Chartkick will detect
    // the new chart element and initialize it automatically
  }

  // Called when Turbo Stream replaces the chart container
  // Chartkick will automatically detect and re-render the chart
  update() {
    // Chartkick handles chart re-initialization automatically
    // when the DOM is updated via Turbo Stream replace
  }
}

