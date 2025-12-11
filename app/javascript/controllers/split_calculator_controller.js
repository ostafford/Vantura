import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "totalAmount",
    "totalAmountCents",
    "splitMethod",
    "splitEvenly",
    "contributorsList",
    "contributorRow",
    "contributorCheckbox",
    "amountInput",
    "amountCents",
    "total",
    "validationMessage",
    "percentage"
  ]

  connect() {
    // Convert initial amount from cents to dollars if present
    if (this.hasTotalAmountCentsTarget && this.hasTotalAmountTarget) {
      const amountCents = this.totalAmountCentsTarget.value
      if (amountCents && parseFloat(amountCents) > 0) {
        const dollars = (parseFloat(amountCents) / 100).toFixed(2)
        this.totalAmountTarget.value = dollars
      }
    }
    
    // Add form submit handler to convert dollars to cents
    if (this.hasFormTarget) {
      this.boundHandleSubmit = this.handleSubmit.bind(this)
      this.formTarget.addEventListener('submit', this.boundHandleSubmit)
    }
    
    // Initialize split calculation after a short delay to ensure DOM is ready
    setTimeout(() => {
      this.updateSplit()
    }, 50)
  }
  
  disconnect() {
    if (this.boundHandleSubmit && this.hasFormTarget) {
      this.formTarget.removeEventListener('submit', this.boundHandleSubmit)
    }
  }
  
  handleSubmit(event) {
    // Ensure all amount_cents fields are updated from dollar inputs
    const splitMethod = document.querySelector('input[name="split_method"]:checked')?.value || "even"
    
    if (splitMethod === "even") {
      // When splitting evenly, disable all nested attribute fields
      // Backend will handle splitting via split_evenly_among_members
      const allNestedFields = this.formTarget.querySelectorAll('input[name*="[expense_contributions_attributes]"]')
      allNestedFields.forEach((field) => {
        field.disabled = true
      })
    } else {
      // For custom/percentage splits, only submit checked contributors
      const checkedContributors = Array.from(this.contributorCheckboxTargets).filter(cb => cb.checked)
      const allRows = Array.from(this.contributorRowTargets)
      
      allRows.forEach((row) => {
        const checkbox = row.querySelector('[data-split-calculator-target="contributorCheckbox"]')
        const isChecked = checkbox && checkbox.checked
        
        // Find all nested attribute fields in this row
        const nestedFields = row.querySelectorAll('input[name*="[expense_contributions_attributes]"]')
        
        nestedFields.forEach((field) => {
          if (isChecked) {
            field.disabled = false
          } else {
            // Disable unchecked contributor fields so they're not submitted
            field.disabled = true
          }
        })
      })
      
      // For custom/percentage splits, ensure cents fields are updated
      checkedContributors.forEach((checkbox) => {
        const row = checkbox.closest('[data-split-calculator-target="contributorRow"]')
        const amountInput = row?.querySelector('[data-split-calculator-target="amountInput"][data-amount-field="true"]')
        const amountCentsInput = row?.querySelector('[data-split-calculator-target="amountCents"]')
        
        if (amountInput && amountCentsInput) {
          const dollars = parseFloat(amountInput.value || 0)
          const cents = Math.round(dollars * 100)
          amountCentsInput.value = cents
          amountCentsInput.disabled = false // Ensure it's enabled for submission
        }
      })
    }
  }

  updateSplitMethod(event) {
    const method = event.target.value
    this.updateSplit()
  }

  updateSplit() {
    // Get total amount from dollars input and convert to cents
    const totalAmountDollars = parseFloat(this.totalAmountTarget?.value || 0)
    const totalAmountCents = Math.round(totalAmountDollars * 100)
    
    // Update hidden cents field
    if (this.hasTotalAmountCentsTarget) {
      this.totalAmountCentsTarget.value = totalAmountCents
    }
    
    const splitMethod = document.querySelector('input[name="split_method"]:checked')?.value || "even"
    const checkedContributors = Array.from(this.contributorCheckboxTargets).filter(cb => cb.checked)
    
    // Update split_evenly hidden field
    if (this.hasSplitEvenlyTarget) {
      this.splitEvenlyTarget.value = splitMethod === "even" ? "true" : "false"
    }
    
    if (checkedContributors.length === 0) {
      this.showValidation("Please select at least one contributor", true)
      return
    }

    let totalSplit = 0

    if (splitMethod === "even") {
      // Equal split
      const amountPerPerson = totalAmountDollars / checkedContributors.length
      const amountPerPersonCents = Math.round(amountPerPerson * 100)
      checkedContributors.forEach((checkbox) => {
        const row = checkbox.closest('[data-split-calculator-target="contributorRow"]')
        const amountInput = row?.querySelector('[data-split-calculator-target="amountInput"][data-amount-field="true"]')
        const amountCentsInput = row?.querySelector('[data-split-calculator-target="amountCents"]')
        const percentageSpan = row?.querySelector('[data-split-calculator-target="percentage"]')
        
        if (amountInput) {
          // Store as dollars for display
          amountInput.value = amountPerPerson.toFixed(2)
          totalSplit += amountPerPerson
        }
        
        if (amountCentsInput) {
          // Store actual cents value in hidden field
          amountCentsInput.value = amountPerPersonCents
        }
        
        if (percentageSpan) {
          const percentage = checkedContributors.length > 0 ? (100 / checkedContributors.length).toFixed(1) : "0"
          percentageSpan.textContent = `(${percentage}%)`
        }
      })
    } else if (splitMethod === "custom") {
      // Custom amounts - sum up what user entered
      checkedContributors.forEach((checkbox) => {
        const row = checkbox.closest('[data-split-calculator-target="contributorRow"]')
        const amountInput = row?.querySelector('[data-split-calculator-target="amountInput"][data-amount-field="true"]')
        const amountCentsInput = row?.querySelector('[data-split-calculator-target="amountCents"]')
        const percentageSpan = row?.querySelector('[data-split-calculator-target="percentage"]')
        
        if (amountInput) {
          const amount = parseFloat(amountInput.value || 0)
          const amountCents = Math.round(amount * 100)
          totalSplit += amount
          
          if (amountCentsInput) {
            amountCentsInput.value = amountCents
          }
          
          if (percentageSpan && totalAmountDollars > 0) {
            const percentage = ((amount / totalAmountDollars) * 100).toFixed(1)
            percentageSpan.textContent = `(${percentage}%)`
          }
        }
      })
    } else if (splitMethod === "percentage") {
      // Percentage split - calculate amounts from percentages
      // For now, we'll use equal percentages and let user adjust
      const percentagePerPerson = 100 / checkedContributors.length
      checkedContributors.forEach((checkbox) => {
        const row = checkbox.closest('[data-split-calculator-target="contributorRow"]')
        const amountInput = row?.querySelector('[data-split-calculator-target="amountInput"][data-amount-field="true"]')
        const amountCentsInput = row?.querySelector('[data-split-calculator-target="amountCents"]')
        const percentageSpan = row?.querySelector('[data-split-calculator-target="percentage"]')
        
        if (amountInput && percentageSpan) {
          const amount = (totalAmountDollars * percentagePerPerson) / 100
          const amountCents = Math.round(amount * 100)
          amountInput.value = amount.toFixed(2)
          
          if (amountCentsInput) {
            amountCentsInput.value = amountCents
          }
          
          totalSplit += amount
          percentageSpan.textContent = `(${percentagePerPerson.toFixed(1)}%)`
        }
      })
    }

    // Update total display
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = `$${totalSplit.toFixed(2)}`
    }

    // Validate total
    const difference = Math.abs(totalSplit - totalAmountDollars)
    if (difference > 0.01) {
      this.showValidation(`Total split ($${totalSplit.toFixed(2)}) does not match expense amount ($${totalAmountDollars.toFixed(2)})`, true)
    } else {
      this.showValidation("", false)
    }
  }

  showValidation(message, isError) {
    if (this.hasValidationMessageTarget) {
      this.validationMessageTarget.textContent = message
      this.validationMessageTarget.classList.toggle("text-red-600", isError)
      this.validationMessageTarget.classList.toggle("dark:text-red-400", isError)
      this.validationMessageTarget.classList.toggle("text-green-600", !isError && message)
      this.validationMessageTarget.classList.toggle("dark:text-green-400", !isError && message)
    }
  }
}

