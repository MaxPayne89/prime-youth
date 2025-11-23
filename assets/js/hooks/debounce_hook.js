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

    // Parse and validate debounce delay with error handling
    const debounceAttr = this.el.dataset.debounce

    if (debounceAttr !== undefined && debounceAttr !== null && debounceAttr !== "") {
      const parsedDelay = parseInt(debounceAttr, 10)

      if (isNaN(parsedDelay)) {
        console.error(
          `[DebounceHook] Invalid data-debounce value: "${debounceAttr}". ` +
          `Expected a number. Falling back to default 150ms.`,
          { element: this.el }
        )
        this.delay = 150
      } else if (parsedDelay < 50) {
        console.warn(
          `[DebounceHook] Debounce delay too small (${parsedDelay}ms). ` +
          `Using minimum of 50ms to prevent excessive server requests.`,
          { element: this.el }
        )
        this.delay = 50
      } else if (parsedDelay > 2000) {
        console.warn(
          `[DebounceHook] Unusually large debounce delay (${parsedDelay}ms). ` +
          `This may cause poor UX. Consider values under 1000ms.`,
          { element: this.el }
        )
        this.delay = parsedDelay
      } else {
        this.delay = parsedDelay
      }
    } else {
      this.delay = 150
    }

    // Store handler reference for proper cleanup
    this.inputHandler = (e) => {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        try {
          this.pushEvent("search", { search: e.target.value })
        } catch (error) {
          console.error(
            "[DebounceHook] Failed to send search event to LiveView:",
            error,
            { searchValue: e.target.value, element: this.el }
          )
        }
      }, this.delay)
    }

    this.el.addEventListener("input", this.inputHandler)
  },

  destroyed() {
    // Clear any pending timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }

    // Explicitly remove event listener to prevent memory leaks
    if (this.inputHandler) {
      this.el.removeEventListener("input", this.inputHandler)
      this.inputHandler = null
    }
  }
}

export default DebounceHook
