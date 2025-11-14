/**
 * Frame Navigation Helper
 *
 * Provides utilities for loading Turbo Frames via Turbo Stream responses.
 * Falls back to Turbo.visit when Turbo Stream content is unavailable.
 */

const RESTORE_EVENT = "frame-navigation:restore-scroll"

/**
 * Visit a URL and prefer Turbo Stream updates for the target frame.
 *
 * @param {string} url - The target URL to fetch.
 * @param {string|undefined|null} frameId - Optional Turbo Frame ID for fallback navigation.
 * @returns {Promise<void>}
 */
export async function visitFrame(url, frameId) {
  const frame = frameId ? document.getElementById(frameId) : null

  try {
    const response = await fetch(url, {
      headers: {
        Accept: "text/vnd.turbo-stream.html, text/html",
        "X-Requested-With": "XMLHttpRequest"
      },
      credentials: "same-origin"
    })

    if (!response.ok) {
      throw new Error(`[frame-navigation] HTTP ${response.status}`)
    }

    const contentType = response.headers.get("content-type") || ""
    if (contentType.includes("text/vnd.turbo-stream.html")) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
      frame?.dispatchEvent(new CustomEvent(RESTORE_EVENT))
      return
    }
  } catch (error) {
    console.error("[frame-navigation] Turbo stream request failed", error)
  }

  if (frameId) {
    Turbo.visit(url, { frame: frameId })
    return
  }

  Turbo.visit(url)
}


