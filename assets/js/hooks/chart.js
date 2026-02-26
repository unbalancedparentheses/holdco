const ChartHook = {
  mounted() {
    const type = this.el.dataset.chartType || "bar";
    const data = JSON.parse(this.el.dataset.chartData || "{}");
    const options = JSON.parse(this.el.dataset.chartOptions || "{}");

    const canvas = this.el.querySelector("canvas");
    if (!canvas) return;

    this.chart = new Chart(canvas, { type, data, options: {
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
