import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview"]

  connect() {
    // Avatar upload controller for preview functionality
  }

  preview(event) {
    const file = event.target.files[0]
    if (!file) return

    // Validate file type
    if (!file.type.match('image.*')) {
      alert('Please select an image file')
      event.target.value = ''
      return
    }

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      alert('File size must be less than 5MB')
      event.target.value = ''
      return
    }

    // Create preview
    const reader = new FileReader()
    reader.onload = (e) => {
      const previewTarget = this.previewTarget
      
      // If preview is a div placeholder, replace it with an img
      if (previewTarget.tagName === 'DIV') {
        const img = document.createElement('img')
        img.src = e.target.result
        img.className = 'w-20 h-20 rounded-full object-cover'
        img.id = 'avatar-preview'
        img.setAttribute('data-avatar-upload-target', 'preview')
        previewTarget.parentNode.replaceChild(img, previewTarget)
        // Stimulus will automatically find the new element on next access
      } else {
        // Update existing image
        previewTarget.src = e.target.result
      }
    }
    reader.readAsDataURL(file)
  }

  upload() {
    // File upload is handled by Rails form submission
    // This method can be used for additional UI feedback if needed
  }
}

