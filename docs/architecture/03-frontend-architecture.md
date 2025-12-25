# Frontend Architecture
## Hotwire (Turbo + Stimulus) Implementation

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Related:** [Backend Architecture](./02-backend-architecture.md)

---

## Table of Contents

1. [Hotwire Overview](#hotwire-overview)
2. [Turbo Implementation](#turbo-implementation)
3. [Stimulus Controllers](#stimulus-controllers)
4. [Component Structure](#component-structure)
5. [Styling with Tailwind CSS](#styling-with-tailwind-css)
6. [Flowbite Components](#flowbite-components)
7. [State Management](#state-management)
8. [Progressive Web App Features](#progressive-web-app-features)

---

## Hotwire Overview

### What is Hotwire?

Hotwire is a collection of frameworks that deliver HTML over the wire, providing a modern web experience without writing much JavaScript. It consists of:

- **Turbo:** Handles navigation, forms, and frames
- **Stimulus:** Adds JavaScript behavior to HTML

### Why Hotwire for This Project?

- **Server-rendered HTML:** Rails generates HTML, minimal JavaScript needed
- **Fast Development:** Leverage Rails views and partials
- **Progressive Enhancement:** Works without JavaScript, enhanced with it
- **Simple Mental Model:** Traditional web development with modern UX
- **Small Bundle Size:** Minimal JavaScript footprint

### Architecture Pattern

```
┌─────────────────────────────────────────────────────────┐
│              Rails Controller Action                    │
│              Renders HTML View                          │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ HTML Response
                        │
┌───────────────────────▼─────────────────────────────────┐
│                    Turbo Drive                          │
│         Intercepts navigation, updates page             │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ DOM Updates
                        │
┌───────────────────────┬─────────────────────────────────┐
│              Turbo Frames                               │
│         Partial page updates                            │
│                                                         │
│              Turbo Streams                              │
│         Real-time updates (future)                      │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ Interactive Elements
                        │
┌───────────────────────▼─────────────────────────────────┐
│              Stimulus Controllers                       │
│         JavaScript behavior                             │
└─────────────────────────────────────────────────────────┘
```

---

## Turbo Implementation

### Turbo Drive (Navigation)

Turbo Drive intercepts link clicks and form submissions, making navigation feel like a single-page app.

#### Layout with Turbo

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title>Up Bank Desktop</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <%= render 'shared/navbar' %>
    
    <main class="container mx-auto px-4 py-8">
      <%= render 'shared/flash_messages' %>
      <%= yield %>
    </main>
    
    <%= render 'shared/footer' %>
  </body>
</html>
```

#### Turbo Frames (Partial Updates)

Turbo Frames allow updating parts of a page without full reload.

**Example: Transaction List with Filters**

```erb
<!-- app/views/transactions/index.html.erb -->
<div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
  <!-- Filters Sidebar -->
  <div class="lg:col-span-1">
    <%= turbo_frame_tag "filters" do %>
      <%= render 'filters', categories: @categories %>
    <% end %>
  </div>

  <!-- Transaction List -->
  <div class="lg:col-span-3">
    <%= turbo_frame_tag "transactions" do %>
      <%= render 'transaction_list', transactions: @transactions %>
    <% end %>
  </div>
</div>
```

**Filter Partial with Turbo Frame**

```erb
<!-- app/views/transactions/_filters.html.erb -->
<%= form_with url: transactions_path, method: :get, 
    data: { turbo_frame: "transactions" } do |f| %>
  
  <div class="space-y-4">
    <div>
      <%= f.label :category_id, "Category", class: "block text-sm font-medium" %>
      <%= f.select :category_id, 
          options_from_collection_for_select(@categories, :id, :name, params[:category_id]),
          { include_blank: "All Categories" },
          { class: "form-select" } %>
    </div>

    <div>
      <%= f.label :start_date, "Start Date", class: "block text-sm font-medium" %>
      <%= f.date_field :start_date, value: params[:start_date], class: "form-input" %>
    </div>

    <div>
      <%= f.label :end_date, "End Date", class: "block text-sm font-medium" %>
      <%= f.date_field :end_date, value: params[:end_date], class: "form-input" %>
    </div>

    <%= f.submit "Filter", class: "btn-primary" %>
  </div>
<% end %>
```

**Transaction List Partial**

```erb
<!-- app/views/transactions/_transaction_list.html.erb -->
<%= turbo_frame_tag "transactions" do %>
  <div class="space-y-4">
    <% @transactions.each do |transaction| %>
      <%= render 'transaction_card', transaction: transaction %>
    <% end %>
  </div>

  <% if @transactions.respond_to?(:current_page) %>
    <div class="mt-6">
      <%= paginate @transactions %>
    </div>
  <% end %>
<% end %>
```

### Turbo Streams (Real-time Updates - Future)

Turbo Streams enable real-time updates via WebSocket or Server-Sent Events.

**Example: Budget Alert (Future Implementation)**

```ruby
# app/controllers/budgets_controller.rb
def create
  @budget = current_user.budgets.build(budget_params)
  
  if @budget.save
    respond_to do |format|
      format.html { redirect_to budgets_path }
      format.turbo_stream # Renders create.turbo_stream.erb
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

```erb
<!-- app/views/budgets/create.turbo_stream.erb -->
<%= turbo_stream.append "budgets", partial: "budget", locals: { budget: @budget } %>
<%= turbo_stream.update "budget_form", partial: "form", locals: { budget: Budget.new } %>
```

---

## Stimulus Controllers

Stimulus adds JavaScript behavior to HTML elements via data attributes.

### Transaction Search Controller

```javascript
// app/javascript/controllers/transaction_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "loading"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)
    
    this.loadingTarget.classList.remove("hidden")
    
    this.timeout = setTimeout(() => {
      this.performSearch()
    }, 300) // Debounce 300ms
  }

  async performSearch() {
    const query = this.inputTarget.value
    const url = `${this.urlValue}?q=${encodeURIComponent(query)}`

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      
      const html = await response.text()
      Turbo.renderStreamMessage(html)
    } catch (error) {
      console.error("Search error:", error)
    } finally {
      this.loadingTarget.classList.add("hidden")
    }
  }
}
```

**Usage in View:**

```erb
<div data-controller="transaction-search" 
     data-transaction-search-url-value="<%= search_transactions_path %>">
  
  <input type="text" 
         data-transaction-search-target="input"
         data-action="input->transaction-search#search"
         placeholder="Search transactions..."
         class="form-input">
  
  <div data-transaction-search-target="loading" class="hidden">
    Loading...
  </div>
  
  <div data-transaction-search-target="results">
    <!-- Results will be updated via Turbo Stream -->
  </div>
</div>
```

### Budget Calculator Controller

```javascript
// app/javascript/controllers/budget_calculator_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "spent", "remaining", "percentage", "progressBar"]
  static values = { 
    limit: Number,
    spent: Number 
  }

  connect() {
    this.updateDisplay()
  }

  updateDisplay() {
    const limit = this.limitValue
    const spent = this.spentValue
    const remaining = limit - spent
    const percentage = limit > 0 ? (spent / limit * 100) : 0

    this.amountTarget.textContent = this.formatCurrency(limit)
    this.spentTarget.textContent = this.formatCurrency(spent)
    this.remainingTarget.textContent = this.formatCurrency(remaining)
    this.percentageTarget.textContent = `${percentage.toFixed(1)}%`

    // Update progress bar
    const progressBar = this.progressBarTarget
    progressBar.style.width = `${Math.min(percentage, 100)}%`
    
    // Color coding
    if (percentage >= 100) {
      progressBar.classList.add("bg-red-500")
      progressBar.classList.remove("bg-yellow-500", "bg-green-500")
    } else if (percentage >= 80) {
      progressBar.classList.add("bg-yellow-500")
      progressBar.classList.remove("bg-red-500", "bg-green-500")
    } else {
      progressBar.classList.add("bg-green-500")
      progressBar.classList.remove("bg-red-500", "bg-yellow-500")
    }
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD'
    }).format(amount)
  }
}
```

**Usage in View:**

```erb
<div data-controller="budget-calculator"
     data-budget-calculator-limit-value="<%= budget.amount %>"
     data-budget-calculator-spent-value="<%= budget.spent_amount(current_user) %>">
  
  <div class="budget-card">
    <h3><%= budget.name %></h3>
    
    <div class="progress-bar-container">
      <div class="progress-bar" 
           data-budget-calculator-target="progressBar"></div>
    </div>
    
    <div class="budget-stats">
      <div>
        <span>Limit:</span>
        <span data-budget-calculator-target="amount"></span>
      </div>
      <div>
        <span>Spent:</span>
        <span data-budget-calculator-target="spent"></span>
      </div>
      <div>
        <span>Remaining:</span>
        <span data-budget-calculator-target="remaining"></span>
      </div>
      <div>
        <span>Percentage:</span>
        <span data-budget-calculator-target="percentage"></span>
      </div>
    </div>
  </div>
</div>
```

### Chart Controller (Chart.js Integration)

```javascript
// app/javascript/controllers/chart_controller.js
import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

export default class extends Controller {
  static values = {
    type: String,
    data: Object,
    options: Object
  }

  connect() {
    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data: this.dataValue,
      options: this.optionsValue || {}
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  update() {
    if (this.chart) {
      this.chart.data = this.dataValue
      this.chart.update()
    }
  }
}
```

**Usage in View:**

```erb
<canvas data-controller="chart"
        data-chart-type-value="line"
        data-chart-data-value="<%= @spending_chart_data.to_json %>"
        data-chart-options-value="<%= @chart_options.to_json %>">
</canvas>
```

---

## Component Structure

### View Partials Organization

```
app/views/
├── shared/
│   ├── _navbar.html.erb
│   ├── _flash_messages.html.erb
│   └── _footer.html.erb
├── dashboard/
│   └── index.html.erb
├── transactions/
│   ├── index.html.erb
│   ├── show.html.erb
│   ├── _transaction_card.html.erb
│   ├── _transaction_list.html.erb
│   └── _filters.html.erb
├── budgets/
│   ├── index.html.erb
│   ├── _budget_card.html.erb
│   └── _budget_form.html.erb
└── accounts/
    ├── index.html.erb
    ├── show.html.erb
    └── _account_card.html.erb
```

### Reusable Components

**Transaction Card Component**

```erb
<!-- app/views/transactions/_transaction_card.html.erb -->
<div class="transaction-card <%= transaction.debit? ? 'debit' : 'credit' %>">
  <div class="transaction-header">
    <div class="transaction-amount">
      <%= number_to_currency(transaction.amount_abs) %>
    </div>
    <div class="transaction-date">
      <%= transaction.settled_at.strftime("%d %b %Y") %>
    </div>
  </div>

  <div class="transaction-description">
    <%= transaction.description || transaction.raw_text %>
  </div>

  <div class="transaction-meta">
    <% if transaction.categories.any? %>
      <div class="transaction-categories">
        <% transaction.categories.each do |category| %>
          <span class="category-badge"><%= category.name %></span>
        <% end %>
      </div>
    <% end %>

    <% if transaction.tags.any? %>
      <div class="transaction-tags">
        <% transaction.tags.each do |tag| %>
          <span class="tag-badge"><%= tag.name %></span>
        <% end %>
      </div>
    <% end %>
  </div>

  <%= link_to transaction_path(transaction), 
      class: "transaction-link",
      data: { turbo_frame: "_top" } do %>
    View Details
  <% end %>
</div>
```

**Budget Card Component**

```erb
<!-- app/views/budgets/_budget_card.html.erb -->
<div class="budget-card" 
     data-controller="budget-calculator"
     data-budget-calculator-limit-value="<%= budget.amount %>"
     data-budget-calculator-spent-value="<%= budget.spent_amount(current_user) %>">
  
  <div class="budget-header">
    <h3><%= budget.name %></h3>
    <% if budget.category %>
      <span class="category-badge"><%= budget.category.name %></span>
    <% end %>
  </div>

  <div class="budget-progress">
    <div class="progress-bar-container">
      <div class="progress-bar" 
           data-budget-calculator-target="progressBar"></div>
    </div>
    <div class="progress-text" 
         data-budget-calculator-target="percentage"></div>
  </div>

  <div class="budget-stats">
    <div class="stat">
      <span class="stat-label">Limit</span>
      <span class="stat-value" data-budget-calculator-target="amount"></span>
    </div>
    <div class="stat">
      <span class="stat-label">Spent</span>
      <span class="stat-value" data-budget-calculator-target="spent"></span>
    </div>
    <div class="stat">
      <span class="stat-label">Remaining</span>
      <span class="stat-value" data-budget-calculator-target="remaining"></span>
    </div>
  </div>

  <% if budget.alert_threshold_reached?(current_user) %>
    <div class="budget-alert">
      ⚠️ Budget threshold reached!
    </div>
  <% end %>
</div>
```

---

## Styling with Tailwind CSS
```javascript
// app/javascript/controllers/theme_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Check for saved theme preference or default to system preference
    const savedTheme = localStorage.getItem('theme')
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    
    if (savedTheme === 'dark' || (!savedTheme && systemPrefersDark)) {
      this.enableDarkMode()
    } else {
      this.enableLightMode()
    }
  }

  toggle() {
    if (document.documentElement.classList.contains('dark')) {
      this.enableLightMode()
    } else {
      this.enableDarkMode()
    }
  }

  enableDarkMode() {
    document.documentElement.classList.add('dark')
    localStorage.setItem('theme', 'dark')
  }

  enableLightMode() {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('theme', 'light')
  }
}

// tailwind.config.js - ADD darkMode config
module.exports = {
  darkMode: 'class', // Enable class-based dark mode
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
        }
      }
    },
  },
  plugins: [
    require('flowbite/plugin')
  ],
}

```

```erb
<!-- app/views/shared/_navbar.html.erb -->
<button data-controller="theme" 
        data-action="click->theme#toggle"
        class="btn-icon">
  <svg class="w-6 h-6 hidden dark:block" fill="currentColor" viewBox="0 0 20 20">
    <!-- Sun icon for dark mode -->
    <path d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z"></path>
  </svg>
  <svg class="w-6 h-6 block dark:hidden" fill="currentColor" viewBox="0 0 20 20">
    <!-- Moon icon for light mode -->
    <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path>
  </svg>
</button>
```
### Tailwind Configuration

```javascript
// tailwind.config.js
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
        }
      }
    },
  },
  plugins: [
    require('flowbite/plugin')
  ],
}
```

### Utility Classes Usage

**Example: Transaction List Styling**

```erb
<div class="space-y-4">
  <% @transactions.each do |transaction| %>
    <div class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div class="flex justify-between items-start mb-4">
        <div>
          <h3 class="text-lg font-semibold text-gray-900">
            <%= transaction.description %>
          </h3>
          <p class="text-sm text-gray-500">
            <%= transaction.settled_at.strftime("%B %d, %Y") %>
          </p>
        </div>
        <div class="text-right">
          <p class="text-xl font-bold <%= transaction.debit? ? 'text-red-600' : 'text-green-600' %>">
            <%= number_to_currency(transaction.amount_abs) %>
          </p>
        </div>
      </div>

      <div class="flex flex-wrap gap-2">
        <% transaction.categories.each do |category| %>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
            <%= category.name %>
          </span>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

### Custom Component Classes

```css
/* app/assets/stylesheets/application.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  .btn-primary {
    @apply px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2;
  }

  .form-input {
    @apply block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm;
  }

  .transaction-card {
    @apply bg-white rounded-lg shadow-md p-6 transition-shadow hover:shadow-lg;
  }

  .transaction-card.debit .transaction-amount {
    @apply text-red-600;
  }

  .transaction-card.credit .transaction-amount {
    @apply text-green-600;
  }
}
```

---

## Flowbite Components

### Using Flowbite Modals

```erb
<!-- Budget Form Modal -->
<button data-modal-target="budget-modal" 
        data-modal-toggle="budget-modal"
        class="btn-primary">
  Create Budget
</button>

<div id="budget-modal" 
     tabindex="-1" 
     aria-hidden="true"
     class="hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)] max-h-full">
  <div class="relative p-4 w-full max-w-2xl max-h-full">
    <div class="relative bg-white rounded-lg shadow">
      <%= render 'budgets/form', budget: Budget.new %>
    </div>
  </div>
</div>
```

### Using Flowbite Dropdowns

```erb
<div class="relative">
  <button data-dropdown-toggle="account-dropdown"
          class="btn-primary">
    Select Account
  </button>
  
  <div id="account-dropdown" 
       class="z-10 hidden bg-white divide-y divide-gray-100 rounded-lg shadow w-44">
    <ul class="py-2 text-sm text-gray-700">
      <% current_user.accounts.each do |account| %>
        <li>
          <%= link_to account.display_name_or_type,
              account_path(account),
              class: "block px-4 py-2 hover:bg-gray-100" %>
        </li>
      <% end %>
    </ul>
  </div>
</div>
```

---

## State Management

### Server-Side State (Rails)

Primary state management happens server-side:

- **User Session:** Devise handles authentication state
- **Data State:** ActiveRecord models in database
- **View State:** Instance variables in controllers
- **Flash Messages:** Rails flash for temporary messages

### Client-Side State (Stimulus)

Minimal client-side state in Stimulus controllers:

```javascript
// Example: Filter state in Stimulus controller
export default class extends Controller {
  static values = { 
    category: String,
    startDate: String,
    endDate: String
  }

  // State stored in data attributes, synced with form
}
```

### No Global State Management Needed

- No Redux/Zustand required
- Server renders HTML with current state
- Turbo updates DOM efficiently
- Stimulus handles local component state

---

## Progressive Web App Features

### Web App Manifest

```json
{
  "name": "Vantura",
  "short_name": "Vantura",
  "description": "Up Bank budgeting and investment tracking",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0ea5e9",
  "orientation": "any",
  "scope": "/",
  "icons": [
    {
      "src": "/icons/icon-72x72.png",
      "sizes": "72x72",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-96x96.png",
      "sizes": "96x96",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-128x128.png",
      "sizes": "128x128",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-144x144.png",
      "sizes": "144x144",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-152x152.png",
      "sizes": "152x152",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-384x384.png",
      "sizes": "384x384",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
```

### Service Worker (Optional - Future)

```javascript
// app/javascript/service-worker.js
// REQUIRED for offline functionality

const CACHE_NAME = 'vantura-v1';
const OFFLINE_URL = '/offline.html';

// Assets to cache immediately
const ASSETS_TO_CACHE = [
  '/',
  '/dashboard',
  '/offline.html',
  '/assets/application.css',
  '/assets/application.js',
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png'
];

// Install event - cache critical assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('Caching assets');
      return cache.addAll(ASSETS_TO_CACHE);
    })
  );
  self.skipWaiting();
});

// Activate event - clean old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch event - cache-first strategy
self.addEventListener('fetch', (event) => {
  // Cache-first for assets, network-first for API
  if (event.request.url.includes('/api/') || event.request.url.includes('api.up.com.au')) {
    // Network-first for API calls
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          // Cache successful API responses
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
          return response;
        })
        .catch(() => {
          // Fall back to cached API response
          return caches.match(event.request);
        })
    );
  } else {
    // Cache-first for everything else
    event.respondWith(
      caches.match(event.request).then((response) => {
        if (response) {
          return response;
        }
        
        return fetch(event.request)
          .then((response) => {
            // Cache successful responses
            if (response.status === 200) {
              const responseClone = response.clone();
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(event.request, responseClone);
              });
            }
            return response;
          })
          .catch(() => {
            // Show offline page for navigation requests
            if (event.request.mode === 'navigate') {
              return caches.match(OFFLINE_URL);
            }
          });
      })
    );
  }
});
```

### Layout with PWA Meta Tags

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <!-- PWA Meta Tags -->
  <meta name="theme-color" content="#0ea5e9">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  
  <!-- Manifest -->
  <link rel="manifest" href="/manifest.json">
  
  <!-- Icons -->
  <link rel="icon" href="/icon-192.png">
  <link rel="apple-touch-icon" href="/icon-192.png">
</head>
```

---

**Document Version:** 1.0  
**Last Updated:** December 2025