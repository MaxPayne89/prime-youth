/**
 * Component Inspector - Cross-reference functionality for Prime Youth Design System
 * Allows users to see which components are used where and navigate between
 * component library and app mockups
 */

class ComponentInspector {
    constructor() {
        this.isActive = false;
        this.componentMap = new Map();
        this.init();
    }

    init() {
        this.buildComponentMap();
        this.createInspectorUI();
        this.attachEventListeners();
    }

    /**
     * Build a map of components and their usage across the design system
     */
    buildComponentMap() {
        this.componentMap.set('btn', {
            name: 'Button',
            description: 'Primary interactive element for user actions',
            variants: ['primary', 'secondary', 'outline', 'ghost', 'icon'],
            usedIn: ['login-screen', 'home-screen', 'activities-screen', 'profile-screen', 'booking-screen'],
            componentLibraryId: 'buttons-section',
            cssClass: 'btn'
        });

        this.componentMap.set('card', {
            name: 'Card',
            description: 'Container for grouping related content',
            variants: ['default', 'activity', 'profile', 'action'],
            usedIn: ['home-screen', 'activities-screen', 'booking-screen'],
            componentLibraryId: 'cards-section',
            cssClass: 'card'
        });

        this.componentMap.set('form-input', {
            name: 'Form Input',
            description: 'Text input field for user data entry',
            variants: ['text', 'email', 'password', 'select', 'textarea'],
            usedIn: ['login-screen', 'booking-screen'],
            componentLibraryId: 'forms-section',
            cssClass: 'form-input'
        });

        this.componentMap.set('nav-item', {
            name: 'Navigation Item',
            description: 'Bottom navigation menu item',
            variants: ['active', 'inactive'],
            usedIn: ['home-screen', 'activities-screen', 'profile-screen'],
            componentLibraryId: 'navigation-section',
            cssClass: 'nav-item'
        });

        this.componentMap.set('activity-card-small', {
            name: 'Activity Card Small',
            description: 'Compact activity display for grids and lists',
            variants: ['default', 'featured'],
            usedIn: ['home-screen', 'activities-screen'],
            componentLibraryId: 'cards-section',
            cssClass: 'activity-card-small'
        });

        this.componentMap.set('quick-action', {
            name: 'Quick Action',
            description: 'Dashboard shortcut for common tasks',
            variants: ['default'],
            usedIn: ['home-screen'],
            componentLibraryId: 'cards-section',
            cssClass: 'quick-action'
        });

        this.componentMap.set('filter-chip', {
            name: 'Filter Chip',
            description: 'Selectable filter option',
            variants: ['active', 'inactive'],
            usedIn: ['activities-screen'],
            componentLibraryId: 'filters-section',
            cssClass: 'filter-chip'
        });

        this.componentMap.set('menu-item', {
            name: 'Menu Item',
            description: 'Profile menu navigation item',
            variants: ['default', 'danger'],
            usedIn: ['profile-screen'],
            componentLibraryId: 'navigation-section',
            cssClass: 'menu-item'
        });
    }

