// Prime Youth Mobile UI System - Theme Management

class ThemeManager {
    constructor() {
        this.currentTheme = this.getStoredTheme() || 'light';
        this.themeToggle = document.getElementById('themeToggle');
        
        this.init();
    }

    init() {
        // Set initial theme
        this.applyTheme(this.currentTheme);
        
        // Bind event listeners
        if (this.themeToggle) {
            this.themeToggle.addEventListener('click', () => this.toggleTheme());
        }

        // Listen for system theme changes
        if (window.matchMedia) {
            window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
                if (!localStorage.getItem('prime-youth-theme')) {
                    this.applyTheme(e.matches ? 'dark' : 'light');
                }
            });
        }

        // Handle tab navigation
        this.initTabNavigation();
    }

    getStoredTheme() {
        return localStorage.getItem('prime-youth-theme');
    }

    getPreferredTheme() {
        const storedTheme = this.getStoredTheme();
        if (storedTheme) {
            return storedTheme;
        }

        return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }

    setStoredTheme(theme) {
        localStorage.setItem('prime-youth-theme', theme);
    }

    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        this.currentTheme = theme;
        this.updateThemeToggle();
        
        // Dispatch custom event for other components
        window.dispatchEvent(new CustomEvent('themeChanged', { 
            detail: { theme } 
        }));
    }

    toggleTheme() {
        const newTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        this.setStoredTheme(newTheme);
        this.applyTheme(newTheme);
        
        // Add animation class for smooth transition
        document.body.classList.add('theme-transitioning');
        setTimeout(() => {
            document.body.classList.remove('theme-transitioning');
        }, 300);
    }

    updateThemeToggle() {
        if (this.themeToggle) {
            const icon = this.themeToggle.querySelector('.theme-icon');
            if (icon) {
                icon.innerHTML = this.currentTheme === 'light' ? '🌙' : '☀️';
            }
            
            this.themeToggle.setAttribute('aria-label', 
                `Switch to ${this.currentTheme === 'light' ? 'dark' : 'light'} mode`
            );
        }
    }

    initTabNavigation() {
        const navTabs = document.querySelectorAll('.nav-tab');
        const tabContents = document.querySelectorAll('.tab-content');

        navTabs.forEach(tab => {
            tab.addEventListener('click', (e) => {
                e.preventDefault();
                const targetTab = tab.getAttribute('data-tab');
                
                // Update active states
                navTabs.forEach(t => t.classList.remove('active'));
                tabContents.forEach(content => content.classList.remove('active'));
                
                tab.classList.add('active');
                const targetContent = document.getElementById(targetTab);
                if (targetContent) {
                    targetContent.classList.add('active');
                    
                    // Trigger animations for newly visible content
                    this.triggerContentAnimations(targetContent);
                }
            });
        });
    }

    triggerContentAnimations(container) {
        // Animate cards and components when tab becomes visible
        const animatedElements = container.querySelectorAll('.card, .btn, .form-group');
        animatedElements.forEach((element, index) => {
            element.style.setProperty('--delay', index);
            element.classList.add('stagger-in');
            
            // Remove animation class after animation completes
            setTimeout(() => {
                element.classList.remove('stagger-in');
            }, 600 + (index * 100));
        });
    }
}

// Color scheme utilities
class ColorSchemeUtils {
    static getContrastRatio(color1, color2) {
        // Simplified contrast ratio calculation
        const l1 = this.getLuminance(color1);
        const l2 = this.getLuminance(color2);
        
        const lighter = Math.max(l1, l2);
        const darker = Math.min(l1, l2);
        
        return (lighter + 0.05) / (darker + 0.05);
    }

