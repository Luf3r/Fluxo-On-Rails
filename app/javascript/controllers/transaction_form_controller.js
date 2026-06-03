import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "destination", "destinationSelect"]

  connect() {
    this.toggle()
  }

  toggle() {
    const transferSelected = this.typeTarget.value === "transfer"

    this.destinationTarget.classList.toggle("hidden", !transferSelected)
    this.destinationSelectTarget.disabled = !transferSelected
    this.destinationSelectTarget.required = transferSelected

    if (!transferSelected) {
      this.destinationSelectTarget.value = ""
    }
  }
}
