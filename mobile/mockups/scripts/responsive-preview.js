/**
 * Responsive Preview System for Prime Youth App Mockups
 * Allows switching between different device sizes and orientations
 */

class ResponsivePreview {
    constructor() {
        this.currentDevice = 'iphone';
        this.currentOrientation = 'portrait';
        this.devices = {
            iphone: {
                name: 'iPhone 14',
                width: 375,
                height: 812,
                scale: 1
            },
            android: {
                name: 'Pixel 7',
                width: 393,
                height: 851,
                scale: 1
            },
            tablet: {
                name: 'iPad',
                width: 768,
                height: 1024,
                scale: 0.8
            },
            desktop: {
                name: 'Desktop',
                width: 1200,
                height: 800,
                scale: 0.6
            }
        };
        
        this.init();
    }

    init() {
        this.createResponsiveControls();
        this.attachEventListeners();
        this.addScreenTransitions();
        this.setupZoomControls();
    }

    /**
     * Create responsive preview controls
     */
    createResponsiveControls() {
        // Create responsive controls panel
        const controlsPanel = document.createElement('div');
        controlsPanel.id = 'responsive-controls';
        controlsPanel.className = 'responsive-controls';
        
        controlsPanel.innerHTML = `
            <div class="controls-header">
                <h4>📱 Device Preview</h4>
                <button id="controls-toggle" class="controls-toggle">−</button>
            </div>
            <div class="controls-content">
                <div class="device-selector">
                    <label>Device:</label>
                    <select id="device-select">
                        <option value="iphone">iPhone 14 (375×812)</option>
                        <option value="android">Pixel 7 (393×851)</option>
                        <option value="tablet">iPad (768×1024)</option>
                        <option value="desktop">Desktop (1200×800)</option>
                    </select>
                </div>
                
                <div class="orientation-controls">
                    <label>Orientation:</label>
                    <div class="orientation-buttons">
                        <button class="orientation-btn active" data-orientation="portrait">📱</button>
                        <button class="orientation-btn" data-orientation="landscape">📱</button>
                    </div>
                </div>
                
                <div class="zoom-controls">
                    <label>Zoom:</label>
                    <div class="zoom-buttons">
                        <button class="zoom-btn" data-zoom="0.5">50%</button>
                        <button class="zoom-btn active" data-zoom="1">100%</button>
                        <button class="zoom-btn" data-zoom="1.5">150%</button>
                    </div>
                </div>
                
                <div class="preview-info">
                    <div class="info-item">
                        <span class="info-label">Size:</span>
                        <span id="size-display">375 × 812</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Scale:</span>
                        <span id="scale-display">100%</span>
                    </div>
                </div>
            </div>
        `;

        // Add responsive preview styles
        const responsiveStyles = document.createElement('style');
        responsiveStyles.textContent = `
            .responsive-controls {
                position: fixed;
                top: 20px;
                left: 20px;
                background: var(--color-white);
                border-radius: var(--radius-lg);
                box-shadow: var(--shadow-lg);
                border: 1px solid var(--color-gray-200);
                z-index: 1000;
                min-width: 280px;
                transition: all 0.3s ease;
            }

            .controls-header {
                padding: var(--space-md) var(--space-lg);
                border-bottom: 1px solid var(--color-gray-200);
                display: flex;
                justify-content: between;
                align-items: center;
                background: linear-gradient(135deg, var(--color-magenta), var(--color-magenta-dark));
                color: var(--color-white);
                border-radius: var(--radius-lg) var(--radius-lg) 0 0;
            }

            .controls-header h4 {
                margin: 0;
                font-size: var(--font-size-sm);
                flex: 1;
            }

            .controls-toggle {
                background: none;
                border: none;
                color: var(--color-white);
                font-size: var(--font-size-lg);
                cursor: pointer;
                padding: var(--space-xs);
                border-radius: var(--radius-sm);
                transition: background-color 0.2s ease;
            }

            .controls-toggle:hover {
                background: rgba(255, 255, 255, 0.2);
            }

            .controls-content {
                padding: var(--space-lg);
                display: flex;
                flex-direction: column;
                gap: var(--space-lg);
                transition: all 0.3s ease;
            }

            .controls-content.collapsed {
                display: none;
            }

            .device-selector label,
            .orientation-controls label,
            .zoom-controls label {
                display: block;
                font-size: var(--font-size-sm);
                font-weight: var(--font-weight-medium);
                color: var(--color-gray-700);
                margin-bottom: var(--space-sm);
            }

            .device-selector select {
                width: 100%;
                padding: var(--space-sm);
                border: 1px solid var(--color-gray-300);
                border-radius: var(--radius-md);
                font-size: var(--font-size-sm);
                background: var(--color-white);
            }

            .orientation-buttons,
            .zoom-buttons {
                display: flex;
                gap: var(--space-sm);
            }

            .orientation-btn,
            .zoom-btn {
                padding: var(--space-sm) var(--space-md);
                border: 1px solid var(--color-gray-300);
                background: var(--color-white);
                border-radius: var(--radius-md);
                font-size: var(--font-size-sm);
                cursor: pointer;
                transition: all 0.2s ease;
            }

            .orientation-btn.active,
            .zoom-btn.active {
                background: var(--color-magenta);
                color: var(--color-white);
                border-color: var(--color-magenta);
            }

            .orientation-btn:hover,
            .zoom-btn:hover {
                border-color: var(--color-magenta);
            }

            .orientation-btn[data-orientation="landscape"] {
                transform: rotate(90deg);
            }

            .preview-info {
                background: var(--color-gray-50);
                border-radius: var(--radius-md);
                padding: var(--space-md);
            }

            .info-item {
                display: flex;
                justify-content: space-between;
                margin-bottom: var(--space-xs);
                font-size: var(--font-size-sm);
            }

            .info-item:last-child {
                margin-bottom: 0;
            }

            .info-label {
                color: var(--color-gray-600);
            }

            .info-value {
                font-weight: var(--font-weight-medium);
                color: var(--color-gray-800);
            }

            /* Screen transition animations */
            .screen-content {
                transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .screen-content.transitioning {
                opacity: 0;
                transform: translateX(20px);
            }

            .phone-frame {
                transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
                transform-origin: center center;
            }

            .phone-frame.tablet-mode {
                width: 768px;
                height: 1024px;
                border-radius: 20px;
            }

            .phone-frame.desktop-mode {
                width: 1200px;
                height: 800px;
                border-radius: 12px;
                background: var(--color-gray-200);
                padding: 4px;
            }

            .phone-frame.landscape {
                transform: rotate(90deg);
                margin: 200px 0;
            }

            /* Zoom controls */
            .mockup-content {
                transition: transform 0.3s ease;
                transform-origin: center center;
            }

            @media (max-width: 768px) {
                .responsive-controls {
                    position: relative;
                    top: 0;
                    left: 0;
                    margin: var(--space-md);
                    width: calc(100% - var(--space-xl));
                    min-width: auto;
                }
            }

            /* Smooth page transitions */
            .page-transition {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: linear-gradient(135deg, var(--color-cyan), var(--color-magenta));
                z-index: 9999;
                display: flex;
                align-items: center;
                justify-content: center;
                opacity: 0;
                visibility: hidden;
                transition: all 0.3s ease;
            }

            .page-transition.active {
                opacity: 1;
                visibility: visible;
            }

            .transition-content {
                text-align: center;
                color: var(--color-white);
            }

            .transition-spinner {
                width: 40px;
                height: 40px;
                border: 3px solid rgba(255, 255, 255, 0.3);
                border-top: 3px solid var(--color-white);
                border-radius: 50%;
                animation: spin 1s linear infinite;
                margin: 0 auto var(--space-md) auto;
            }

            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
        `;

        document.head.appendChild(responsiveStyles);
        document.body.appendChild(controlsPanel);

        // Create page transition overlay
        const pageTransition = document.createElement('div');
        pageTransition.className = 'page-transition';
        pageTransition.innerHTML = `
            <div class="transition-content">
                <div class="transition-spinner"></div>
                <div>Loading...</div>
            </div>
        `;
        document.body.appendChild(pageTransition);
    }

