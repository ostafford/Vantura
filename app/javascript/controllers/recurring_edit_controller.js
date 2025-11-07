import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recurring-edit"
export default class extends Controller {
  static targets = ["categorySelect", "customCategoryField", "customCategoryInput"]
  
  // Toggle custom category input when "other" is selected
  toggleCustomCategory(event) {
    const categorySelect = event.target
    const customCategoryField = document.getElementById('edit-custom-category-field')
    const customCategoryInput = document.getElementById('edit-custom-category-name-input')
    
    // Ensure elements exist
    if (!customCategoryField || !customCategoryInput) {
      console.error('Custom category field elements not found', {
        field: !!customCategoryField,
        input: !!customCategoryInput
      })
      return
    }
    
    // Check if "other" is selected (case-insensitive check)
    const isOther = categorySelect.value === 'other'
    
    if (isOther) {
      customCategoryField.classList.remove('hidden')
      customCategoryInput.required = true
      customCategoryInput.focus()
    } else {
      customCategoryField.classList.add('hidden')
      customCategoryInput.required = false
      customCategoryInput.value = ''
    }
  }
  
  // Check on connect if "other" is already selected (e.g., when editing existing)
  connect() {
    const categorySelect = document.getElementById('edit-recurring-category-select')
    if (categorySelect) {
      // Set up event listener if not already attached
      if (!categorySelect.dataset.listenerAttached) {
        categorySelect.dataset.listenerAttached = 'true'
      }
      
      // Check if "other" is already selected
      if (categorySelect.value === 'other') {
        this.toggleCustomCategory({ target: categorySelect })
      }
    }
  }
}

