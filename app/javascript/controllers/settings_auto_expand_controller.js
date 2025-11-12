import { Controller } from "@hotwired/stimulus"

/**
 * Settings Auto Expand Controller
 * 
 * Automatically expands account sections when navigating from savings goal links.
 * Checks for the `expand_goal` query parameter and expands the first account section.
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  connect() {
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('expand_goal') === 'true') {
      // Wait a tick to ensure all controllers (especially collapsible) are connected
      requestAnimationFrame(() => {
        this.expandFirstAccountSection();
      });
    }
  }

  expandFirstAccountSection() {
    // Find the first account collapsible section
    const firstAccountItem = this.element.querySelector('[data-controller*="collapsible"]');
    if (!firstAccountItem) return;

    const content = firstAccountItem.querySelector('[data-collapsible-target="content"]');
    const toggleButton = firstAccountItem.querySelector('[data-collapsible-target="toggle"]');
    const icon = firstAccountItem.querySelector('[data-collapsible-target="icon"]');

    // Only expand if currently collapsed
    if (content && content.classList.contains('hidden')) {
      // Get the collapsible controller instance
      const application = this.application;
      const collapsibleController = application.getControllerForElementAndIdentifier(
        firstAccountItem,
        'collapsible'
      );

      if (collapsibleController) {
        // Use the controller's toggle method if it's not already expanded
        if (!collapsibleController.isExpanded) {
          collapsibleController.toggle();
          
          // Scroll to the expanded section for better UX
          setTimeout(() => {
            firstAccountItem.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
          }, 100);
        }
      } else {
        // Fallback: directly manipulate DOM if controller not available
        content.classList.remove('hidden');
        if (icon) icon.classList.add('rotate-180');
        if (toggleButton) toggleButton.setAttribute('aria-expanded', 'true');
        
        setTimeout(() => {
          firstAccountItem.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }, 50);
      }
    }
  }
}

