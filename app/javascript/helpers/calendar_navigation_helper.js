import { visitFrame } from "helpers/frame_navigation_helper"

/**
 * Calendar Navigation Helper
 * 
 * Shared utilities for calendar date navigation and URL building.
 * Used by calendar_controller.js for date picker navigation.
 */

/**
 * Build calendar URL from date and view type
 * 
 * @param {Date} date - Date to navigate to
 * @param {string} view - View type ('week' or 'month')
 * @returns {string} Calendar URL path
 */
export function buildCalendarUrl(date, view) {
  const year = date.getFullYear()
  const month = date.getMonth() + 1 // JavaScript months are 0-indexed
  const day = date.getDate()
  
  if (view === 'week') {
    return `/calendar/${year}/${month}/${day}?view=week`
  } else {
    return `/calendar/${year}/${month}?view=month`
  }
}

/**
 * Navigate to specific calendar date using Turbo Frame
 * 
 * @param {Date} date - Date to navigate to
 * @param {string} view - View type ('week' or 'month')
 * @param {string} frameId - Turbo Frame ID (default: 'calendar_content')
 */
export async function navigateToCalendarDate(date, view, frameId = 'calendar_content') {
  const calendarPath = buildCalendarUrl(date, view)
  
  // Navigate using Turbo Frame
  const calendarFrame = document.getElementById(frameId)
  calendarFrame?.dispatchEvent(new CustomEvent("frame-navigation:remember-scroll"))
  await visitFrame(calendarPath, frameId)
}

