document.getElementById('uploadForm').addEventListener('submit', function(e) {
    const fileInput = document.getElementById('uploadFile');
    
    if (!fileInput.files || fileInput.files.length === 0) {
        return;
    }
    
    // Show loading overlay
    const overlay = document.getElementById('loadingOverlay');
    const stageText = document.getElementById('loadingStage');
    overlay.classList.add('show');
    
    // Animate through stages
    const stages = [
        { icon: 'fa-upload', text: 'Uploading file...' },
        { icon: 'fa-file-excel', text: 'Reading Excel data...' },
        { icon: 'fa-search', text: 'Extracting contact information...' },
        { icon: 'fa-database', text: 'Matching with directory...' },
        { icon: 'fa-check', text: 'Finalizing import...' }
    ];
    
    let currentStage = 0;
    const stageInterval = setInterval(function() {
        currentStage++;
        if (currentStage < stages.length) {
            const stage = stages[currentStage];
            stageText.innerHTML = '<i class="fas ' + stage.icon + '"></i> ' + stage.text;
        }
    }, 2000); // Change stage every 2 seconds
    
    // Store interval ID to clear it if needed
    window.loadingInterval = stageInterval;
});