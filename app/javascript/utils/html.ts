/**
 * Shared utility functions for HTML/DOM manipulation
 * Extracted to avoid duplication across controllers and helpers
 */

/**
 * Escapes HTML special characters to prevent XSS attacks
 * @param text - Text that may contain HTML special characters
 * @returns Escaped HTML-safe string
 */
export function escapeHtml(text: string): string {
  const map: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  }
  return text.replace(/[&<>"']/g, m => map[m])
}
