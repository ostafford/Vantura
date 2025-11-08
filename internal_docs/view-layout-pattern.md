# View Layout Pattern

**Last Updated:** 2025-01-XX  
**Status:** Active Standard

## Overview

This document defines the standard page layout structure used across all views in the Vantura application. This pattern ensures consistency, accessibility, maintainability, and proper Hotwire (Turbo + Stimulus) integration.

## Standard Page Structure

### Required Components

Every page view must follow this structure:

```erb
<% content_for :title, "Page Title - Vantura" %>

<main id="page-container" aria-label="Page description">
  <!-- Page Header -->
  <%= render 'shared/page_header_simple', title: "Page Title", subtitle: "Page subtitle" %>

  <%= content_wrapper class: "py-6" do %>
    <!-- Page Sections -->
  <% end %>
</main>
```

### Component Breakdown

#### 1. Page Title (`content_for :title`)

**Purpose:** Sets the browser tab title consistently across all pages.

**Format:**
```erb
<% content_for :title, "Page Name - Vantura" %>
```

**Examples:**
- `"Dashboard - Vantura"`
- `"Settings - Vantura"`
- `"#{@project.name} - Projects - Vantura"`

**Rules:**
- Always include " - Vantura" suffix
- Use dynamic content when appropriate (e.g., project name)
- Keep titles concise and descriptive

#### 2. Root Element (`<main>`)

**Purpose:** Semantic HTML element that identifies the main content area.

**Required Attributes:**
- `id="[page-name]-container"` - Follows ID naming convention: `[context]-[element]-[purpose]`
- `aria-label="[description]"` - Screen reader description

**Optional Attributes:**
- `data-controller="[controller-name]"` - If page needs Stimulus controller
- `data-[controller]-[value]-value="[value]"` - For Stimulus values

**Examples:**
```erb
<main id="dashboard-page-container" aria-label="Dashboard page">
<main id="settings-page-container" aria-label="Settings page">
<main data-controller="filter" id="transactions-page-container" aria-label="Transactions page">
```

**Why `<main>` not `<div>`:**
- Semantic HTML improves accessibility
- Screen readers can identify main content
- Better SEO
- HTML5 best practice

#### 3. Page Header (`page_header_simple` partial)

**Purpose:** Consistent header styling across all pages.

**Usage:**
```erb
<%= render 'shared/page_header_simple', title: "Page Title", subtitle: "Page subtitle" %>
```

**Options:**
- `title:` (required) - Main page heading
- `subtitle:` (optional) - Descriptive subtitle
- `hide_quick_actions: true` (optional) - Hide quick actions button

**Examples:**
```erb
<%= render 'shared/page_header_simple', title: "Dashboard", subtitle: "Your cash flow projection tool" %>
<%= render 'shared/page_header_simple', title: @project.name, subtitle: "View project details", hide_quick_actions: true %>
```

**Why This Partial:**
- Centralizes header styling
- Ensures consistent appearance
- Includes quick actions by default
- Easy to update globally

#### 4. Content Wrapper (`content_wrapper` helper)

**Purpose:** Provides consistent responsive padding and max-width.

**Usage:**
```erb
<%= content_wrapper class: "py-6" do %>
  <!-- Content here -->
<% end %>
```

**Spacing Options:**
- `class: "py-6"` - Standard vertical padding (most common)
- `class: "py-4"` - Reduced vertical padding
- `class: "py-8"` - Increased vertical padding

**What It Provides:**
- Responsive padding: `px-4 sm:px-6 lg:px-8 xl:px-12 2xl:px-16`
- Max width: `max-w-[1920px]`
- Centered: `mx-auto`

**Why Not Manual Classes:**
- Centralizes responsive breakpoints
- Ensures consistency across pages
- Easy to update globally
- Prevents inconsistent spacing

**❌ Don't Do This:**
```erb
<div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Content -->
</div>
```

**✅ Do This:**
```erb
<%= content_wrapper class: "py-6" do %>
  <!-- Content -->
<% end %>
```

#### 5. Sections (`<section>` elements)

**Purpose:** Semantic HTML for organizing page content.

**Structure:**
```erb
<section id="section-name-section" class="mb-6" aria-label="Section description">
  <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Section Title</h2>
  <!-- Section content -->
</section>
```

**ID Naming:**
- Format: `id="[context]-[purpose]-section"`
- Examples:
  - `id="financial-insights-section"`
  - `id="connected-accounts-section"`
  - `id="bank-integrations-section"`

**Required Attributes:**
- `id` - Following naming convention
- `aria-label` - Screen reader description

**Common Classes:**
- `mb-6` - Standard margin bottom
- `bento-grid` - For grid layouts
- `mt-6` - Top margin when needed

## Complete Examples

### Example 1: Simple Page (Dashboard)

```erb
<% content_for :title, "Dashboard - Vantura" %>

<main id="dashboard-page-container" aria-label="Dashboard page">
  <%= render 'shared/page_header_simple', title: "Dashboard", subtitle: "Your cash flow projection tool" %>

  <%= content_wrapper class: "py-6" do %>
    <!-- Key Insights Section -->
    <section id="financial-insights-section" class="mb-6" aria-label="Financial insights">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Financial Insights</h2>
          <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">Actionable recommendations</p>
        </div>
      </div>
      <!-- Insights content -->
    </section>

    <!-- Statistics Section -->
    <section id="statistics-section" class="bento-grid mb-6" aria-label="Financial statistics">
      <!-- Statistics content -->
    </section>
  <% end %>
</main>
```

