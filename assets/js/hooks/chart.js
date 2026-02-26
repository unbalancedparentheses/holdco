const ChartHook = {
  mounted() {
    const type = this.el.dataset.chartType || "bar";
    const data = JSON.parse(this.el.dataset.chartData || "{}");
    const options = JSON.parse(this.el.dataset.chartOptions || "{}");

    const canvas = this.el.querySelector("canvas") || this.el;
    const ctx = canvas.getContext ? canvas : document.createElement("canvas");
    if (!canvas.getContext) {
      this.el.appendChild(ctx);
    }

    this.chart = new Chart(ctx, { type, data, options: {
      responsive: true,
      maintainAspectRatio: false,
      ...options
    }});
  },

  updated() {
    const data = JSON.parse(this.el.dataset.chartData || "{}");
    if (this.chart) {
      this.chart.data = data;
      this.chart.update();
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export default ChartHook;