    /**
     * Attach event listeners for responsive controls
     */
    attachEventListeners() {
        // Device selector
        const deviceSelect = document.getElementById('device-select');
        deviceSelect.addEventListener('change', (e) => {
            this.changeDevice(e.target.value);
        });

        // Orientation controls
        const orientationBtns = document.querySelectorAll('.orientation-btn');
        orientationBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                this.changeOrientation(btn.dataset.orientation);
                orientationBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
            });
        });

        // Zoom controls
        const zoomBtns = document.querySelectorAll('.zoom-btn');
        zoomBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                this.changeZoom(parseFloat(btn.dataset.zoom));
                zoomBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
            });
        });

        // Controls toggle
        const controlsToggle = document.getElementById('controls-toggle');
        const controlsContent = document.querySelector('.controls-content');
        controlsToggle.addEventListener('click', () => {
            controlsContent.classList.toggle('collapsed');
            controlsToggle.textContent = controlsContent.classList.contains('collapsed') ? '+' : '−';
        });
    }

    /**
     * Change device preview
     */
    changeDevice(deviceType) {
        this.currentDevice = deviceType;
        const device = this.devices[deviceType];
        const phoneFrame = document.querySelector('.phone-frame');
        
        if (!phoneFrame) return;

        // Apply device-specific styles
        phoneFrame.className = 'phone-frame';
        
        if (deviceType === 'tablet') {
            phoneFrame.classList.add('tablet-mode');
        } else if (deviceType === 'desktop') {
            phoneFrame.classList.add('desktop-mode');
        }

        // Update dimensions
        if (this.currentOrientation === 'portrait') {
            phoneFrame.style.width = device.width + 'px';
            phoneFrame.style.height = device.height + 'px';
        } else {
            phoneFrame.style.width = device.height + 'px';
            phoneFrame.style.height = device.width + 'px';
        }

        this.updateDisplayInfo();
    }

    /**
     * Change orientation
     */
    changeOrientation(orientation) {
        this.currentOrientation = orientation;
        const phoneFrame = document.querySelector('.phone-frame');
        
        if (!phoneFrame) return;

        if (orientation === 'landscape') {
            phoneFrame.classList.add('landscape');
        } else {
            phoneFrame.classList.remove('landscape');
        }

        // Update device dimensions for current orientation
        this.changeDevice(this.currentDevice);
    }

    /**
     * Change zoom level
     */
    changeZoom(zoomLevel) {
        const mockupContent = document.querySelector('.mockup-content');
        if (!mockupContent) return;

        mockupContent.style.transform = `scale(${zoomLevel})`;
        
        // Update display info
        document.getElementById('scale-display').textContent = Math.round(zoomLevel * 100) + '%';
    }

    /**
     * Update size display information
     */
    updateDisplayInfo() {
        const device = this.devices[this.currentDevice];
        const sizeDisplay = document.getElementById('size-display');
        
        if (this.currentOrientation === 'portrait') {
            sizeDisplay.textContent = `${device.width} × ${device.height}`;
        } else {
            sizeDisplay.textContent = `${device.height} × ${device.width}`;
        }
    }

    /**
     * Add smooth screen transitions
     */
    addScreenTransitions() {
        const navBtns = document.querySelectorAll('.screen-nav-btn');
        
        navBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                
                const targetScreen = btn.dataset.screen;
                this.transitionToScreen(targetScreen, btn);
            });
        });
    }

    /**
     * Transition to a new screen with animation
     */
    transitionToScreen(targetScreen, clickedBtn) {
        const currentScreen = document.querySelector('.screen-content.active');
        const targetScreenEl = document.getElementById(targetScreen + '-screen');
        
        if (!currentScreen || !targetScreenEl) return;

        // Add transitioning class for animation
        currentScreen.classList.add('transitioning');
        
        setTimeout(() => {
            // Update navigation
            document.querySelectorAll('.screen-nav-btn').forEach(b => b.classList.remove('active'));
            clickedBtn.classList.add('active');
            
            // Update screen content
            document.querySelectorAll('.screen-content').forEach(screen => {
                screen.classList.remove('active');
            });
            targetScreenEl.classList.add('active');
            
            // Remove transitioning class
            setTimeout(() => {
                currentScreen.classList.remove('transitioning');
            }, 50);
        }, 200);
    }

    /**
     * Setup zoom controls for better viewing
     */
    setupZoomControls() {
        // Add keyboard shortcuts for zoom
        document.addEventListener('keydown', (e) => {
            if ((e.ctrlKey || e.metaKey) && e.key === '0') {
                e.preventDefault();
                this.changeZoom(1);
                document.querySelectorAll('.zoom-btn').forEach(b => b.classList.remove('active'));
                document.querySelector('[data-zoom="1"]').classList.add('active');
            }
            
            if ((e.ctrlKey || e.metaKey) && e.key === '=') {
                e.preventDefault();
                const currentZoom = parseFloat(document.querySelector('.zoom-btn.active').dataset.zoom);
                const newZoom = Math.min(currentZoom + 0.25, 2);
                this.changeZoom(newZoom);
            }
            
            if ((e.ctrlKey || e.metaKey) && e.key === '-') {
                e.preventDefault();
                const currentZoom = parseFloat(document.querySelector('.zoom-btn.active').dataset.zoom);
                const newZoom = Math.max(currentZoom - 0.25, 0.25);
                this.changeZoom(newZoom);
            }
        });
    }

    /**
     * Show page transition animation
     */
    showPageTransition(duration = 800) {
        const transition = document.querySelector('.page-transition');
        transition.classList.add('active');
        
        setTimeout(() => {
            transition.classList.remove('active');
        }, duration);
    }
}

// Initialize responsive preview when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Only initialize on app mockups page
    if (document.querySelector('.phone-frame')) {
        window.responsivePreview = new ResponsivePreview();
    }
});

// Export for global access
window.ResponsivePreview = ResponsivePreview;