    static getLuminance(color) {
        // Simplified luminance calculation
        // This is a basic implementation - in production, you'd want a more robust solution
        const rgb = this.hexToRgb(color);
        if (!rgb) return 0;
        
        const rsRGB = rgb.r / 255;
        const gsRGB = rgb.g / 255;
        const bsRGB = rgb.b / 255;
        
        const r = rsRGB <= 0.03928 ? rsRGB / 12.92 : Math.pow((rsRGB + 0.055) / 1.055, 2.4);
        const g = gsRGB <= 0.03928 ? gsRGB / 12.92 : Math.pow((gsRGB + 0.055) / 1.055, 2.4);
        const b = bsRGB <= 0.03928 ? bsRGB / 12.92 : Math.pow((bsRGB + 0.055) / 1.055, 2.4);
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    static hexToRgb(hex) {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        return result ? {
            r: parseInt(result[1], 16),
            g: parseInt(result[2], 16),
            b: parseInt(result[3], 16)
        } : null;
    }

    static ensureAccessibleContrast() {
        // Check and adjust colors for accessibility
        const criticalElements = document.querySelectorAll('[data-critical-contrast]');
        
        criticalElements.forEach(element => {
            const bgColor = getComputedStyle(element).backgroundColor;
            const textColor = getComputedStyle(element).color;
            
            // Implementation would check contrast and adjust if needed
            // This is a placeholder for the concept
        });
    }
}

// Performance monitoring for theme transitions
class ThemePerformance {
    static measureTransition() {
        let startTime;
        let endTime;

        const observer = new MutationObserver((mutations) => {
            if (!startTime) {
                startTime = performance.now();
            }
        });

        observer.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ['data-theme']
        });

        // Stop observing after transition completes
        setTimeout(() => {
            observer.disconnect();
            endTime = performance.now();
            
            console.log(`Theme transition took ${endTime - startTime} milliseconds`);
            
            // Report to analytics if needed
            if (window.analytics && window.analytics.track) {
                window.analytics.track('Theme Transition Performance', {
                    duration: endTime - startTime,
                    theme: document.documentElement.getAttribute('data-theme')
                });
            }
        }, 500);
    }
}

// Initialize theme management when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.themeManager = new ThemeManager();
    
    // Monitor performance in development
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        window.addEventListener('themeChanged', ThemePerformance.measureTransition);
    }
});

// Handle system preference changes
if (window.matchMedia) {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    
    mediaQuery.addEventListener('change', (e) => {
        if (!localStorage.getItem('prime-youth-theme')) {
            window.themeManager?.applyTheme(e.matches ? 'dark' : 'light');
        }
    });
}

// Accessibility helpers
class AccessibilityHelpers {
    static init() {
        this.handleReducedMotion();
        this.handleHighContrast();
        this.setupFocusManagement();
    }

    static handleReducedMotion() {
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            document.documentElement.style.setProperty('--transition-fast', '0ms');
            document.documentElement.style.setProperty('--transition-normal', '0ms');
            document.documentElement.style.setProperty('--transition-slow', '0ms');
        }
    }

    static handleHighContrast() {
        if (window.matchMedia('(prefers-contrast: high)').matches) {
            document.documentElement.classList.add('high-contrast');
        }
    }

    static setupFocusManagement() {
        // Enhanced focus management for better keyboard navigation
        let focusedBeforeModal = null;

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                this.handleTabNavigation(e);
            }
            
            if (e.key === 'Escape') {
                this.handleEscapeKey(e);
            }
        });

        // Track focus for modal management
        document.addEventListener('focusin', (e) => {
            if (!e.target.closest('.modal')) {
                focusedBeforeModal = e.target;
            }
        });

        // Restore focus when modal closes
        window.addEventListener('modalClosed', () => {
            if (focusedBeforeModal) {
                focusedBeforeModal.focus();
                focusedBeforeModal = null;
            }
        });
    }

    static handleTabNavigation(e) {
        const modal = document.querySelector('.modal.active');
        if (modal) {
            this.trapFocusInModal(e, modal);
        }
    }

    static trapFocusInModal(e, modal) {
        const focusableElements = modal.querySelectorAll(
            'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        );
        
        const firstElement = focusableElements[0];
        const lastElement = focusableElements[focusableElements.length - 1];

        if (e.shiftKey && document.activeElement === firstElement) {
            e.preventDefault();
            lastElement.focus();
        } else if (!e.shiftKey && document.activeElement === lastElement) {
            e.preventDefault();
            firstElement.focus();
        }
    }

    static handleEscapeKey(e) {
        const modal = document.querySelector('.modal.active');
        if (modal) {
            e.preventDefault();
            const closeButton = modal.querySelector('.modal-close');
            if (closeButton) {
                closeButton.click();
            }
        }
    }
}

// Initialize accessibility helpers
document.addEventListener('DOMContentLoaded', () => {
    AccessibilityHelpers.init();
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ThemeManager, ColorSchemeUtils, AccessibilityHelpers };
}