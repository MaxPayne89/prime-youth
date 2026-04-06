/**
 * ScrollRevealHook - Reveals elements with a fade-up animation when they scroll into view
 *
 * Usage:
 *   <!-- Simple reveal -->
 *   <div phx-hook="ScrollReveal">Content fades up when visible</div>
 *
 *   <!-- Staggered children reveal -->
 *   <div phx-hook="ScrollReveal" data-reveal-stagger="100">
 *     <div>Card 1 (0ms delay)</div>
 *     <div>Card 2 (100ms delay)</div>
 *     <div>Card 3 (200ms delay)</div>
 *   </div>
 *
 *   <!-- Delayed reveal -->
 *   <div phx-hook="ScrollReveal" data-reveal-delay="200">Appears after 200ms</div>
 *
 * Elements start invisible (via CSS) and transition in when the observer fires.
 * Respects prefers-reduced-motion by revealing immediately without animation.
 */
const ScrollRevealHook = {
  mounted() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.revealImmediately()
      return
    }

    const delay = parseInt(this.el.dataset.revealDelay || "0", 10)
    const stagger = parseInt(this.el.dataset.revealStagger || "0", 10)

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setTimeout(() => this.reveal(stagger), delay)
            this.observer.unobserve(this.el)
          }
        })
      },
      { threshold: 0.15, rootMargin: "0px 0px -40px 0px" }
    )

    this.observer.observe(this.el)
  },

  reveal(stagger) {
    if (stagger > 0) {
      // Staggered children: animate each direct child with increasing delay
      Array.from(this.el.children).forEach((child, index) => {
        child.style.transitionDelay = `${index * stagger}ms`
        child.classList.add("revealed")
      })
      // Mark parent as revealed (makes it visible as a container)
      this.el.classList.add("revealed")
    } else {
      this.el.classList.add("revealed")
    }
  },

  revealImmediately() {
    this.el.classList.add("revealed")
    Array.from(this.el.children).forEach((child) => {
      child.classList.add("revealed")
    })
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  }
}

export default ScrollRevealHook
