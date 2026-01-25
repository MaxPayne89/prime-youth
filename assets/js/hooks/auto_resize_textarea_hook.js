/**
 * AutoResizeTextareaHook - Automatically resizes textarea based on content
 *
 * Usage:
 *   <textarea phx-hook="AutoResizeTextarea"></textarea>
 *
 * This hook adjusts the textarea height to fit its content, providing a better
 * user experience for message composition without needing scrollbars.
 */
const AutoResizeTextareaHook = {
  mounted() {
    this.resize()
    this.inputHandler = () => this.resize()
    this.el.addEventListener("input", this.inputHandler)
  },

  updated() {
    this.resize()
  },

  destroyed() {
    if (this.inputHandler) {
      this.el.removeEventListener("input", this.inputHandler)
      this.inputHandler = null
    }
  },

  resize() {
    this.el.style.height = "auto"
    this.el.style.height = this.el.scrollHeight + "px"
  }
}

export default AutoResizeTextareaHook
