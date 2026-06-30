const ClipboardCopy = {
  mounted() {
    this.originalLabel = this.el.dataset.copyLabel || this.el.textContent
    this.copiedLabel = this.el.dataset.copiedLabel || this.originalLabel

    this.el.addEventListener("click", event => {
      event.preventDefault()
      this.copy()
    })
  },
  copy() {
    const source = document.querySelector(this.el.dataset.copySource)
    const value = source?.value || ""

    if (!value || !navigator.clipboard) return

    navigator.clipboard.writeText(value).then(() => {
      const label = this.el.querySelector("[data-copy-button-label]")
      this.el.dataset.copied = "true"
      if (label) label.textContent = this.copiedLabel

      window.setTimeout(() => {
        this.el.dataset.copied = "false"
        if (label) label.textContent = this.originalLabel
      }, 1600)
    })
  },
}

export default ClipboardCopy
