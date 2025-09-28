// Prime Youth Mobile UI System - Advanced Animations

class AnimationManager {
    constructor() {
        this.reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        this.init();
    }

    init() {
        this.setupScreenTransitions();
        this.setupMicroInteractions();
        this.setupListAnimations();
        this.setupIntersectionObserver();
        this.setupPerformanceOptimizations();
    }

    // Screen transition animations
    setupScreenTransitions() {
        const transitionButtons = document.querySelectorAll('[data-transition]');
        const transitionDemo = document.getElementById('transitionDemo');

        if (!transitionDemo) return;

        const screens = transitionDemo.querySelectorAll('.demo-screen');
        let currentScreenIndex = 0;

        transitionButtons.forEach(button => {
            button.addEventListener('click', () => {
                if (this.reducedMotion) return;

                const transitionType = button.getAttribute('data-transition');
                this.performScreenTransition(transitionDemo, screens, transitionType, currentScreenIndex);
                currentScreenIndex = (currentScreenIndex + 1) % screens.length;
            });
        });
    }

    performScreenTransition(container, screens, type, currentIndex) {
        const currentScreen = screens[currentIndex];
        const nextScreen = screens[(currentIndex + 1) % screens.length];

        // Set transition type class
        container.className = `transition-demo ${type}`;

        // Start transition
        currentScreen.classList.add('exiting');
        nextScreen.classList.add('active');

        // Clean up after transition
        setTimeout(() => {
            currentScreen.classList.remove('active', 'exiting');
            container.className = 'transition-demo';
        }, 400);
    }

    // Micro-interactions setup
    setupMicroInteractions() {
        this.setupHoverEffects();
        this.setupScrollAnimations();
        this.setupLoadingAnimations();
        this.setupProgressAnimations();
    }

    setupHoverEffects() {
        const interactionItems = document.querySelectorAll('.interaction-item');
        
        interactionItems.forEach(item => {
            if (item.classList.contains('bounce-in')) {
                this.animateOnView(item, 'bounceIn', 0.8);
            }
            
            if (item.classList.contains('slide-reveal')) {
                this.animateOnView(item, 'slideReveal', 0.6);
            }

            if (item.classList.contains('pulse-glow')) {
                this.animateOnView(item, 'pulseGlow', 2);
            }
        });
    }

    setupScrollAnimations() {
        const scrollTriggers = document.querySelectorAll('.scroll-trigger');
        
        scrollTriggers.forEach(element => {
            this.animateOnView(element, 'fadeInUp', 0.6);
        });
    }

    setupLoadingAnimations() {
        // Skeleton loading animation
        const skeletonElements = document.querySelectorAll('.skeleton-card');
        skeletonElements.forEach(element => {
            this.addShimmerEffect(element);
        });

        // Spinner variations
        this.setupSpinnerAnimations();
    }

    setupSpinnerAnimations() {
        const spinners = document.querySelectorAll('.loading-spinner');
        
        spinners.forEach(spinner => {
            if (spinner.classList.contains('dots')) {
                this.animateDotsSpinner(spinner);
            }
        });
    }

    animateDotsSpinner(spinner) {
        const dots = spinner.querySelectorAll('span');
        
        dots.forEach((dot, index) => {
            dot.style.animationDelay = `${index * 0.16}s`;
        });
    }

    setupProgressAnimations() {
        const progressBars = document.querySelectorAll('.progress-bar');
        
        progressBars.forEach(bar => {
            this.animateProgressBar(bar);
        });
    }

    animateProgressBar(bar) {
        const targetWidth = bar.getAttribute('data-progress') || '75';
        
        // Animate to target width
        setTimeout(() => {
            bar.style.width = `${targetWidth}%`;
        }, 200);
    }

    // List animations
    setupListAnimations() {
        const replayButton = document.getElementById('replayAnimation');
        const animatedList = document.querySelector('.animated-list');

        if (replayButton && animatedList) {
            replayButton.addEventListener('click', () => {
                this.replayListAnimation(animatedList);
            });
        }
    }

