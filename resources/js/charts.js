const palette = [
    "#0d6efd",
    "#6c757d",
    "#198754",
    "#dc3545",
    "#ffc107",
    "#0dcaf0",
    "#d63384",
    "#fd7e14"
];

const hasCompare = Array.isArray(chartCompareValues)
    && chartCompareValues.length > 0
    && chartCompareValues.length === chartLabels.length;

const currentLabel = typeof chartCurrentLabel === "string" && chartCurrentLabel
    ? chartCurrentLabel
    : "This batch";
const compareLabel = typeof chartCompareLabel === "string" && chartCompareLabel
    ? chartCompareLabel
    : "Comparison";

const barDatasets = [{
    label: currentLabel,
    data: chartValues,
    backgroundColor: hasCompare ? "#667eea" : palette,
    borderRadius: 4,
    maxBarThickness: 46
}];

if (hasCompare) {
    barDatasets.push({
        label: compareLabel,
        data: chartCompareValues,
        backgroundColor: "#d5daf5",
        borderColor: "#b7bddf",
        borderWidth: 1,
        borderRadius: 4,
        maxBarThickness: 46
    });
}

const pieLabels = [];
const pieValues = [];

chartLabels.forEach(function (label, index) {
    const value = Number(chartValues[index]) || 0;
    if (value <= 0) {
        return;
    }
    pieLabels.push(label);
    pieValues.push(value);
});

if (pieLabels.length === 0) {
    chartLabels.forEach(function (label, index) {
        pieLabels.push(label);
        pieValues.push(Number(chartValues[index]) || 0);
    });
}

const pieTotal = pieValues.reduce(function (sum, value) {
    return sum + value;
}, 0);

const pieData = {
    labels: pieLabels.map(function (label, index) {
        const pct = pieTotal > 0
            ? ((pieValues[index] / pieTotal) * 100).toFixed(1)
            : "0.0";
        return label + " (" + pct + "%)";
    }),
    datasets: [{
        data: pieValues,
        backgroundColor: palette
    }]
};

function formatChartValue(value) {
    const number = Number(value);
    if (!Number.isFinite(number)) {
        return "";
    }
    return number.toLocaleString(undefined, { maximumFractionDigits: 1 });
}

const showBarLabels = !hasCompare || chartLabels.length <= 8;

const valueLabelsPlugin = {
    id: "valueLabels",
    afterDatasetsDraw(chart) {
        if (!showBarLabels || chart.config.type !== "bar") {
            return;
        }

        const { ctx } = chart;

        chart.data.datasets.forEach(function (dataset, datasetIndex) {
            const meta = chart.getDatasetMeta(datasetIndex);

            meta.data.forEach(function (element, index) {
                const value = dataset.data[index];
                ctx.save();
                ctx.fillStyle = "#212529";
                ctx.font = "bold 11px Arial";
                ctx.textAlign = "center";
                ctx.fillText(formatChartValue(value), element.x, element.y - 6);
                ctx.restore();
            });
        });
    }
};

Chart.register(valueLabelsPlugin);

new Chart(document.getElementById("directorateChart"), {
    type: "bar",
    data: {
        labels: chartLabels,
        datasets: barDatasets
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        events: [],
        layout: {
            padding: { top: showBarLabels ? 18 : 0 }
        },
        plugins: {
            legend: {
                display: hasCompare,
                position: "top"
            },
            title: {
                display: true,
                text: hasCompare
                    ? "Hours compared by directorate"
                    : "Total Hours by Directorate"
            }
        },
        scales: {
            y: {
                beginAtZero: true,
                title: {
                    display: true,
                    text: "Hours"
                }
            }
        }
    }
});

new Chart(document.getElementById("distributionChart"), {
    type: "pie",
    data: pieData,
    options: {
        responsive: true,
        maintainAspectRatio: false,
        events: [],
        plugins: {
            legend: {
                position: "right"
            },
            title: {
                display: true,
                text: hasCompare ? "This batch" : "Hours Distribution"
            }
        }
    }
});
