import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="month-nav"
// Generic controller that works for both calendar and projects pages
export default class extends Controller {
  static targets = ["header", "dropdown", "yearSelect", "monthButton", "weekYearSelect", "weekMonthSelect", "weekList"]
  static values = {
    urlPattern: String,
    urlType: String,
    viewMode: String,
    currentYear: Number,
    currentMonth: Number,
    currentWeekYear: Number,
    currentWeekMonth: Number,
    currentWeekDay: Number,
    turboFrame: String
  }

  connect() {
    // Close dropdown when clicking outside
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    
    // Track selected year and month for navigation
    this.selectedYear = this.currentYearValue
    this.selectedMonth = this.currentMonthValue
    
    // For week view, track selected week year and month
    if (this.viewModeValue === 'week') {
      this.selectedWeekYear = this.hasCurrentWeekYearValue ? this.currentWeekYearValue : this.currentYearValue
      this.selectedWeekMonth = this.hasCurrentWeekMonthValue ? this.currentWeekMonthValue : this.currentMonthValue
    }
  }

  disconnect() {
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  togglePicker(event) {
    event.stopPropagation()
    const isOpen = !this.dropdownTarget.classList.contains('hidden')
    
    if (isOpen) {
      this.closePicker()
    } else {
      this.openPicker()
    }
  }

  openPicker() {
    this.dropdownTarget.classList.remove('hidden')
    
    if (this.viewModeValue === 'week') {
      // Reset to current week values when opening
      this.selectedWeekYear = this.hasCurrentWeekYearValue ? this.currentWeekYearValue : this.currentYearValue
      this.selectedWeekMonth = this.hasCurrentWeekMonthValue ? this.currentWeekMonthValue : this.currentMonthValue
      this.weekYearSelectTarget.value = this.selectedWeekYear
      this.weekMonthSelectTarget.value = this.selectedWeekMonth
      
      // Generate weeks for the selected month
      this.generateWeeksForMonth(this.selectedWeekYear, this.selectedWeekMonth)
    } else {
      // Reset to current values when opening
      this.selectedYear = this.currentYearValue
      this.selectedMonth = this.currentMonthValue
      this.yearSelectTarget.value = this.selectedYear
      
      // Update month button states
      this.updateMonthButtonStates()
    }
    
    // Add event listeners
    setTimeout(() => {
      document.addEventListener('click', this.boundHandleClickOutside)
      document.addEventListener('keydown', this.boundHandleKeydown)
    }, 0)
  }

  closePicker() {
    this.dropdownTarget.classList.add('hidden')
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  handleClickOutside(event) {
    // Check if click is outside both the dropdown and the header button
    const isOutsideDropdown = !this.dropdownTarget.contains(event.target)
    const isOutsideHeader = !this.headerTarget.contains(event.target)
    
    if (isOutsideDropdown && isOutsideHeader) {
      this.closePicker()
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.closePicker()
    }
  }

  selectYear(event) {
    this.selectedYear = parseInt(event.target.value)
    this.updateMonthButtonStates()
  }

  selectMonth(event) {
    this.selectedMonth = parseInt(event.currentTarget.dataset.monthValue)
    
    // Navigate to the selected month/year
    this.navigateToMonth(this.selectedYear, this.selectedMonth)
  }

  selectWeekYear(event) {
    this.selectedWeekYear = parseInt(event.target.value)
    this.generateWeeksForMonth(this.selectedWeekYear, this.selectedWeekMonth)
  }

  selectWeekMonth(event) {
    this.selectedWeekMonth = parseInt(event.target.value)
    this.generateWeeksForMonth(this.selectedWeekYear, this.selectedWeekMonth)
  }

  generateWeeksForMonth(year, month) {
    // Get the first day of the month
    const firstDay = new Date(year, month - 1, 1)
    // Get the last day of the month
    const lastDay = new Date(year, month, 0)
    
    // Find all weeks that have at least one day in this month
    const weeks = []
    
    // Start from the Monday of the week containing the first day of the month
    const currentWeek = new Date(firstDay)
    const dayOfWeek = currentWeek.getDay()
    const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1 // Convert Sunday=0 to Monday offset
    currentWeek.setDate(currentWeek.getDate() - mondayOffset)
    
    // Generate weeks until the Monday is past the last day of the month
    const maxIterations = 10
    let iterations = 0
    
    while (iterations < maxIterations) {
      const weekStart = new Date(currentWeek)
      const weekEnd = new Date(currentWeek)
      weekEnd.setDate(weekEnd.getDate() + 6) // Sunday
      
      // Check if this week has any day in the selected month
      // A week belongs to the month if its Monday is in the month OR if it overlaps with the month
      if (weekStart <= lastDay && weekEnd >= firstDay) {
        weeks.push({
          start: new Date(weekStart),
          end: new Date(weekEnd)
        })
      }
      
      // Move to next week (Monday)
      currentWeek.setDate(currentWeek.getDate() + 7)
      
      // Stop if we've passed the last day of the month
      if (weekStart > lastDay) {
        break
      }
      
      iterations++
    }
    
    // Render weeks
    this.renderWeeks(weeks, year, month)
  }

  renderWeeks(weeks, year, month) {
    const weekList = this.weekListTarget
    weekList.innerHTML = ''
    
    // Get current week for highlighting
    const currentWeekYear = this.hasCurrentWeekYearValue ? this.currentWeekYearValue : this.currentYearValue
    const currentWeekMonth = this.hasCurrentWeekMonthValue ? this.currentWeekMonthValue : this.currentMonthValue
    const currentWeekDay = this.hasCurrentWeekDayValue ? this.currentWeekDayValue : 1
    
    const currentWeekStart = new Date(currentWeekYear, currentWeekMonth - 1, currentWeekDay)
    const currentWeekMonday = new Date(currentWeekStart)
    const dayOfWeek = currentWeekMonday.getDay()
    const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    currentWeekMonday.setDate(currentWeekMonday.getDate() - mondayOffset)
    
    weeks.forEach(week => {
      const isCurrentWeek = week.start.getTime() === currentWeekMonday.getTime()
      
      const button = document.createElement('button')
      button.type = 'button'
      button.className = `w-full px-3 py-2 text-sm text-left rounded-lg transition-all ${
        isCurrentWeek 
          ? 'bg-primary-700 text-white dark:bg-primary-600' 
          : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
      }`
      button.dataset.action = 'click->month-nav#selectWeek'
      button.dataset.weekStartYear = week.start.getFullYear()
      button.dataset.weekStartMonth = week.start.getMonth() + 1
      button.dataset.weekStartDay = week.start.getDate()
      
      // Format: "Jan 1 - Jan 7" or "Dec 30 - Jan 5"
      const formatDate = (date) => {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        return `${months[date.getMonth()]} ${date.getDate()}`
      }
      
      const startStr = formatDate(week.start)
      const endStr = formatDate(week.end)
      const endYear = week.end.getFullYear() !== year ? `, ${week.end.getFullYear()}` : ''
      
      button.textContent = `${startStr} - ${endStr}${endYear}`
      
      weekList.appendChild(button)
    })
  }

  selectWeek(event) {
    const year = parseInt(event.currentTarget.dataset.weekStartYear)
    const month = parseInt(event.currentTarget.dataset.weekStartMonth)
    const day = parseInt(event.currentTarget.dataset.weekStartDay)
    
    // Navigate to the selected week
    this.navigateToWeek(year, month, day)
  }

  updateMonthButtonStates() {
    this.monthButtonTargets.forEach(button => {
      const monthNum = parseInt(button.dataset.monthValue)
      // Check if this is the currently displayed month (based on current values, not selected)
      const isCurrentMonth = monthNum === this.currentMonthValue && 
                             this.selectedYear === this.currentYearValue
      
      // Update classes based on current month display
      if (isCurrentMonth) {
        button.classList.remove('bg-gray-100', 'dark:bg-gray-700', 'text-gray-700', 'dark:text-gray-300', 'hover:bg-gray-200', 'dark:hover:bg-gray-600')
        button.classList.add('bg-primary-700', 'text-white', 'dark:bg-primary-600')
      } else {
        button.classList.remove('bg-primary-700', 'text-white', 'dark:bg-primary-600')
        button.classList.add('bg-gray-100', 'dark:bg-gray-700', 'text-gray-700', 'dark:text-gray-300', 'hover:bg-gray-200', 'dark:hover:bg-gray-600')
      }
    })
  }

  navigateToMonth(year, month) {
    // Build URL from pattern
    let url = this.buildUrl(year, month)
    
    if (!url) {
      console.error('Failed to build URL for year:', year, 'month:', month)
      return
    }

    // Save current scroll position before navigation
    // The scrollable element is #mainContent, not window
    const scrollableElement = document.getElementById('mainContent') || window
    const scrollY = scrollableElement === window ? window.scrollY : scrollableElement.scrollTop
    
    // Make the request with Turbo Stream accept header
    fetch(url, { 
      headers: { 
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.text()
      })
      .then(html => {
        // IMPORTANT: Render Turbo Streams and immediately prevent scroll
        const scrollableElement = document.getElementById('mainContent') || window
        const isWindow = scrollableElement === window
        const savedPosition = scrollY
        
        // Lock scroll before rendering
        if (!isWindow) {
          scrollableElement.scrollTop = savedPosition
        }
        
        // Render the Turbo Stream updates
        Turbo.renderStreamMessage(html)
        
        // Immediately lock scroll again after rendering starts
        if (!isWindow) {
          scrollableElement.scrollTop = savedPosition
        } else {
          window.scrollTo(0, savedPosition)
        }
        
        // Update browser URL without full page reload
        if (url.includes('?')) {
          const urlObj = new URL(url, window.location.origin)
          window.history.pushState({ turbo: true }, '', urlObj.pathname + urlObj.search)
        } else {
          window.history.pushState({ turbo: true }, '', url)
        }
        
        // Dispatch custom event to notify other controllers of month change
        window.dispatchEvent(new CustomEvent('month:changed', { 
          detail: { year, month, url } 
        }))
        
        // Close the picker after navigation
        this.closePicker()
        
        // Restore scroll position after Turbo Stream rendering completes
        this.restoreScrollAfterStream(scrollY)
      })
      .catch(err => {
        console.error('Navigation error:', err)
        // Fallback: allow default navigation if Turbo Stream fails
        window.location.href = url
      })
  }

  buildUrl(year, month, day = null) {
    const pattern = this.urlPatternValue
    const urlType = this.urlTypeValue || 'path'
    
    let url = pattern.replace(':year', year).replace(':month', month)
    
    // For week view, replace :day placeholder
    if (urlType === 'week' && day !== null) {
      url = url.replace(':day', day)
    }
    
    // Ensure URL starts with / for proper parsing
    if (!url.startsWith('/')) {
      url = '/' + url
    }
    
    // For calendar paths, set appropriate view parameter
    if (urlType === 'path' && url.includes('/calendar/')) {
      // Parse and reconstruct URL with view=month parameter
      const urlObj = new URL(url, window.location.origin)
      urlObj.searchParams.set('view', 'month')
      // Return the pathname + search, without origin
      return urlObj.pathname + urlObj.search
    } else if (urlType === 'week' && url.includes('/calendar/')) {
      // Ensure view=week is set for week navigation
      const urlObj = new URL(url, window.location.origin)
      urlObj.searchParams.set('view', 'week')
      return urlObj.pathname + urlObj.search
    }
    
    return url
  }

  navigateToWeek(year, month, day) {
    // Build URL from pattern
    let url = this.buildUrl(year, month, day)
    
    if (!url) {
      console.error('Failed to build URL for week:', year, month, day)
      return
    }

    // Save current scroll position before navigation
    // The scrollable element is #mainContent, not window
    const scrollableElement = document.getElementById('mainContent') || window
    const scrollY = scrollableElement === window ? window.scrollY : scrollableElement.scrollTop
    
    // Make the request with Turbo Stream accept header
    fetch(url, { 
      headers: { 
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.text()
      })
      .then(html => {
        // IMPORTANT: Render Turbo Streams and immediately prevent scroll
        const scrollableElement = document.getElementById('mainContent') || window
        const isWindow = scrollableElement === window
        const savedPosition = scrollY
        
        // Lock scroll before rendering
        if (!isWindow) {
          scrollableElement.scrollTop = savedPosition
        }
        
        // Render the Turbo Stream updates
        Turbo.renderStreamMessage(html)
        
        // Immediately lock scroll again after rendering starts
        if (!isWindow) {
          scrollableElement.scrollTop = savedPosition
        } else {
          window.scrollTo(0, savedPosition)
        }
        
        // Close the picker after navigation
        this.closePicker()
        
        // Restore scroll position after Turbo Stream rendering completes
        this.restoreScrollAfterStream(scrollY)
      })
      .catch(err => {
        console.error('Navigation error:', err)
        // Fallback: allow default navigation if Turbo Stream fails
        window.location.href = url
      })
  }

  navigate(event) {
    event.preventDefault()
    event.stopPropagation()
    const link = event.currentTarget
    const url = new URL(link.href, window.location.origin)
    
    // Save current scroll position before navigation
    // The scrollable element is #mainContent, not window
    const scrollableElement = document.getElementById('mainContent') || window
    const scrollY = scrollableElement === window ? window.scrollY : scrollableElement.scrollTop
    
    // Make the request with Turbo Stream accept header
    fetch(url, { 
      headers: { 
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.text()
      })
      .then(html => {
        // IMPORTANT: Render Turbo Streams and immediately prevent scroll
        // We intercept the rendering to block any scroll that might occur
        const scrollableElement = document.getElementById('mainContent') || window
        const isWindow = scrollableElement === window
        const savedPosition = scrollY
        
        // Lock scroll before rendering
        if (!isWindow) {
          scrollableElement.scrollTop = savedPosition
        }
        
        // Render the Turbo Stream updates
        Turbo.renderStreamMessage(html)
        
        // Immediately lock scroll again after rendering starts
        if (!isWindow) {
          scrollableElement.scrollTop = savedPosition
        } else {
          window.scrollTo(0, savedPosition)
        }
        
        // Restore scroll position after Turbo Stream rendering completes
        this.restoreScrollAfterStream(scrollY)
      })
      .catch(err => {
        console.error('Navigation error:', err)
        // Fallback: allow default navigation if Turbo Stream fails
        window.location.href = url.toString()
      })
  }

  restoreScrollAfterStream(scrollY) {
    // Strategy: Aggressively prevent scrolling during Turbo Stream updates
    // The browser may try to scroll to replaced elements, so we block all scroll changes
    // until our restoration happens
    
    const scrollableElement = document.getElementById('mainContent') || window
    const isWindow = scrollableElement === window
    const savedScrollPosition = scrollY
    
    // Immediately lock scroll position before any updates happen
    if (isWindow) {
      window.scrollTo(0, savedScrollPosition)
    } else {
      scrollableElement.scrollTop = savedScrollPosition
    }
    
    // Prevent scroll restoration by browser
    const originalScrollRestoration = 'scrollRestoration' in window.history 
      ? window.history.scrollRestoration 
      : null
    if (originalScrollRestoration) {
      window.history.scrollRestoration = 'manual'
    }
    
    let scrollBlocked = true
    let restorationComplete = false
    
    // Actively block scroll changes during update
    const blockScroll = (e) => {
      if (scrollBlocked && !restorationComplete) {
        if (isWindow) {
          window.scrollTo(0, savedScrollPosition)
        } else {
          scrollableElement.scrollTop = savedScrollPosition
        }
        e.preventDefault && e.preventDefault()
        return false
      }
    }
    
    // Block scroll events
    if (isWindow) {
      window.addEventListener('scroll', blockScroll, { passive: false, capture: true })
    } else {
      scrollableElement.addEventListener('scroll', blockScroll, { passive: false, capture: true })
    }
    
    // Force scroll position continuously during updates (every frame)
    let forceScrollId = null
    const forceScrollPosition = () => {
      if (scrollBlocked && !restorationComplete) {
        if (isWindow) {
          const currentScroll = window.scrollY
          if (Math.abs(currentScroll - savedScrollPosition) > 1) {
            window.scrollTo(0, savedScrollPosition)
          }
        } else {
          const currentScroll = scrollableElement.scrollTop
          if (Math.abs(currentScroll - savedScrollPosition) > 1) {
            scrollableElement.scrollTop = savedScrollPosition
          }
        }
        forceScrollId = requestAnimationFrame(forceScrollPosition)
      }
    }
    forceScrollPosition()
    
    const restoreScroll = () => {
      if (restorationComplete) return
      restorationComplete = true
      scrollBlocked = false
      
      // Cancel the continuous scroll forcing
      if (forceScrollId !== null) {
        cancelAnimationFrame(forceScrollId)
        forceScrollId = null
      }
      
      // Remove scroll blocker
      if (isWindow) {
        window.removeEventListener('scroll', blockScroll, { capture: true })
      } else {
        scrollableElement.removeEventListener('scroll', blockScroll, { capture: true })
      }
      
      // Restore scroll position after a brief delay
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          if (isWindow) {
            window.scrollTo(0, savedScrollPosition)
          } else {
            scrollableElement.scrollTop = savedScrollPosition
          }
          
          if (originalScrollRestoration) {
            window.history.scrollRestoration = originalScrollRestoration
          }
        })
      })
    }
    
    // Approach 1: Listen for turbo:after-stream-render event
    const streamRenderHandler = () => {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          setTimeout(() => {
            restoreScroll()
          }, 150)
        })
      })
    }
    document.addEventListener('turbo:after-stream-render', streamRenderHandler, { once: true })
    
    // Approach 2: Watch for DOM mutations to complete
    const frameId = this.turboFrameValue || 'calendar_content'
    const turboFrame = document.getElementById(frameId) || document.querySelector(`turbo-frame#${frameId}`)
    if (turboFrame) {
      let mutationTimeout
      let mutationCount = 0
      
      const observer = new MutationObserver(() => {
        mutationCount++
        clearTimeout(mutationTimeout)
        mutationTimeout = setTimeout(() => {
          // Wait for mutations to settle
          if (mutationCount > 0) {
            restoreScroll()
            observer.disconnect()
          }
        }, 200)
      })
      
      observer.observe(turboFrame, {
        childList: true,
        subtree: true,
        attributes: true
      })
      
      // Also observe scrollable container
      if (!isWindow) {
        observer.observe(scrollableElement, {
          childList: true,
          subtree: true
        })
      }
      
      // Cleanup after timeout
      setTimeout(() => {
        observer.disconnect()
        restoreScroll()
      }, 2000)
    }
    
    // Approach 3: Fallback - always restore after reasonable delay
    setTimeout(() => {
      restoreScroll()
    }, 800)
  }
}

