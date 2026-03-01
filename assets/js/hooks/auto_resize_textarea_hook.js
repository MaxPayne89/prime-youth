/**
 * AutoResizeTextareaHook - Automatically resizes textarea based on content
 *
 * Usage:
 *   <textarea phx-hook="AutoResizeTextarea"></textarea>
 *
 * This hook adjusts the textarea height to fit its content, providing a better
 * user experience for message composition without needing scrollbars.
 *
 * Listens for "clear_message_input" server events to reset the textarea value
 * after form submission, since LiveView skips DOM patching on submitted forms.
 */
const AutoResizeTextareaHook = {
  mounted() {
    this.resize()
    this.inputHandler = () => this.resize()
    this.el.addEventListener("input", this.inputHandler)

    // Trigger: server sends this event after successful message send
    // Why: LiveView's morphdom skips patching form inputs after phx-submit,
    //      so the textarea .value diverges from server-rendered content
    // Outcome: textarea visually clears and resizes to single row
    this.handleEvent("clear_message_input", () => {
      this.el.value = ""
      this.resize()
    })
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
