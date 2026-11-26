// Directorate Chart
const dirData = {
    labels: chartLabels,
    datasets: [{
        label: 'Hours',
        data: chartValues,
        backgroundColor: [
            '#0d6efd', '#6c757d', '#198754', '#dc3545', 
            '#ffc107', '#0dcaf0', '#d63384', '#fd7e14'
        ]
    }]
};

const total = chartValues.reduce((a, b) => a + b, 0);

const pieData = {
    labels: chartLabels.map((label, i) => {
        const pct = ((chartValues[i] / total) * 100).toFixed(1);
        return `${label} (${pct}%)`;
    }),
    datasets: dirData.datasets
};

const valueLabelsPlugin = {
    id: 'valueLabels',
    afterDatasetsDraw(chart) {
        const { ctx } = chart;

        chart.data.datasets.forEach((dataset, i) => {
            const meta = chart.getDatasetMeta(i);

            meta.data.forEach((element, index) => {
                const value = dataset.data[index];

                ctx.save();
                ctx.fillStyle = 'black';
                ctx.font = 'bold 12px Arial';
                ctx.textAlign = 'center';

                if (chart.config.type === 'bar') {
                    ctx.fillText(value, element.x, element.y - 5);
                }

                ctx.restore();
            });
        });
    }
};

Chart.register(valueLabelsPlugin);

// Create Bar Chart
new Chart(document.getElementById('directorateChart'), {
    type: 'bar',
    data: dirData,
    options: {
        responsive: true,
        maintainAspectRatio: false,
        events: [],
        plugins: {
            legend: { display: false },
            title: {
                display: true,
                text: 'Total Hours by Directorate'
            }
        },
        scales: {
            y: {
                beginAtZero: true,
                title: {
                    display: true,
                    text: 'Hours'
                }
            }
        }
    }
});

// Create Pie Chart
new Chart(document.getElementById('distributionChart'), {
    type: 'pie',
    data: pieData,
    options: {
        responsive: true,
        maintainAspectRatio: false,
        events: [],
        plugins: {
            legend: {
                position: 'right'
            },
            title: {
                display: true,
                text: 'Hours Distribution'
            }
        }
    }
});