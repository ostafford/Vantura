/**
 * Responsive breakpoint hook
 * Returns breakpoint state for mobile, tablet, and desktop
 */

import { useState, useEffect } from 'react'

export interface ResponsiveState {
  isMobile: boolean
  isTablet: boolean
  isDesktop: boolean
}

const breakpoints = {
  mobile: 768,
  tablet: 1024
}

/**
 * Hook that returns responsive breakpoint state
 * - Mobile: < 768px
 * - Tablet: 768px - 1023px
 * - Desktop: ≥ 1024px
 */
export function useResponsive(): ResponsiveState {
  const [windowWidth, setWindowWidth] = useState(typeof window !== 'undefined' ? window.innerWidth : 1024)

  useEffect(() => {
    const handleResize = () => {
      setWindowWidth(window.innerWidth)
    }

    // Debounce resize events
    let timeoutId: NodeJS.Timeout
    const debouncedResize = () => {
      clearTimeout(timeoutId)
      timeoutId = setTimeout(handleResize, 150)
    }

    window.addEventListener('resize', debouncedResize)
    // Call once to set initial state
    handleResize()

    return () => {
      window.removeEventListener('resize', debouncedResize)
      clearTimeout(timeoutId)
    }
  }, [])

  return {
    isMobile: windowWidth < breakpoints.mobile,
    isTablet: windowWidth >= breakpoints.mobile && windowWidth < breakpoints.tablet,
    isDesktop: windowWidth >= breakpoints.tablet
  }
}

