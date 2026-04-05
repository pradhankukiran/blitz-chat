export const ScrollBottom = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
    this.observer = new MutationObserver(() => {
      this.el.scrollTop = this.el.scrollHeight
    })
    this.observer.observe(this.el, { childList: true, subtree: true })
  },

  updated() {
    this.el.scrollTop = this.el.scrollHeight
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}
