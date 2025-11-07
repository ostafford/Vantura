import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recurring-edit"
export default class extends Controller {
  // Toggle custom category input when "other" is selected
  toggleCustomCategory(event) {
    const categorySelect = event.target
    const customCategoryField = document.getElementById('edit-custom-category-field')
    const customCategoryInput = document.getElementById('edit-custom-category-name-input')
    
    if (categorySelect.value === 'other') {
      customCategoryField.classList.remove('hidden')
      customCategoryInput.required = true
    } else {
      customCategoryField.classList.add('hidden')
      customCategoryInput.required = false
      customCategoryInput.value = ''
    }
  }
}

