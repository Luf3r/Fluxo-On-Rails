import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "destination", "destinationSelect", "categorization", "categorySelect", "tagNames"]

  connect() {
    this.toggle()
  }

  toggle() {
    const transferSelected = this.typeTarget.value === "transfer"

    this.destinationTarget.classList.toggle("hidden", !transferSelected)
    this.destinationSelectTarget.disabled = !transferSelected
    this.destinationSelectTarget.required = transferSelected
    this.categorizationTarget.classList.toggle("hidden", transferSelected)
    this.categorySelectTarget.disabled = transferSelected
    this.tagNamesTarget.disabled = transferSelected

    if (!transferSelected) {
      this.destinationSelectTarget.value = ""
    } else {
      this.categorySelectTarget.value = ""
      this.tagNamesTarget.value = ""
    }
  }
}
