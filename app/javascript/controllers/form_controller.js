import { Controller } from "@hotwired/stimulus"

// Form validation and submission controller
export default class extends Controller {
  static targets = ["submit", "field"]
  static values = { 
    validateOnBlur: { type: Boolean, default: true },
    validateOnInput: { type: Boolean, default: false }
  }

  connect() {
    // Set up validation listeners
    if (this.validateOnBlurValue) {
      this.fieldTargets.forEach(field => {
        field.addEventListener('blur', this.validateField.bind(this))
      })
    }

    if (this.validateOnInputValue) {
      this.fieldTargets.forEach(field => {
        field.addEventListener('input', this.validateField.bind(this))
      })
    }

    // Prevent form submission if validation fails
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
  }

  disconnect() {
    // Cleanup event listeners if needed
  }

  validateField(event) {
    const field = event.target
    const isValid = this.isFieldValid(field)
    
    this.updateFieldState(field, isValid)
    this.updateSubmitButton()
  }

  validateAll() {
    let allValid = true
    
    this.fieldTargets.forEach(field => {
      const isValid = this.isFieldValid(field)
      this.updateFieldState(field, isValid)
      if (!isValid) allValid = false
    })

    this.updateSubmitButton()
    return allValid
  }

  isFieldValid(field) {
    // Check HTML5 validation
    if (!field.checkValidity()) {
      return false
    }

    // Check custom validation rules if present
    const customValidator = field.dataset.validate
    if (customValidator) {
      return this.runCustomValidator(field, customValidator)
    }

    return true
  }

  runCustomValidator(field, validatorName) {
    switch(validatorName) {
      case 'email':
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(field.value)
      case 'url':
        try {
          new URL(field.value)
          return true
        } catch {
          return false
        }
      case 'phone':
        return /^[\d\s\-\+\(\)]+$/.test(field.value)
      default:
        return true
    }
  }

  updateFieldState(field, isValid) {
    // Remove existing validation classes
    field.classList.remove('border-red-500', 'border-green-500', 'ring-red-500', 'ring-green-500')
    
    if (field.value.length > 0) {
      if (isValid) {
        field.classList.add('border-green-500', 'ring-green-500')
      } else {
        field.classList.add('border-red-500', 'ring-red-500')
      }
    }

    // Update error message if present
    const errorElement = field.parentElement.querySelector('.text-red-600')
    if (errorElement) {
      if (!isValid && !field.validity.valid) {
        errorElement.textContent = field.validationMessage
        errorElement.classList.remove('hidden')
      } else {
        errorElement.classList.add('hidden')
      }
    }
  }

  updateSubmitButton() {
    if (this.hasSubmitTarget) {
      const allValid = this.fieldTargets.every(field => {
        if (field.hasAttribute('required') && field.value.length === 0) {
          return false
        }
        return this.isFieldValid(field)
      })

      this.submitTarget.disabled = !allValid
    }
  }

  handleSubmit(event) {
    if (!this.validateAll()) {
      event.preventDefault()
      event.stopPropagation()
      
      // Focus first invalid field
      const firstInvalid = this.fieldTargets.find(field => !this.isFieldValid(field))
      if (firstInvalid) {
        firstInvalid.focus()
        firstInvalid.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }
    }
  }

  // Public method to manually validate form
  validate() {
    return this.validateAll()
  }

  // Public method to reset form validation state
  reset() {
    this.fieldTargets.forEach(field => {
      field.classList.remove('border-red-500', 'border-green-500', 'ring-red-500', 'ring-green-500')
      const errorElement = field.parentElement.querySelector('.text-red-600')
      if (errorElement) {
        errorElement.classList.add('hidden')
      }
    })
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
  }
}

