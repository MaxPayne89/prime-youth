/**
 * DebounceHook - Debounces input events before sending to LiveView
 *
 * Usage:
 *   <input phx-hook="Debounce" data-debounce="150" phx-change="search" />
 *
 * This hook prevents excessive server requests during rapid typing by waiting
 * for a specified delay (default 150ms) after the last keystroke before
 * triggering the search event.
 */
const DebounceHook = {
  mounted() {
    this.timeout = null
    this.delay = parseInt(this.el.dataset.debounce) || 150

    this.el.addEventListener("input", (e) => {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        this.pushEvent("search", { search: e.target.value })
      }, this.delay)
    })
  },

  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

export default DebounceHook