    replayListAnimation(list) {
        const items = list.querySelectorAll('.list-item');
        
        // Reset animations
        list.classList.add('replay');
        
        setTimeout(() => {
            list.classList.remove('replay');
            
            // Trigger stagger animation
            items.forEach((item, index) => {
                item.style.setProperty('--delay', index);
                item.classList.add('animate-in');
                
                setTimeout(() => {
                    item.classList.remove('animate-in');
                }, 500 + (index * 100));
            });
        }, 50);
    }

    // Intersection Observer for scroll-triggered animations
    setupIntersectionObserver() {
        if (this.reducedMotion) return;

        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        this.observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    this.triggerElementAnimation(entry.target);
                }
            });
        }, observerOptions);

        // Observe elements for scroll animations
        const animatedElements = document.querySelectorAll(
            '.card, .btn, .form-group, .state-example, .component-group'
        );

        animatedElements.forEach(element => {
            this.observer.observe(element);
        });
    }

    triggerElementAnimation(element) {
        if (element.classList.contains('animated')) return;

        element.classList.add('animated', 'fadeInUp');
        
        // Remove animation class after completion
        setTimeout(() => {
            element.classList.remove('fadeInUp');
        }, 600);
    }

    animateOnView(element, animationClass, duration) {
        if (this.reducedMotion) return;

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting && !entry.target.classList.contains('animated')) {
                    entry.target.classList.add('animated', animationClass);
                    
                    setTimeout(() => {
                        entry.target.classList.remove(animationClass);
                    }, duration * 1000);
                    
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.3 });

        observer.observe(element);
    }

    // Performance optimizations
    setupPerformanceOptimizations() {
        // Add will-change property to elements that will be animated
        const animatedElements = document.querySelectorAll(
            '.btn, .card, .modal-content, .nav-item, .form-input'
        );

        animatedElements.forEach(element => {
            element.addEventListener('mouseenter', () => {
                element.style.willChange = 'transform';
            });

            element.addEventListener('mouseleave', () => {
                element.style.willChange = 'auto';
            });
        });

        // GPU acceleration for frequently animated elements
        const gpuElements = document.querySelectorAll(
            '.loading-spinner, .shimmer-item, .progress-bar'
        );

        gpuElements.forEach(element => {
            element.classList.add('gpu-accelerate');
        });
    }

    // Shimmer effect for skeleton loading
    addShimmerEffect(element) {
        const shimmerElements = element.querySelectorAll(
            '.skeleton-image, .skeleton-title, .skeleton-text'
        );

        shimmerElements.forEach((shimmer, index) => {
            shimmer.style.setProperty('--shimmer-delay', `${index * 0.2}s`);
        });
    }

    // Dynamic animation utilities
    createCustomAnimation(element, keyframes, options = {}) {
        if (this.reducedMotion) return;

        const defaultOptions = {
            duration: 300,
            easing: 'ease',
            fill: 'both'
        };

        const animationOptions = { ...defaultOptions, ...options };
        
        return element.animate(keyframes, animationOptions);
    }

    // Stagger animations for multiple elements
    staggerAnimation(elements, animationClass, delay = 100) {
        if (this.reducedMotion) return;

        elements.forEach((element, index) => {
            setTimeout(() => {
                element.classList.add(animationClass);
                
                setTimeout(() => {
                    element.classList.remove(animationClass);
                }, 600);
            }, index * delay);
        });
    }

    // Page transition animations
    animatePageTransition(fromPage, toPage, direction = 'left') {
        if (this.reducedMotion) {
            fromPage.style.display = 'none';
            toPage.style.display = 'block';
            return;
        }

        const animations = {
            left: {
                out: [
                    { transform: 'translateX(0)' },
                    { transform: 'translateX(-100%)' }
                ],
                in: [
                    { transform: 'translateX(100%)' },
                    { transform: 'translateX(0)' }
                ]
            },
            right: {
                out: [
                    { transform: 'translateX(0)' },
                    { transform: 'translateX(100%)' }
                ],
                in: [
                    { transform: 'translateX(-100%)' },
                    { transform: 'translateX(0)' }
                ]
            },
            up: {
                out: [
                    { transform: 'translateY(0)' },
                    { transform: 'translateY(-100%)' }
                ],
                in: [
                    { transform: 'translateY(100%)' },
                    { transform: 'translateY(0)' }
                ]
            }
        };

        const animationOptions = {
            duration: 300,
            easing: 'cubic-bezier(0.25, 0.46, 0.45, 0.94)',
            fill: 'both'
        };

        // Start animations
        const outAnimation = fromPage.animate(
            animations[direction].out,
            animationOptions
        );

        toPage.style.display = 'block';
        const inAnimation = toPage.animate(
            animations[direction].in,
            animationOptions
        );

        // Cleanup after animation
        Promise.all([outAnimation.finished, inAnimation.finished]).then(() => {
            fromPage.style.display = 'none';
            fromPage.style.transform = '';
            toPage.style.transform = '';
        });
    }

    // Particle animation system
    createParticleEffect(container, particleCount = 20) {
        if (this.reducedMotion) return;

        const particles = [];
        
        for (let i = 0; i < particleCount; i++) {
            const particle = document.createElement('div');
            particle.className = 'particle';
            particle.style.cssText = `
                position: absolute;
                width: 4px;
                height: 4px;
                background: var(--prime-yellow);
                border-radius: 50%;
                pointer-events: none;
                opacity: 0;
            `;
            
            container.appendChild(particle);
            particles.push(particle);
        }

        this.animateParticles(particles, container);
    }

    animateParticles(particles, container) {
        const rect = container.getBoundingClientRect();
        
        particles.forEach((particle, index) => {
            const delay = index * 50;
            
            setTimeout(() => {
                const startX = rect.width / 2;
                const startY = rect.height / 2;
                const endX = Math.random() * rect.width;
                const endY = Math.random() * rect.height;
                
                particle.animate([
                    {
                        left: `${startX}px`,
                        top: `${startY}px`,
                        opacity: 1
                    },
                    {
                        left: `${endX}px`,
                        top: `${endY}px`,
                        opacity: 0
                    }
                ], {
                    duration: 1000,
                    easing: 'ease-out'
                }).onfinish = () => {
                    particle.remove();
                };
            }, delay);
        });
    }

    // Spring animation system
    springAnimation(element, property, to, config = {}) {
        if (this.reducedMotion) return;

        const defaultConfig = {
            tension: 170,
            friction: 26,
            mass: 1
        };

        const springConfig = { ...defaultConfig, ...config };
        
        // This is a simplified spring animation
        // In production, you might want to use a proper physics library
        const duration = this.calculateSpringDuration(springConfig);
        
        element.animate([
            { [property]: element.style[property] || '0px' },
            { [property]: to }
        ], {
            duration,
            easing: 'cubic-bezier(0.23, 1, 0.32, 1)',
            fill: 'forwards'
        });
    }

    calculateSpringDuration(config) {
        // Simplified calculation - real springs would be more complex
        return Math.sqrt(config.mass / config.tension) * config.friction * 100;
    }

    // Cleanup method
    destroy() {
        if (this.observer) {
            this.observer.disconnect();
        }
    }
}

