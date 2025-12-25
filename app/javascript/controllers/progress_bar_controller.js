import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    width: Number
  }

  connect() {
    this.updateWidth()
  }

  widthValueChanged() {
    this.updateWidth()
  }

  updateWidth() {
    const width = Math.min(Math.max(this.widthValue, 0), 100)
    this.element.style.width = `${width}%`
  }
}

