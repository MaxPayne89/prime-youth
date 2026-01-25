/**
 * ScrollToBottomHook - Automatically scrolls container to bottom
 *
 * Usage:
 *   <div id="messages" phx-hook="ScrollToBottom">...</div>
 *
 * This hook scrolls to the bottom of the container on mount and on updates,
 * useful for chat/messaging interfaces where new messages appear at the bottom.
 */
const ScrollToBottomHook = {
  mounted() {
    this.scrollToBottom()
  },

  updated() {
    this.scrollToBottom()
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

export default ScrollToBottomHook
