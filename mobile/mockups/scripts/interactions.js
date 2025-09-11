// Prime Youth Mobile UI System - Interactive Components

class InteractionManager {
    constructor() {
        this.init();
    }

    init() {
        this.setupFormInteractions();
        this.setupModalInteractions();
        this.setupTouchFeedback();
        this.setupPullToRefresh();
        this.setupRippleEffects();
        this.setupValidation();
    }

    // Form interactions and validation
    setupFormInteractions() {
        const interactiveInputs = document.querySelectorAll('.interactive-input');
        
        interactiveInputs.forEach(input => {
            const formGroup = input.closest('.form-group');
            
            // Focus and blur effects
            input.addEventListener('focus', () => {
                formGroup?.classList.add('focused', 'interactive');
            });

            input.addEventListener('blur', () => {
                formGroup?.classList.remove('focused');
                this.validateField(input);
            });

            // Real-time validation
            input.addEventListener('input', () => {
                if (input.value.length > 0) {
                    formGroup?.classList.add('has-value');
                } else {
                    formGroup?.classList.remove('has-value');
                }
                
                // Debounced validation
                this.debounceValidation(input, 500);
            });

            // Enter key handling
            input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    this.handleEnterKey(input);
                }
            });
        });

        // Form submission handling
        const forms = document.querySelectorAll('form, .form-example');
        forms.forEach(form => {
            form.addEventListener('submit', (e) => {
                e.preventDefault();
                this.handleFormSubmission(form);
            });
        });
    }

    validateField(input) {
        const formGroup = input.closest('.form-group');
        const type = input.type;
        const value = input.value.trim();
        let isValid = true;
        let message = '';

        // Reset states
        formGroup?.classList.remove('error', 'success', 'validating');

        if (value === '') {
            return; // Don't validate empty fields on blur
        }

        // Add validating state
        formGroup?.classList.add('validating');

        // Simulate async validation
        setTimeout(() => {
            switch (type) {
                case 'email':
                    isValid = this.isValidEmail(value);
                    message = isValid ? 'Valid email format' : 'Please enter a valid email address';
                    break;
                
                case 'tel':
                    isValid = this.isValidPhone(value);
                    message = isValid ? 'Valid phone number' : 'Please enter a valid phone number';
                    break;
                
                case 'password':
                    isValid = this.isValidPassword(value);
                    message = isValid ? 'Strong password' : 'Password must be at least 8 characters';
                    break;
                
                default:
                    isValid = value.length >= 2;
                    message = isValid ? 'Looks good!' : 'Please enter a valid value';
            }

            formGroup?.classList.remove('validating');
            formGroup?.classList.add(isValid ? 'success' : 'error');

            // Update message
            const errorElement = formGroup?.querySelector('.form-error');
            const successElement = formGroup?.querySelector('.form-success');
            
            if (isValid && successElement) {
                successElement.textContent = message;
            } else if (!isValid && errorElement) {
                errorElement.textContent = message;
            }
        }, 300); // Simulate API delay
    }

    debounceValidation(input, delay) {
        clearTimeout(input.validationTimeout);
        input.validationTimeout = setTimeout(() => {
            this.validateField(input);
        }, delay);
    }

    isValidEmail(email) {
        const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return re.test(email);
    }

    isValidPhone(phone) {
        const re = /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/;
        return re.test(phone);
    }

    isValidPassword(password) {
        return password.length >= 8;
    }

    handleEnterKey(input) {
        const form = input.closest('form, .form-example');
        const inputs = Array.from(form.querySelectorAll('input, select, textarea'));
        const currentIndex = inputs.indexOf(input);
        const nextInput = inputs[currentIndex + 1];

        if (nextInput) {
            nextInput.focus();
        } else {
            // Submit form or trigger primary action
            const submitButton = form.querySelector('button[type="submit"], .btn-primary');
            if (submitButton) {
                submitButton.click();
            }
        }
    }

    handleFormSubmission(form) {
        const submitButton = form.querySelector('button[type="submit"], .btn-primary');
        const inputs = form.querySelectorAll('input, select, textarea');
        
        // Show loading state
        if (submitButton) {
            submitButton.classList.add('loading');
            submitButton.disabled = true;
        }

        // Validate all fields
        let isFormValid = true;
        inputs.forEach(input => {
            this.validateField(input);
            if (input.closest('.form-group')?.classList.contains('error')) {
                isFormValid = false;
            }
        });

        // Simulate form submission
        setTimeout(() => {
            if (submitButton) {
                submitButton.classList.remove('loading');
                submitButton.disabled = false;
            }

            if (isFormValid) {
                this.showToast('Form submitted successfully!', 'success');
            } else {
                this.showToast('Please correct the errors above', 'error');
            }
        }, 2000);
    }

    // Modal interactions
    setupModalInteractions() {
        const modal = document.getElementById('modal');
        const openButton = document.getElementById('openModal');
        const closeButton = document.getElementById('closeModal');
        const cancelButton = document.getElementById('modalCancel');
        const backdrop = modal?.querySelector('.modal-backdrop');

        if (openButton && modal) {
            openButton.addEventListener('click', () => {
                this.openModal(modal);
            });
        }

        [closeButton, cancelButton, backdrop].forEach(element => {
            if (element) {
                element.addEventListener('click', () => {
                    this.closeModal(modal);
                });
            }
        });

        // ESC key to close modal
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && modal?.classList.contains('active')) {
                this.closeModal(modal);
            }
        });
    }

    openModal(modal) {
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
        
        // Focus first focusable element
        const firstFocusable = modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
        if (firstFocusable) {
            setTimeout(() => firstFocusable.focus(), 100);
        }

        // Dispatch event
        window.dispatchEvent(new CustomEvent('modalOpened', { detail: { modal } }));
    }

    closeModal(modal) {
        modal.classList.remove('active');
        document.body.style.overflow = '';
        
        // Dispatch event
        window.dispatchEvent(new CustomEvent('modalClosed', { detail: { modal } }));
    }

    // Touch feedback and ripple effects
    setupTouchFeedback() {
        // Add touch feedback to interactive elements
        const touchElements = document.querySelectorAll('.btn, .card, .nav-item, .touch-card');
        
        touchElements.forEach(element => {
            let touchTimeout;

            element.addEventListener('touchstart', (e) => {
                element.classList.add('touching');
                
                // Add haptic feedback if available
                if (navigator.vibrate) {
                    navigator.vibrate(10);
                }
            }, { passive: true });

            element.addEventListener('touchend', () => {
                touchTimeout = setTimeout(() => {
                    element.classList.remove('touching');
                }, 150);
            }, { passive: true });

            element.addEventListener('touchcancel', () => {
                clearTimeout(touchTimeout);
                element.classList.remove('touching');
            }, { passive: true });
        });
    }

    setupRippleEffects() {
        const rippleButtons = document.querySelectorAll('.ripple-effect');
        
        rippleButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                this.createRipple(e, button);
            });
        });
    }

    createRipple(e, element) {
        const circle = document.createElement('span');
        const diameter = Math.max(element.clientWidth, element.clientHeight);
        const radius = diameter / 2;

        const rect = element.getBoundingClientRect();
        const left = e.clientX - rect.left - radius;
        const top = e.clientY - rect.top - radius;

        circle.style.width = circle.style.height = `${diameter}px`;
        circle.style.left = `${left}px`;
        circle.style.top = `${top}px`;
        circle.classList.add('ripple');

        // Remove existing ripples
        const ripple = element.getElementsByClassName('ripple')[0];
        if (ripple) {
            ripple.remove();
        }

        element.appendChild(circle);

        // Remove ripple after animation
        setTimeout(() => {
            circle.remove();
        }, 600);
    }

    // Pull to refresh functionality
    setupPullToRefresh() {
        const refreshContainer = document.getElementById('refreshContainer');
        if (!refreshContainer) return;

        let startY = 0;
        let currentY = 0;
        let isRefreshing = false;
        let isPulling = false;

        refreshContainer.addEventListener('touchstart', (e) => {
            if (refreshContainer.scrollTop === 0) {
                startY = e.touches[0].pageY;
                isPulling = true;
            }
        }, { passive: true });

        refreshContainer.addEventListener('touchmove', (e) => {
            if (!isPulling || isRefreshing) return;

            currentY = e.touches[0].pageY;
            const pullDistance = currentY - startY;

            if (pullDistance > 0 && pullDistance < 100) {
                refreshContainer.classList.add('pulling');
                const indicator = refreshContainer.querySelector('.refresh-text');
                if (indicator) {
                    indicator.textContent = 'Pull to refresh';
                }
            } else if (pullDistance >= 100) {
                const indicator = refreshContainer.querySelector('.refresh-text');
                if (indicator) {
                    indicator.textContent = 'Release to refresh';
                }
            }
        }, { passive: true });

        refreshContainer.addEventListener('touchend', () => {
            if (!isPulling || isRefreshing) return;

            const pullDistance = currentY - startY;
            
            if (pullDistance >= 100) {
                this.triggerRefresh(refreshContainer);
            } else {
                refreshContainer.classList.remove('pulling');
            }

            isPulling = false;
        }, { passive: true });
    }

    triggerRefresh(container) {
        container.classList.remove('pulling');
        container.classList.add('refreshing');
        
        const indicator = container.querySelector('.refresh-text');
        if (indicator) {
            indicator.textContent = 'Refreshing...';
        }

        // Simulate refresh
        setTimeout(() => {
            container.classList.remove('refreshing');
            const indicator = container.querySelector('.refresh-text');
            if (indicator) {
                indicator.textContent = 'Pull to refresh';
            }
            
            this.showToast('Content refreshed!', 'success');
        }, 2000);
    }

    // Toast notifications
    showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.innerHTML = `
            <span class="toast-message">${message}</span>
            <button class="toast-close" aria-label="Close">×</button>
        `;

        // Add toast styles if not exists
        if (!document.querySelector('#toast-styles')) {
            const styles = document.createElement('style');
            styles.id = 'toast-styles';
            styles.textContent = `
                .toast {
                    position: fixed;
                    top: 20px;
                    right: 20px;
                    left: 20px;
                    max-width: 400px;
                    margin: 0 auto;
                    padding: var(--spacing-md) var(--spacing-lg);
                    background: var(--color-surface-elevated);
                    border: 1px solid var(--color-border-light);
                    border-radius: var(--radius-lg);
                    box-shadow: 0 4px 12px var(--shadow-medium);
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    z-index: var(--z-toast);
                    transform: translateY(-100px);
                    opacity: 0;
                    transition: all var(--transition-normal);
                }
                .toast.show { transform: translateY(0); opacity: 1; }
                .toast-success { border-left: 4px solid var(--color-success); }
                .toast-error { border-left: 4px solid var(--color-error); }
                .toast-info { border-left: 4px solid var(--color-info); }
                .toast-message { flex: 1; color: var(--color-text-primary); font-size: var(--font-size-sm); }
                .toast-close { background: none; border: none; font-size: 18px; color: var(--color-text-secondary); cursor: pointer; padding: 0; margin-left: var(--spacing-sm); }
            `;
            document.head.appendChild(styles);
        }

        document.body.appendChild(toast);

        // Show toast
        setTimeout(() => toast.classList.add('show'), 10);

        // Auto-hide after 3 seconds
        const hideTimeout = setTimeout(() => {
            this.hideToast(toast);
        }, 3000);

        // Close button functionality
        const closeButton = toast.querySelector('.toast-close');
        closeButton.addEventListener('click', () => {
            clearTimeout(hideTimeout);
            this.hideToast(toast);
        });
    }

    hideToast(toast) {
        toast.classList.remove('show');
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 250);
    }

    // Setup validation with enhanced UX
    setupValidation() {
        // Password strength indicator
        const passwordInputs = document.querySelectorAll('input[type="password"]');
        passwordInputs.forEach(input => {
            this.addPasswordStrengthIndicator(input);
        });

        // Phone number formatting
        const phoneInputs = document.querySelectorAll('input[type="tel"]');
        phoneInputs.forEach(input => {
            this.addPhoneFormatting(input);
        });
    }

    addPasswordStrengthIndicator(input) {
        const formGroup = input.closest('.form-group');
        if (!formGroup) return;

        const strengthIndicator = document.createElement('div');
        strengthIndicator.className = 'password-strength';
        strengthIndicator.innerHTML = `
            <div class="strength-bar">
                <div class="strength-fill"></div>
            </div>
            <span class="strength-text">Enter password</span>
        `;

        // Add styles
        const styles = `
            .password-strength {
                margin-top: var(--spacing-sm);
                font-size: var(--font-size-xs);
            }
            .strength-bar {
                height: 4px;
                background: var(--color-bg-tertiary);
                border-radius: 2px;
                overflow: hidden;
                margin-bottom: var(--spacing-xs);
            }
            .strength-fill {
                height: 100%;
                transition: all var(--transition-normal);
                border-radius: 2px;
                width: 0%;
            }
            .strength-weak .strength-fill { width: 33%; background: var(--color-error); }
            .strength-medium .strength-fill { width: 66%; background: var(--color-warning); }
            .strength-strong .strength-fill { width: 100%; background: var(--color-success); }
        `;

        if (!document.querySelector('#password-strength-styles')) {
            const styleSheet = document.createElement('style');
            styleSheet.id = 'password-strength-styles';
            styleSheet.textContent = styles;
            document.head.appendChild(styleSheet);
        }

        formGroup.appendChild(strengthIndicator);

        input.addEventListener('input', () => {
            const strength = this.calculatePasswordStrength(input.value);
            this.updatePasswordStrength(strengthIndicator, strength);
        });
    }

    calculatePasswordStrength(password) {
        let score = 0;
        
        if (password.length >= 8) score++;
        if (/[a-z]/.test(password)) score++;
        if (/[A-Z]/.test(password)) score++;
        if (/[0-9]/.test(password)) score++;
        if (/[^A-Za-z0-9]/.test(password)) score++;

        if (score <= 2) return { level: 'weak', text: 'Weak password' };
        if (score <= 4) return { level: 'medium', text: 'Medium strength' };
        return { level: 'strong', text: 'Strong password' };
    }

    updatePasswordStrength(indicator, strength) {
        indicator.className = `password-strength strength-${strength.level}`;
        indicator.querySelector('.strength-text').textContent = strength.text;
    }

    addPhoneFormatting(input) {
        input.addEventListener('input', (e) => {
            let value = e.target.value.replace(/\D/g, '');
            
            if (value.length >= 6) {
                value = `(${value.slice(0, 3)}) ${value.slice(3, 6)}-${value.slice(6, 10)}`;
            } else if (value.length >= 3) {
                value = `(${value.slice(0, 3)}) ${value.slice(3)}`;
            }
            
            e.target.value = value;
        });
    }
}

// Initialize interactions when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.interactionManager = new InteractionManager();
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { InteractionManager };
}