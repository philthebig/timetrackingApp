// Upload form handling and validation

document.addEventListener('DOMContentLoaded', function() {
    const uploadForm = document.getElementById('uploadForm');
    const submitBtn = document.getElementById('submitBtn');
    const processingIndicator = document.getElementById('processingIndicator');
    const uploadFile = document.getElementById('uploadFile');

    // File validation
    uploadFile.addEventListener('change', function(e) {
        const file = e.target.files[0];
        
        if (file) {
            // Check file extension
            const fileName = file.name.toLowerCase();
            if (!fileName.endsWith('.xlsx') && !fileName.endsWith('.xls')) {
                alert('Please select a valid Excel file (.xlsx or .xls)');
                uploadFile.value = '';
                return;
            }

            // Check file size (max 10MB)
            const maxSize = 10 * 1024 * 1024; // 10MB in bytes
            if (file.size > maxSize) {
                alert('File size must be less than 10MB');
                uploadFile.value = '';
                return;
            }

            // Display file info
            console.log('File selected:', fileName, 'Size:', (file.size / 1024).toFixed(2) + ' KB');
        }
    });

    // Form submission
    if (uploadForm) {
        uploadForm.addEventListener('submit', function(e) {
            // Validate file is selected
            if (!uploadFile.files.length) {
                e.preventDefault();
                alert('Please select a file to upload');
                return;
            }

            // Show processing indicator
            if (processingIndicator) {
                submitBtn.disabled = true;
                submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Processing...';
                processingIndicator.style.display = 'block';
            }

            // Allow form to submit normally
            return true;
        });
    }

    // Drag and drop functionality
    const dropZone = uploadFile.parentElement;
    
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, preventDefaults, false);
    });

    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    ['dragenter', 'dragover'].forEach(eventName => {
        dropZone.addEventListener(eventName, highlight, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, unhighlight, false);
    });

    function highlight(e) {
        dropZone.classList.add('border-primary', 'bg-light');
    }

    function unhighlight(e) {
        dropZone.classList.remove('border-primary', 'bg-light');
    }

    dropZone.addEventListener('drop', handleDrop, false);

    function handleDrop(e) {
        const dt = e.dataTransfer;
        const files = dt.files;

        if (files.length) {
            uploadFile.files = files;
            
            // Trigger change event
            const event = new Event('change', { bubbles: true });
            uploadFile.dispatchEvent(event);
        }
    }

    // Auto-populate importedBy field if possible
    const importedBy = document.getElementById('importedBy');
    if (importedBy && !importedBy.value) {
        // Try to get from session storage or user context
        const savedUser = localStorage.getItem('timekeepingUser');
        if (savedUser) {
            importedBy.value = savedUser;
        }
    }

    // Save user name to local storage on form submit
    if (uploadForm) {
        uploadForm.addEventListener('submit', function() {
            const userName = importedBy.value.trim();
            if (userName) {
                localStorage.setItem('timekeepingUser', userName);
            }
        });
    }
});

// Format numbers with thousand separators
function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// Download helper function
function downloadExport(type, batchId = null) {
    let url = `export.cfm?type=${type}`;
    if (batchId) {
        url += `&batch=${batchId}`;
    }
    window.location.href = url;
}

// Confirm before navigation if processing
window.addEventListener('beforeunload', function(e) {
    const processingIndicator = document.getElementById('processingIndicator');
    if (processingIndicator && processingIndicator.style.display !== 'none') {
        e.preventDefault();
        e.returnValue = 'Upload is in progress. Are you sure you want to leave?';
        return e.returnValue;
    }
});

// Table sorting functionality
function sortTable(tableId, columnIndex, dataType = 'string') {
    const table = document.getElementById(tableId);
    if (!table) return;

    const tbody = table.querySelector('tbody');
    const rows = Array.from(tbody.querySelectorAll('tr'));
    
    // Determine sort direction
    const currentDirection = table.dataset.sortDirection || 'asc';
    const newDirection = currentDirection === 'asc' ? 'desc' : 'asc';
    table.dataset.sortDirection = newDirection;
    
    // Sort rows
    rows.sort((a, b) => {
        const aValue = a.cells[columnIndex].textContent.trim();
        const bValue = b.cells[columnIndex].textContent.trim();
        
        let comparison = 0;
        if (dataType === 'number') {
            comparison = parseFloat(aValue) - parseFloat(bValue);
        } else {
            comparison = aValue.localeCompare(bValue);
        }
        
        return newDirection === 'asc' ? comparison : -comparison;
    });
    
    // Re-append sorted rows
    rows.forEach(row => tbody.appendChild(row));
}

// Add click handlers to table headers for sorting
document.addEventListener('DOMContentLoaded', function() {
    const tables = document.querySelectorAll('.table');
    tables.forEach(table => {
        const headers = table.querySelectorAll('thead th');
        headers.forEach((header, index) => {
            if (header.textContent.trim()) {
                header.style.cursor = 'pointer';
                header.addEventListener('click', function() {
                    const dataType = header.dataset.type || 'string';
                    sortTable(table.id, index, dataType);
                });
            }
        });
    });
});
