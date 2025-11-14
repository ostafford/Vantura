import { Controller } from "@hotwired/stimulus"
import { visitFrame } from "helpers/frame_navigation_helper"

const REMEMBER_EVENT = "frame-navigation:remember-scroll"

/**
 * Generic navigation controller that prefers Turbo Stream updates for frame links.
 * Dispatches custom events for scroll preservation helpers.
 */
export default class extends Controller {
  static values = {
    frameId: String
  }

  async navigate(event) {
    const link = event.currentTarget
    if (!(link instanceof HTMLAnchorElement)) {
      return
    }

    const url = link.href
    const frameId = this.frameIdValue || link.dataset.turboFrame
    const frame = frameId ? document.getElementById(frameId) : null

    frame?.dispatchEvent(new CustomEvent(REMEMBER_EVENT))
    event.preventDefault()

    await visitFrame(url, frameId)
  }
}


