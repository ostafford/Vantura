# Stimulus Controllers Architecture

## Overview

This document describes the architecture decisions for Stimulus controllers in the Vantura application, including controller splitting, shared helpers, and coordination patterns.

## Controller Splitting Strategy

### Month Navigation Controller Split

**Original:** `month_nav_controller.js` (624 lines) - Violated 200-line rule

**Split into:**
1. `month_nav_controller.js` (~220 lines) - Month/year selection and navigation
2. `week_nav_controller.js` (~230 lines) - Week selection and navigation

### Rationale

Following Rails 8 and project standards (`.cursor/rules/conventions/code_style/stimulus_controller_style.mdc`), controllers must be under 200 lines. The original controller handled both month and week navigation, violating the single responsibility principle.

**Split Logic:**
- Month navigation: Year/month selection, month button states, month navigation
- Week navigation: Week year/month selection, week generation, week list rendering, week navigation

### Shared Logic Extraction

To maintain consistency and avoid duplication, shared logic was extracted to helper modules:

1. **`app/javascript/helpers/navigation_helper.js`**
   - `buildUrl()` function - URL building logic shared by both controllers
   - Ensures consistent URL generation across month and week navigation

2. **`app/javascript/helpers/scroll_helper.js`**
   - `restoreScrollAfterStream()` function - Scroll preservation during Turbo Stream updates
   - Prevents scroll jumps when navigating between months/weeks
   - Reusable across controllers needing scroll preservation

## Controller Coordination

### Custom Events

Controllers coordinate through custom events:

- `month:changed` - Dispatched by `month_nav_controller.js` when month changes
  - Detail: `{ year, month, url }`
  - Other controllers can listen for month changes

- `week:changed` - Dispatched by `week_nav_controller.js` when week changes
  - Detail: `{ year, month, day, url }`
  - Other controllers can listen for week changes

### Shared Values

Both controllers use the same Stimulus values for consistency:
- `urlPattern` - URL pattern with placeholders
- `urlType` - Type of URL ('path' or 'week')
- `turboFrame` - Turbo Frame ID for navigation

## Cross-Controller Access Patterns

### Acceptable Patterns

Per `.cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc` (lines 668-678), the following patterns are acceptable:

1. **`getElementById('main-content-container')`**
   - Shared layout element accessed by multiple controllers
   - Used by: `sidebar_controller.js`, `month_nav_controller.js`, `week_nav_controller.js`, `calendar_controller.js`
   - Rationale: Element is accessed outside controller scope and shared across controllers

2. **`getElementById('calendar_content')`**
   - Turbo Frame accessed by multiple controllers
   - Used by: `calendar_controller.js`, `month_nav_controller.js`, `week_nav_controller.js`
   - Rationale: Turbo Frame is accessed outside controller scope

3. **`querySelector('[data-controller~="autocomplete"]')`**
   - Accessing another controller's element
   - Used by: `transactions_nav_controller.js`
   - Rationale: Cross-controller coordination for syncing values

### Patterns to Avoid

- `querySelector` within controller scope - Use Stimulus targets instead
- `getElementById` for elements within controller scope - Use Stimulus targets instead

## Controller Structure

All controllers follow this structure (per `.cursor/rules/conventions/code_style/stimulus_controller_style.mdc`):

1. **Static Properties** (targets, classes, values)
2. **Lifecycle Methods** (connect, disconnect)
3. **Action Methods** (public methods called by data-action)
4. **Helper Methods** (private methods)

Example:

```javascript
export default class extends Controller {
  static targets = ["example"]
  static values = { example: String }
  
  connect() { /* ... */ }
  disconnect() { /* ... */ }
  
  actionMethod() { /* ... */ }
  
  private helperMethod() { /* ... */ }
}
```

## Helper Modules

### Navigation Helper

**Location:** `app/javascript/helpers/navigation_helper.js`

**Purpose:** Shared URL building logic

**Usage:**
```javascript
import { buildUrl } from "../helpers/navigation_helper.js"

const url = buildUrl(pattern, urlType, year, month, day)
```

**Parameters:**
- `pattern` - URL pattern with :year, :month, :day placeholders
- `urlType` - 'path' or 'week'
- `year` - Year value
- `month` - Month value (1-12)
- `day` - Optional day value (for week view)

### Scroll Helper

**Location:** `app/javascript/helpers/scroll_helper.js`

**Purpose:** Scroll preservation during Turbo Stream updates

**Usage:**
```javascript
import { restoreScrollAfterStream } from "../helpers/scroll_helper.js"

restoreScrollAfterStream(scrollY, frameId, containerId)
```

**Parameters:**
- `scrollY` - Saved scroll position to restore
- `frameId` - Optional Turbo Frame ID to watch for mutations
- `containerId` - Optional container ID (defaults to 'main-content-container')

## References

- `.cursor/rules/conventions/code_style/stimulus_controller_style.mdc`
- `.cursor/rules/development/hotwire/stimulus_controllers.mdc`
- `.cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc`
- `.cursor/rules/conventions/file_structure/file_naming.mdc`
- `.cursor/rules/conventions/file_structure/directory_rules.mdc`