    /**
     * Create the inspector UI overlay
     */
    createInspectorUI() {
        // Inspector toggle button
        const inspectorToggle = document.createElement('button');
        inspectorToggle.id = 'inspector-toggle';
        inspectorToggle.className = 'inspector-toggle';
        inspectorToggle.innerHTML = '🔍';
        inspectorToggle.title = 'Toggle Component Inspector';
        
        // Inspector panel
        const inspectorPanel = document.createElement('div');
        inspectorPanel.id = 'inspector-panel';
        inspectorPanel.className = 'inspector-panel';
        inspectorPanel.innerHTML = `
            <div class="inspector-header">
                <h3>Component Inspector</h3>
                <button id="inspector-close" class="inspector-close">×</button>
            </div>
            <div class="inspector-content">
                <div class="inspector-placeholder">
                    <p>Click on any component to see details</p>
                    <div class="inspector-legend">
                        <div class="legend-item">
                            <div class="legend-color" style="background: rgba(0, 206, 209, 0.3);"></div>
                            <span>Buttons & Actions</span>
                        </div>
                        <div class="legend-item">
                            <div class="legend-color" style="background: rgba(255, 215, 0, 0.3);"></div>
                            <span>Cards & Containers</span>
                        </div>
                        <div class="legend-item">
                            <div class="legend-color" style="background: rgba(255, 20, 147, 0.3);"></div>
                            <span>Forms & Inputs</span>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Inspector styles
        const inspectorStyles = document.createElement('style');
        inspectorStyles.textContent = `
            .inspector-toggle {
                position: fixed;
                bottom: 20px;
                right: 20px;
                width: 60px;
                height: 60px;
                border-radius: 50%;
                background: var(--color-cyan);
                color: var(--color-white);
                border: none;
                font-size: 24px;
                cursor: pointer;
                box-shadow: var(--shadow-lg);
                z-index: 1000;
                transition: all 0.3s ease;
            }

            .inspector-toggle:hover {
                transform: scale(1.1);
                background: var(--color-cyan-dark);
            }

            .inspector-toggle.active {
                background: var(--color-magenta);
            }

            .inspector-panel {
                position: fixed;
                top: 50%;
                right: 20px;
                transform: translateY(-50%);
                width: 320px;
                max-height: 80vh;
                background: var(--color-white);
                border-radius: var(--radius-xl);
                box-shadow: var(--shadow-lg);
                border: 1px solid var(--color-gray-200);
                z-index: 1001;
                opacity: 0;
                visibility: hidden;
                transition: all 0.3s ease;
                overflow: hidden;
            }

            .inspector-panel.active {
                opacity: 1;
                visibility: visible;
            }

            .inspector-header {
                padding: var(--space-lg);
                border-bottom: 1px solid var(--color-gray-200);
                display: flex;
                justify-content: space-between;
                align-items: center;
                background: linear-gradient(135deg, var(--color-cyan), var(--color-cyan-dark));
                color: var(--color-white);
            }

            .inspector-header h3 {
                margin: 0;
                font-size: var(--font-size-lg);
            }

            .inspector-close {
                background: none;
                border: none;
                color: var(--color-white);
                font-size: var(--font-size-xl);
                cursor: pointer;
                padding: var(--space-xs);
                border-radius: var(--radius-sm);
                transition: background-color 0.2s ease;
            }

            .inspector-close:hover {
                background: rgba(255, 255, 255, 0.2);
            }

            .inspector-content {
                padding: var(--space-lg);
                max-height: calc(80vh - 80px);
                overflow-y: auto;
            }

            .inspector-placeholder {
                text-align: center;
                color: var(--color-gray-600);
            }

            .inspector-legend {
                margin-top: var(--space-lg);
                display: flex;
                flex-direction: column;
                gap: var(--space-sm);
            }

            .legend-item {
                display: flex;
                align-items: center;
                gap: var(--space-sm);
                font-size: var(--font-size-sm);
            }

            .legend-color {
                width: 16px;
                height: 16px;
                border-radius: var(--radius-sm);
                border: 1px solid var(--color-gray-300);
            }

            .component-info {
                animation: fadeIn 0.3s ease;
            }

            .component-name {
                font-size: var(--font-size-lg);
                font-weight: var(--font-weight-bold);
                color: var(--color-gray-800);
                margin-bottom: var(--space-sm);
            }

            .component-description {
                color: var(--color-gray-600);
                margin-bottom: var(--space-md);
                line-height: 1.5;
            }

            .component-variants {
                margin-bottom: var(--space-md);
            }

            .component-variants h4,
            .component-usage h4 {
                font-size: var(--font-size-sm);
                font-weight: var(--font-weight-medium);
                color: var(--color-gray-700);
                margin: 0 0 var(--space-sm) 0;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }

            .variant-list,
            .usage-list {
                display: flex;
                flex-wrap: wrap;
                gap: var(--space-xs);
            }

            .variant-tag,
            .usage-tag {
                background: var(--color-gray-100);
                color: var(--color-gray-700);
                padding: var(--space-xs) var(--space-sm);
                border-radius: var(--radius-sm);
                font-size: var(--font-size-xs);
            }

            .usage-tag {
                background: var(--color-cyan-light);
                color: var(--color-cyan-dark);
                cursor: pointer;
                transition: all 0.2s ease;
            }

            .usage-tag:hover {
                background: var(--color-cyan);
                color: var(--color-white);
            }

            .inspector-actions {
                margin-top: var(--space-lg);
                display: flex;
                gap: var(--space-sm);
            }

            .inspector-btn {
                flex: 1;
                padding: var(--space-sm) var(--space-md);
                border: 1px solid var(--color-cyan);
                background: var(--color-white);
                color: var(--color-cyan);
                border-radius: var(--radius-md);
                font-size: var(--font-size-sm);
                cursor: pointer;
                transition: all 0.2s ease;
            }

            .inspector-btn:hover {
                background: var(--color-cyan);
                color: var(--color-white);
            }

            .inspector-btn.primary {
                background: var(--color-cyan);
                color: var(--color-white);
            }

            .inspector-btn.primary:hover {
                background: var(--color-cyan-dark);
            }

            /* Component highlighting */
            .component-highlight {
                position: relative;
                cursor: pointer !important;
            }

            .component-highlight::before {
                content: '';
                position: absolute;
                top: -2px;
                left: -2px;
                right: -2px;
                bottom: -2px;
                border: 2px solid var(--color-cyan);
                border-radius: var(--radius-md);
                background: rgba(0, 206, 209, 0.1);
                pointer-events: none;
                z-index: 10;
            }

            .component-highlight.btn::before {
                background: rgba(0, 206, 209, 0.3);
            }

            .component-highlight.card::before {
                background: rgba(255, 215, 0, 0.3);
                border-color: var(--color-yellow);
            }

            .component-highlight.form-input::before {
                background: rgba(255, 20, 147, 0.3);
                border-color: var(--color-magenta);
            }

            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(10px); }
                to { opacity: 1; transform: translateY(0); }
            }

            @media (max-width: 768px) {
                .inspector-panel {
                    width: calc(100vw - 40px);
                    right: 20px;
                    left: 20px;
                }
            }
        `;

        document.head.appendChild(inspectorStyles);
        document.body.appendChild(inspectorToggle);
        document.body.appendChild(inspectorPanel);
    }

    /**
     * Attach event listeners for inspector functionality
     */
    attachEventListeners() {
        const toggle = document.getElementById('inspector-toggle');
        const panel = document.getElementById('inspector-panel');
        const close = document.getElementById('inspector-close');

        toggle.addEventListener('click', () => this.toggleInspector());
        close.addEventListener('click', () => this.closeInspector());

        // Close panel when clicking outside
        document.addEventListener('click', (e) => {
            if (this.isActive && !panel.contains(e.target) && !toggle.contains(e.target)) {
                this.closeInspector();
            }
        });

        // Handle component clicks
        document.addEventListener('click', (e) => {
            if (!this.isActive) return;

            const component = this.findComponent(e.target);
            if (component) {
                e.preventDefault();
                e.stopPropagation();
                this.showComponentInfo(component);
            }
        });
    }

    /**
     * Toggle inspector mode on/off
     */
    toggleInspector() {
        this.isActive = !this.isActive;
        const toggle = document.getElementById('inspector-toggle');
        const panel = document.getElementById('inspector-panel');

        if (this.isActive) {
            toggle.classList.add('active');
            panel.classList.add('active');
            this.highlightComponents();
            document.body.style.cursor = 'crosshair';
        } else {
            this.closeInspector();
        }
    }

    /**
     * Close inspector and reset state
     */
    closeInspector() {
        this.isActive = false;
        const toggle = document.getElementById('inspector-toggle');
        const panel = document.getElementById('inspector-panel');

        toggle.classList.remove('active');
        panel.classList.remove('active');
        this.removeHighlights();
        document.body.style.cursor = '';
    }

    /**
     * Highlight components that can be inspected
     */
    highlightComponents() {
        this.componentMap.forEach((info, className) => {
            const elements = document.querySelectorAll(`.${className}`);
            elements.forEach(el => {
                el.classList.add('component-highlight');
                el.dataset.componentType = className;
            });
        });
    }

    /**
     * Remove component highlights
     */
    removeHighlights() {
        const highlighted = document.querySelectorAll('.component-highlight');
        highlighted.forEach(el => {
            el.classList.remove('component-highlight');
            delete el.dataset.componentType;
        });
    }

    /**
     * Find the component type for a clicked element
     */
    findComponent(element) {
        let current = element;
        while (current && current !== document.body) {
            const componentType = current.dataset.componentType;
            if (componentType && this.componentMap.has(componentType)) {
                return {
                    element: current,
                    type: componentType,
                    info: this.componentMap.get(componentType)
                };
            }
            current = current.parentElement;
        }
        return null;
    }

    /**
     * Show component information in the inspector panel
     */
    showComponentInfo(component) {
        const content = document.querySelector('.inspector-content');
        const { type, info } = component;

        content.innerHTML = `
            <div class="component-info">
                <div class="component-name">${info.name}</div>
                <div class="component-description">${info.description}</div>
                
                <div class="component-variants">
                    <h4>Variants</h4>
                    <div class="variant-list">
                        ${info.variants.map(variant => 
                            `<span class="variant-tag">${variant}</span>`
                        ).join('')}
                    </div>
                </div>
                
                <div class="component-usage">
                    <h4>Used In</h4>
                    <div class="usage-list">
                        ${info.usedIn.map(screen => 
                            `<span class="usage-tag" onclick="componentInspector.navigateToScreen('${screen}')">${this.formatScreenName(screen)}</span>`
                        ).join('')}
                    </div>
                </div>
                
                <div class="inspector-actions">
                    <button class="inspector-btn" onclick="componentInspector.viewInLibrary('${info.componentLibraryId}')">
                        View in Library
                    </button>
                    <button class="inspector-btn primary" onclick="componentInspector.copyCode('${type}')">
                        Copy CSS
                    </button>
                </div>
            </div>
        `;
    }

    /**
     * Format screen names for display
     */
    formatScreenName(screenId) {
        return screenId
            .replace('-screen', '')
            .replace('-', ' ')
            .replace(/\b\w/g, l => l.toUpperCase());
    }

    /**
     * Navigate to a specific screen in app mockups
     */
    navigateToScreen(screenId) {
        if (window.location.pathname.includes('app-mockups.html')) {
            // We're already in app mockups, just switch screens
            const screenButton = document.querySelector(`[data-screen="${screenId.replace('-screen', '')}"]`);
            if (screenButton) {
                screenButton.click();
            }
        } else {
            // Navigate to app mockups with the specific screen
            window.location.href = `app-mockups.html#${screenId}`;
        }
    }

    /**
     * View component in the component library
     */
    viewInLibrary(componentId) {
        window.open(`components-demo.html#${componentId}`, '_blank');
    }

    /**
     * Copy component CSS to clipboard
     */
    copyCode(componentType) {
        const info = this.componentMap.get(componentType);
        const cssCode = `/* ${info.name} Component */
.${info.cssClass} {
    /* Add your styles here */
    /* Variants: ${info.variants.join(', ')} */
}`;

        navigator.clipboard.writeText(cssCode).then(() => {
            // Show feedback
            const button = event.target;
            const originalText = button.textContent;
            button.textContent = 'Copied!';
            setTimeout(() => {
                button.textContent = originalText;
            }, 2000);
        });
    }
}

// Initialize component inspector when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.componentInspector = new ComponentInspector();
});

// Export for global access
window.ComponentInspector = ComponentInspector;