// Enhanced easing functions
const Easing = {
    easeOutBounce: 'cubic-bezier(0.68, -0.55, 0.265, 1.55)',
    easeOutElastic: 'cubic-bezier(0.68, -0.6, 0.32, 1.6)',
    easeOutBack: 'cubic-bezier(0.175, 0.885, 0.32, 1.275)',
    easeInOutQuart: 'cubic-bezier(0.77, 0, 0.175, 1)',
    easeOutCirc: 'cubic-bezier(0.075, 0.82, 0.165, 1)'
};

// Animation presets
const AnimationPresets = {
    fadeIn: [
        { opacity: 0 },
        { opacity: 1 }
    ],
    fadeInUp: [
        { opacity: 0, transform: 'translateY(20px)' },
        { opacity: 1, transform: 'translateY(0)' }
    ],
    slideInLeft: [
        { transform: 'translateX(-100%)' },
        { transform: 'translateX(0)' }
    ],
    slideInRight: [
        { transform: 'translateX(100%)' },
        { transform: 'translateX(0)' }
    ],
    scaleIn: [
        { transform: 'scale(0.8)', opacity: 0 },
        { transform: 'scale(1)', opacity: 1 }
    ],
    bounceIn: [
        { transform: 'scale(0.3)', opacity: 0 },
        { transform: 'scale(1.05)', offset: 0.5 },
        { transform: 'scale(0.9)', offset: 0.7 },
        { transform: 'scale(1)', opacity: 1 }
    ]
};

