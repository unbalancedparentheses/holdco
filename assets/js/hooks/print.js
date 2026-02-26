const PrintHook = {
  mounted() {
    this.el.addEventListener("js:print-report", (e) => {
      const url = e.detail && e.detail.url
      if (url) {
        // Open the report in a new window, then trigger print once loaded
        const win = window.open(url, "_blank")
        if (win) {
          win.addEventListener("load", () => {
            win.print()
          })
        }
      } else {
        window.print()
      }
    })

    this.handleEvent("js-print", () => {
      window.print()
    })
  }
}

export default PrintHook
