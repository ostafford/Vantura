import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  scrollToCard(event) {
    event.preventDefault()
    const targetId = event.currentTarget.getAttribute("href")?.substring(1)
    
    if (!targetId) return

    const targetElement = document.getElementById(targetId)
    
    if (targetElement) {
      // Smooth scroll to target
      targetElement.scrollIntoView({ 
        behavior: "smooth", 
        block: "center" 
      })
      
      // Highlight the card briefly
      targetElement.classList.add("ring-4", "ring-primary-500", "ring-opacity-50", "transition-all", "duration-300")
      
      // Remove highlight after 2 seconds
      setTimeout(() => {
        targetElement.classList.remove("ring-4", "ring-primary-500", "ring-opacity-50")
      }, 2000)
    }
  }

  scrollToChart(event) {
    event.preventDefault()
    const chartId = event.currentTarget.dataset.chartTarget
    
    if (!chartId) return

    const chartElement = document.getElementById(chartId)
    
    if (chartElement) {
      // Find the parent chart card
      const chartCard = chartElement.closest(".bg-gradient-to-br")
      
      if (chartCard) {
        chartCard.scrollIntoView({ 
          behavior: "smooth", 
          block: "center" 
        })
        
        // Highlight the chart card briefly
        chartCard.classList.add("ring-4", "ring-primary-500", "ring-opacity-50", "transition-all", "duration-300")
        
        setTimeout(() => {
          chartCard.classList.remove("ring-4", "ring-primary-500", "ring-opacity-50")
        }, 2000)
      }
    }
  }
}