### Example 2: Page with Stimulus Controller (Transactions)

```erb
<% content_for :title, "All Transactions - Vantura" %>

<main data-controller="filter recurring-modal" 
      data-recurring-modal-target="content"
      id="transactions-page-container" 
      aria-label="Transactions page">
  <%= render 'shared/page_header_simple', title: "Your Transactions", subtitle: "View and manage all your transactions" %>

  <%= content_wrapper class: "py-6" do %>
    <%= turbo_frame_tag "transactions_content" do %>
      <!-- Transaction content -->
    <% end %>
  <% end %>
</main>
```

### Example 3: Page with Breadcrumb (Project Show)

```erb
<% content_for :title, "#{@project.name} - Projects - Vantura" %>

<main id="project-show-container" aria-label="Project details page">
  <!-- Breadcrumb Navigation -->
  <nav class="bg-gradient-to-r from-cream-100 to-white dark:from-primary-900 dark:to-primary-950 border-b border-primary-700/20 dark:border-primary-900/30" aria-label="Breadcrumb">
    <%= content_wrapper class: "py-2" do %>
      <div class="flex items-center gap-2">
        <%= link_to projects_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-primary-700 dark:hover:text-primary-400 font-medium transition-colors" do %>
          Projects
        <% end %>
        <span class="text-sm text-gray-400 dark:text-gray-500" aria-hidden="true">/</span>
        <span class="text-sm text-gray-900 dark:text-white font-medium"><%= @project.name %></span>
      </div>
    <% end %>
  </nav>

  <!-- Page Header -->
  <%= render 'shared/page_header_simple', title: @project.name, subtitle: "View project details and expenses", hide_quick_actions: true %>

  <%= content_wrapper class: "py-6" do %>
    <!-- Project content -->
  <% end %>
</main>
```

## Common Patterns

### Pattern 1: Conditional Content

```erb
<%= content_wrapper class: "py-6" do %>
  <% if @account %>
    <!-- Content when account exists -->
  <% else %>
    <!-- Content when no account -->
  <% end %>
<% end %>
```

### Pattern 2: Multiple Sections

```erb
<%= content_wrapper class: "py-6" do %>
  <!-- Section 1 -->
  <section id="section-one-section" class="mb-6" aria-label="First section">
    <!-- Content -->
  </section>

  <!-- Section 2 -->
  <section id="section-two-section" class="mb-6" aria-label="Second section">
    <!-- Content -->
  </section>
<% end %>
```

### Pattern 3: Turbo Frames

```erb
<%= content_wrapper class: "py-6" do %>
  <%= turbo_frame_tag "content_frame" do %>
    <!-- Turbo Frame content -->
  <% end %>
<% end %>
```

## Migration Guide

### Converting Old Pages

**Before (Incorrect):**
```erb
<% content_for :title, "Settings - Vantura" %>

<div id="settings-page-container">
  <%= render 'shared/page_header_simple', title: "Settings" %>
  
  <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Content -->
  </div>
</div>
```

**After (Correct):**
```erb
<% content_for :title, "Settings - Vantura" %>

<main id="settings-page-container" aria-label="Settings page">
  <%= render 'shared/page_header_simple', title: "Settings", subtitle: "Manage your account and integrations" %>

  <%= content_wrapper class: "py-6" do %>
    <!-- Content -->
  <% end %>
</main>
```

**Changes:**
1. Replace `<div>` with `<main>`
2. Add `aria-label` to `<main>`
3. Replace manual classes with `content_wrapper` helper
4. Add subtitle to page header

## Benefits

### 1. Consistency
- All pages follow the same structure
- Predictable codebase
- Easier onboarding for new developers

### 2. Accessibility
- Semantic HTML (`<main>`, `<section>`)
- ARIA labels for screen readers
- Proper heading hierarchy

### 3. Maintainability
- Centralized styling via helpers
- Easy to update globally
- Reduces code duplication

### 4. Hotwire Compatibility
- Proper structure ensures Stimulus controllers connect
- Turbo Frames work correctly
- Turbo Streams update properly

### 5. Responsive Design
- Consistent breakpoints via `content_wrapper`
- Desktop-first approach
- Mobile-friendly by default

## Related Documentation

- `.cursor/rules/development/rails/views.mdc` - View rules and structure
- `.cursor/rules/conventions/ID_naming_strategy/` - ID naming conventions
- `.cursor/rules/conventions/code_style/ERB_style.mdc` - ERB style guide
- `app/helpers/application_helper.rb` - `content_wrapper` helper implementation
- `app/views/shared/_page_header_simple.html.erb` - Page header partial

## Checklist for New Pages

When creating a new page, ensure:

- [ ] Uses `<main>` tag (not `<div>`)
- [ ] Has `id="[page-name]-container"` following naming convention
- [ ] Has `aria-label` attribute
- [ ] Uses `content_for :title` with " - Vantura" suffix
- [ ] Uses `render 'shared/page_header_simple'` for header
- [ ] Uses `content_wrapper` helper (not manual classes)
- [ ] Sections use `<section>` with proper IDs and `aria-label`
- [ ] Follows semantic HTML structure
- [ ] Stimulus controllers properly connected (if needed)
- [ ] Turbo Frames properly structured (if used)

## Questions or Issues?

If you encounter issues with this pattern or have questions:
1. Check existing pages (dashboard, transactions, projects) for examples
2. Review this document for clarification
3. Consult `.cursor/rules/development/rails/views.mdc` for additional guidance

