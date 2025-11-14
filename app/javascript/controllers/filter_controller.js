import { Controller } from "@hotwired/stimulus"
import { visitFrame } from "helpers/frame_navigation_helper"

// Connects to data-controller="filter"
export default class extends Controller {
  static values = {
    url: String,
    turboFrame: String
  }

  // Navigate to filtered results when selection changes
  async change(event) {
    const filterValue = event.target.value
    const { dataset } = event.target
    const baseUrlString = dataset.filterUrlValue || this.urlValue || window.location.href
    const frameId = dataset.filterTurboFrameValue || this.turboFrameValue
    const frame = frameId ? document.getElementById(frameId) : null

    const targetUrl = new URL(baseUrlString, window.location.origin)
    targetUrl.searchParams.set("filter", filterValue)

    frame?.dispatchEvent(new CustomEvent("frame-navigation:remember-scroll"))
    await visitFrame(targetUrl.toString(), frameId)
  }
}

