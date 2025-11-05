/**
 * Navigation Helper
 * 
 * Shared utilities for building navigation URLs across controllers.
 * Used by month_nav_controller.js and week_nav_controller.js.
 * 
 * @see docs/stimulus-controllers-architecture.md
 */

/**
 * Build a URL from a pattern, replacing placeholders with actual values
 * 
 * @param {string} pattern - URL pattern with :year, :month, :day placeholders
 * @param {string} urlType - Type of URL: 'path' or 'week'
 * @param {number} year - Year value
 * @param {number} month - Month value (1-12)
 * @param {number|null} day - Day value (optional, for week view)
 * @returns {string} Built URL path
 */
export function buildUrl(pattern, urlType, year, month, day = null) {
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
