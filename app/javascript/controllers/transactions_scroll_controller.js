   // app/javascript/controllers/transactions_scroll_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    storageKey: { type: String, default: "transactions_scroll_position" }
  }

  connect() {
    this.rememberHandler = this.remember.bind(this)
    this.restoreScrollHandler = this.restoreScroll.bind(this)
    this.handleClickCapture = this.handleClick.bind(this)

    // Frame-specific events
    this.element.addEventListener("turbo:frame-load", this.restoreScrollHandler)
    this.element.addEventListener("turbo:before-fetch-request", this.rememberHandler)
    this.element.addEventListener("turbo:submit-start", this.rememberHandler)
    this.element.addEventListener("frame-navigation:restore-scroll", this.restoreScrollHandler)
    this.element.addEventListener("frame-navigation:remember-scroll", this.rememberHandler)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.restoreScrollHandler)
    this.element.removeEventListener("turbo:before-fetch-request", this.rememberHandler)
    this.element.removeEventListener("turbo:submit-start", this.rememberHandler)
    this.element.removeEventListener("frame-navigation:restore-scroll", this.restoreScrollHandler)
    this.element.removeEventListener("frame-navigation:remember-scroll", this.rememberHandler)
  }

  handleClick(event) {
    const trigger = event.target.closest("[data-turbo-frame]")
    if (!trigger) return

    const frameId = trigger.getAttribute("data-turbo-frame")
    if (!frameId || frameId !== this.element.id) return

    console.debug("[transactions-scroll] click capture matched trigger", {
      frameId,
      href: trigger.getAttribute("href")
    })
    this.remember()
  }

  remember() {
    console.debug("[transactions-scroll] remember scroll", { y: window.scrollY })
    sessionStorage.setItem(this.storageKeyValue, window.scrollY.toString())
  }

  restoreScroll() {
    const rawValue = sessionStorage.getItem(this.storageKeyValue)
    if (!rawValue) return

    sessionStorage.removeItem(this.storageKeyValue)
    const y = parseInt(rawValue, 10)
    if (Number.isNaN(y)) return

    console.debug("[transactions-scroll] restore scroll", { y })
    requestAnimationFrame(() => {
      requestAnimationFrame(() => window.scrollTo(0, y))
    })
  }
}