// Touch gesture animations
class TouchGestureAnimations {
    constructor() {
        this.setupSwipeAnimations();
        this.setupPinchAnimations();
    }

    setupSwipeAnimations() {
        let startX, startY, currentX, currentY;
        let isSwipping = false;

        document.addEventListener('touchstart', (e) => {
            startX = e.touches[0].clientX;
            startY = e.touches[0].clientY;
            isSwipping = true;
        }, { passive: true });

        document.addEventListener('touchmove', (e) => {
            if (!isSwipping) return;

            currentX = e.touches[0].clientX;
            currentY = e.touches[0].clientY;

            const deltaX = currentX - startX;
            const deltaY = currentY - startY;

            // Horizontal swipe
            if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
                this.handleSwipe(deltaX > 0 ? 'right' : 'left', Math.abs(deltaX));
            }
        }, { passive: true });

        document.addEventListener('touchend', () => {
            isSwipping = false;
        }, { passive: true });
    }

    handleSwipe(direction, distance) {
        const swipeElements = document.querySelectorAll('.swipeable');
        
        swipeElements.forEach(element => {
            const maxDistance = element.offsetWidth * 0.3;
            const translateX = Math.min(distance, maxDistance) * (direction === 'left' ? -1 : 1);
            
            element.style.transform = `translateX(${translateX}px)`;
            
            setTimeout(() => {
                element.style.transform = '';
            }, 300);
        });
    }

    setupPinchAnimations() {
        let initialDistance = 0;
        let currentScale = 1;

        document.addEventListener('touchstart', (e) => {
            if (e.touches.length === 2) {
                initialDistance = this.getDistance(e.touches[0], e.touches[1]);
            }
        }, { passive: true });

        document.addEventListener('touchmove', (e) => {
            if (e.touches.length === 2) {
                const currentDistance = this.getDistance(e.touches[0], e.touches[1]);
                const scale = currentDistance / initialDistance;
                
                const pinchElements = document.querySelectorAll('.pinchable');
                pinchElements.forEach(element => {
                    element.style.transform = `scale(${scale})`;
                });
            }
        }, { passive: true });

        document.addEventListener('touchend', () => {
            const pinchElements = document.querySelectorAll('.pinchable');
            pinchElements.forEach(element => {
                element.style.transform = '';
            });
        }, { passive: true });
    }

    getDistance(touch1, touch2) {
        const dx = touch1.clientX - touch2.clientX;
        const dy = touch1.clientY - touch2.clientY;
        return Math.sqrt(dx * dx + dy * dy);
    }
}

// Initialize animations when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.animationManager = new AnimationManager();
    window.touchGestureAnimations = new TouchGestureAnimations();
});

// Handle reduced motion preference changes
if (window.matchMedia) {
    const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    motionQuery.addEventListener('change', () => {
        if (window.animationManager) {
            window.animationManager.reducedMotion = motionQuery.matches;
        }
    });
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { 
        AnimationManager, 
        TouchGestureAnimations, 
        Easing, 
        AnimationPresets 
    };
}