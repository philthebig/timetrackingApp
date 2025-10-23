<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Timekeeping Analytics Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <link href="css/styles.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-dark bg-primary">
        <div class="container-fluid">
            <span class="navbar-brand mb-0 h1">
                <i class="fas fa-chart-line"></i> Timekeeping Analytics Dashboard
            </span>
            <div class="d-flex">
                <a href="index.cfm" class="btn btn-outline-light me-2">
                    <i class="fas fa-upload"></i> Import
                </a>
                <a href="dashboard.cfm" class="btn btn-outline-light">
                    <i class="fas fa-chart-line"></i> Dashboard
                </a>
            </div>
        </div>
    </nav>

    <cfparam name="url.batch" default="0">

    <!--- Get overall statistics --->
    <cfquery name="overallStats" datasource="yourDatasource">
        SELECT 
            COUNT(DISTINCT DirectorateID) AS TotalDirectorates,
            COUNT(DISTINCT DivisionID) AS TotalDivisions,
            COUNT(DISTINCT ClientEmail) AS TotalUniqueClients,
            COUNT(*) AS TotalProjects,
            SUM(RecordedHours) AS TotalHours,
            AVG(RecordedHours) AS AvgHoursPerProject
        FROM dbo.TimekeepingEnriched
        WHERE MatchStatus = 'Matched'
        <cfif url.batch GT 0>
            AND ImportBatchID = <cfqueryparam value="#url.batch#" cfsqltype="cf_sql_integer">
        </cfif>
    </cfquery>

    <!--- Get directorate breakdown --->
    <cfquery name="directorateStats" datasource="yourDatasource">
        SELECT TOP 10
            DirectorateNameE,
            DirectorateAcronymE,
            UniqueClients,
            TotalProjects,
            TotalHours,
            AvgHoursPerProject
        FROM dbo.vw_HoursByDirectorate
        ORDER BY TotalHours DESC
    </cfquery>

    <!--- Get category breakdown --->
    <cfquery name="categoryStats" datasource="yourDatasource">
        SELECT TOP 10
            Category,
            UniqueClients,
            TotalProjects,
            TotalHours,
            AvgHoursPerProject
        FROM dbo.vw_HoursByCategory
        ORDER BY TotalHours DESC
    </cfquery>

    <!--- Get top clients --->
    <cfquery name="topClients" datasource="yourDatasource">
        SELECT TOP 10
            ClientFirstName + ' ' + ClientLastName AS ClientName,
            ClientEmail,
            DirectorateNameE,
            DivisionNameE,
            TotalProjects,
            TotalHours
        FROM dbo.vw_TopClientsByHours
        ORDER BY TotalHours DESC
    </cfquery>

    <!--- Get unmatched clients if specific batch --->
    <cfif url.batch GT 0>
        <cfquery name="unmatchedClients" datasource="yourDatasource">
            SELECT 
                ClientEmail,
                ClientFirstName,
                ClientLastName,
                ClientContact,
                RecordedHours
            FROM dbo.UnmatchedClients
            WHERE ImportBatchID = <cfqueryparam value="#url.batch#" cfsqltype="cf_sql_integer">
            ORDER BY RecordedHours DESC
        </cfquery>
    </cfif>

    <div class="container-fluid mt-4">
        <!--- Summary Cards --->
        <div class="row mb-4">
            <div class="col-md-3">
                <div class="card text-white bg-primary">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <h6 class="card-title">Total Hours</h6>
                                <h2 class="mb-0">
                                    <cfoutput>#numberFormat(overallStats.TotalHours, "999,999.9")#</cfoutput>
                                </h2>
                            </div>
                            <div>
                                <i class="fas fa-clock fa-3x opacity-50"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card text-white bg-success">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <h6 class="card-title">Unique Clients</h6>
                                <h2 class="mb-0">
                                    <cfoutput>#overallStats.TotalUniqueClients#</cfoutput>
                                </h2>
                            </div>
                            <div>
                                <i class="fas fa-users fa-3x opacity-50"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card text-white bg-info">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <h6 class="card-title">Total Projects</h6>
                                <h2 class="mb-0">
                                    <cfoutput>#overallStats.TotalProjects#</cfoutput>
                                </h2>
                            </div>
                            <div>
                                <i class="fas fa-folder fa-3x opacity-50"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card text-white bg-warning">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <h6 class="card-title">Directorates</h6>
                                <h2 class="mb-0">
                                    <cfoutput>#overallStats.TotalDirectorates#</cfoutput>
                                </h2>
                            </div>
                            <div>
                                <i class="fas fa-building fa-3x opacity-50"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!--- Charts Row --->
        <div class="row mb-4">
            <div class="col-md-6">
                <div class="card shadow">
                    <div class="card-header bg-primary text-white">
                        <h5><i class="fas fa-chart-bar"></i> Hours by Directorate</h5>
                    </div>
                    <div class="card-body">
                        <canvas id="directorateChart"></canvas>
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card shadow">
                    <div class="card-header bg-success text-white">
                        <h5><i class="fas fa-chart-pie"></i> Hours by Category</h5>
                    </div>
                    <div class="card-body">
                        <canvas id="categoryChart"></canvas>
                    </div>
                </div>
            </div>
        </div>

        <!--- Tables Row --->
        <div class="row mb-4">
            <div class="col-md-6">
                <div class="card shadow">
                    <div class="card-header bg-info text-white">
                        <h5><i class="fas fa-building"></i> Top Directorates</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Directorate</th>
                                        <th>Clients</th>
                                        <th>Projects</th>
                                        <th>Hours</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <cfoutput query="directorateStats">
                                        <tr>
                                            <td>
                                                <strong>#DirectorateAcronymE#</strong><br>
                                                <small class="text-muted">#DirectorateNameE#</small>
                                            </td>
                                            <td>#UniqueClients#</td>
                                            <td>#TotalProjects#</td>
                                            <td><strong>#numberFormat(TotalHours, "999.9")#</strong></td>
                                        </tr>
                                    </cfoutput>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card shadow">
                    <div class="card-header bg-warning text-white">
                        <h5><i class="fas fa-user-tie"></i> Top Clients</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th>Client</th>
                                        <th>Directorate</th>
                                        <th>Projects</th>
                                        <th>Hours</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <cfoutput query="topClients">
                                        <tr>
                                            <td>
                                                <strong>#ClientName#</strong><br>
                                                <small class="text-muted">#ClientEmail#</small>
                                            </td>
                                            <td><small>#DirectorateNameE#</small></td>
                                            <td>#TotalProjects#</td>
                                            <td><strong>#numberFormat(TotalHours, "999.9")#</strong></td>
                                        </tr>
                                    </cfoutput>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!--- Unmatched Clients (if any) --->
        <cfif url.batch GT 0 AND unmatchedClients.recordCount GT 0>
            <div class="row mb-4">
                <div class="col-md-12">
                    <div class="card shadow border-danger">
                        <div class="card-header bg-danger text-white">
                            <h5><i class="fas fa-exclamation-triangle"></i> Unmatched Clients</h5>
                        </div>
                        <div class="card-body">
                            <p class="text-muted">
                                The following clients could not be matched with the directory. 
                                Please verify the email addresses or names.
                            </p>
                            <div class="table-responsive">
                                <table class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th>Email</th>
                                            <th>First Name</th>
                                            <th>Last Name</th>
                                            <th>Hours</th>
                                            <th>Full Contact Info</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <cfoutput query="unmatchedClients">
                                            <tr>
                                                <td>#ClientEmail#</td>
                                                <td>#ClientFirstName#</td>
                                                <td>#ClientLastName#</td>
                                                <td>#numberFormat(RecordedHours, "999.9")#</td>
                                                <td><small>#ClientContact#</small></td>
                                            </tr>
                                        </cfoutput>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </cfif>

        <!--- Export Options --->
        <div class="row mb-4">
            <div class="col-md-12">
                <div class="card shadow">
                    <div class="card-header bg-secondary text-white">
                        <h5><i class="fas fa-download"></i> Export Options</h5>
                    </div>
                    <div class="card-body">
                        <div class="btn-group" role="group">
                            <a href="export.cfm?type=directorate<cfif url.batch GT 0>&batch=#url.batch#</cfif>" 
                               class="btn btn-outline-primary">
                                <i class="fas fa-file-excel"></i> Export by Directorate
                            </a>
                            <a href="export.cfm?type=category<cfif url.batch GT 0>&batch=#url.batch#</cfif>" 
                               class="btn btn-outline-success">
                                <i class="fas fa-file-excel"></i> Export by Category
                            </a>
                            <a href="export.cfm?type=clients<cfif url.batch GT 0>&batch=#url.batch#</cfif>" 
                               class="btn btn-outline-info">
                                <i class="fas fa-file-excel"></i> Export Client Details
                            </a>
                            <cfif url.batch GT 0 AND unmatchedClients.recordCount GT 0>
                                <a href="export.cfm?type=unmatched&batch=#url.batch#" 
                                   class="btn btn-outline-danger">
                                    <i class="fas fa-file-excel"></i> Export Unmatched
                                </a>
                            </cfif>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <script>
        // Prepare data for charts
        const directorateData = {
            labels: [
                <cfoutput query="directorateStats">
                    '#DirectorateAcronymE#'<cfif currentRow NEQ recordCount>,</cfif>
                </cfoutput>
            ],
            datasets: [{
                label: 'Hours',
                data: [
                    <cfoutput query="directorateStats">
                        #TotalHours#<cfif currentRow NEQ recordCount>,</cfif>
                    </cfoutput>
                ],
                backgroundColor: [
                    'rgba(54, 162, 235, 0.7)',
                    'rgba(255, 99, 132, 0.7)',
                    'rgba(255, 206, 86, 0.7)',
                    'rgba(75, 192, 192, 0.7)',
                    'rgba(153, 102, 255, 0.7)',
                    'rgba(255, 159, 64, 0.7)',
                    'rgba(199, 199, 199, 0.7)',
                    'rgba(83, 102, 255, 0.7)',
                    'rgba(255, 99, 255, 0.7)',
                    'rgba(99, 255, 132, 0.7)'
                ],
                borderWidth: 1
            }]
        };

        const categoryData = {
            labels: [
                <cfoutput query="categoryStats">
                    '#left(Category, 30)#'<cfif currentRow NEQ recordCount>,</cfif>
                </cfoutput>
            ],
            datasets: [{
                label: 'Hours',
                data: [
                    <cfoutput query="categoryStats">
                        #TotalHours#<cfif currentRow NEQ recordCount>,</cfif>
                    </cfoutput>
                ],
                backgroundColor: [
                    'rgba(255, 99, 132, 0.7)',
                    'rgba(54, 162, 235, 0.7)',
                    'rgba(255, 206, 86, 0.7)',
                    'rgba(75, 192, 192, 0.7)',
                    'rgba(153, 102, 255, 0.7)',
                    'rgba(255, 159, 64, 0.7)',
                    'rgba(199, 199, 199, 0.7)',
                    'rgba(83, 102, 255, 0.7)',
                    'rgba(255, 99, 255, 0.7)',
                    'rgba(99, 255, 132, 0.7)'
                ]
            }]
        };

        // Create directorate chart
        const dirCtx = document.getElementById('directorateChart').getContext('2d');
        new Chart(dirCtx, {
            type: 'bar',
            data: directorateData,
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        display: false
                    },
                    title: {
                        display: false
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

        // Create category chart
        const catCtx = document.getElementById('categoryChart').getContext('2d');
        new Chart(catCtx, {
            type: 'doughnut',
            data: categoryData,
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        position: 'right'
                    }
                }
            }
        });
    </script>
</body>
</html>
