<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Timekeeping Analytics</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <link href="../css/styles.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.3.0/dist/chart.umd.js"></script>
</head>
<body>
    <nav class="navbar navbar-dark bg-primary">
        <div class="container-fluid">
            <span class="navbar-brand mb-0 h1">
                <i class="fas fa-chart-line"></i> Timekeeping Dashboard
            </span>
            <div class="d-flex">
                <a href="index.cfm" class="btn btn-outline-light me-2">
                    <i class="fas fa-upload"></i> Import
                </a>
                <a href="dashboard.cfm" class="btn btn-outline-light me-2">
                    <i class="fas fa-chart-line"></i> Dashboard
                </a>
                <a href="export.cfm" class="btn btn-outline-light">
                    <i class="fas fa-download"></i> Export
                </a>
            </div>
        </div>
    </nav>

    <div class="container-fluid mt-4">
        <cfparam name="url.batch" default="0">
        <cfparam name="url.page" default="1">
        <cfset batchFilter = val(url.batch)>
        <cfset currentPage = val(url.page)>
        <cfset pageSize = 20>
        
        <!--- Get batch info if specified --->
        <cfif batchFilter GT 0>
            <cfquery name="batchInfo" datasource="PMSD_SATS">
                SELECT * FROM dbo.ImportBatch WHERE BatchID = <cfqueryparam value="#batchFilter#" cfsqltype="cf_sql_integer">
            </cfquery>
        </cfif>
        
        <!--- Statistics Query --->
        <cfquery name="stats" datasource="PMSD_SATS">
            SELECT 
                COUNT(DISTINCT ImportBatchID) AS TotalBatches,
                SUM(RecordedHours) AS TotalHours,
                COUNT(*) AS TotalRecords
            FROM dbo.TimekeepingEnriched
            <cfif batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
        </cfquery>
        
        <!--- Directorate breakdown --->
        <cfquery name="directorateStats" datasource="PMSD_SATS">
            SELECT 
                ISNULL(DirectorateNameE, 'Unknown') AS Directorate,
                COUNT(*) AS RecordCount,
                SUM(RecordedHours) AS TotalHours
            FROM dbo.TimekeepingEnriched
            <cfif batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
            GROUP BY DirectorateNameE
            ORDER BY TotalHours DESC
        </cfquery>
        
        <!--- Unmatched clients with pagination --->
        <cfset startRow = (currentPage - 1) * pageSize + 1>
        
        <cfquery name="unmatchedCount" datasource="PMSD_SATS">
            SELECT COUNT(*) AS TotalCount FROM dbo.UnmatchedClients
            <cfif batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
        </cfquery>
        
        <cfset totalPages = ceiling(unmatchedCount.TotalCount / pageSize)>
        
        <cfquery name="unmatched" datasource="PMSD_SATS">
            SELECT 
                UnmatchedID,
                ImportBatchID,
                ClientEmail, 
                ClientFirstName, 
                ClientLastName, 
                ClientContact, 
                RecordedHours
            FROM dbo.UnmatchedClients
            <cfif batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
            ORDER BY UnmatchedID DESC
            OFFSET <cfqueryparam value="#startRow - 1#" cfsqltype="cf_sql_integer"> ROWS
            FETCH NEXT <cfqueryparam value="#pageSize#" cfsqltype="cf_sql_integer"> ROWS ONLY
        </cfquery>
        
        <!--- Header with batch info --->
        <div class="row mb-4">
            <div class="col-12">
                <cfif batchFilter GT 0 AND isDefined("batchInfo") AND batchInfo.recordCount GT 0>
                    <cfoutput>
                        <div class="alert alert-info">
                            <h5><i class="fas fa-filter"></i> Viewing Batch ###batchFilter#</h5>
                            <p class="mb-0">
                                <strong>File:</strong> #batchInfo.FileName# | 
                                <strong>Imported:</strong> #dateFormat(batchInfo.ImportDate, "yyyy-mm-dd")# #timeFormat(batchInfo.ImportDate, "HH:mm")# |
                                <strong>By:</strong> #batchInfo.ImportedBy#
                            </p>
                            <a href="dashboard.cfm" class="btn btn-sm btn-outline-primary mt-2">
                                <i class="fas fa-times"></i> Clear Filter
                            </a>
                        </div>
                    </cfoutput>
                <cfelse>
                    <h2><i class="fas fa-chart-line"></i> All Batches Dashboard</h2>
                </cfif>
            </div>
        </div>
        
        <!--- Statistics Cards --->
        <div class="row mb-4">
            <div class="col-md-4">
                <div class="card text-white bg-primary">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-database"></i> Total Records</h5>
                        <cfoutput><h2>#numberFormat(stats.TotalRecords)#</h2></cfoutput>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card text-white bg-success">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-clock"></i> Total Hours</h5>
                        <cfoutput><h2>#numberFormat(stats.TotalHours, "999,999.99")#</h2></cfoutput>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card text-white bg-warning">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-exclamation-triangle"></i> Unmatched</h5>
                        <cfoutput><h2>#numberFormat(unmatchedCount.TotalCount)#</h2></cfoutput>
                    </div>
                </div>
            </div>
        </div>
        
        <!--- Charts Row --->
        <div class="row mb-4">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header bg-primary text-white">
                        <h5><i class="fas fa-chart-bar"></i> Hours by Directorate</h5>
                    </div>
                    <div class="card-body">
                        <canvas id="directorateChart" height="300"></canvas>
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header bg-primary text-white">
                        <h5><i class="fas fa-chart-pie"></i> Distribution</h5>
                    </div>
                    <div class="card-body">
                        <canvas id="distributionChart" height="300"></canvas>
                    </div>
                </div>
            </div>
        </div>
        
        <!--- Unmatched Clients Table with Pagination --->
        <cfif unmatchedCount.TotalCount GT 0>
            <div class="row">
                <div class="col-12">
                    <div class="card">
                        <div class="card-header bg-warning text-dark d-flex justify-content-between align-items-center">
                            <h5 class="mb-0"><i class="fas fa-exclamation-triangle"></i> Unmatched Clients</h5>
                            <span class="badge bg-dark">
                                <cfoutput>#unmatchedCount.TotalCount# total</cfoutput>
                            </span>
                        </div>
                        <div class="card-body">
                            <div class="alert alert-info">
                                <i class="fas fa-info-circle"></i> These clients could not be matched with the directory. 
                                Please verify email addresses or names.
                            </div>
                            
                            <!--- Export Button at Top --->
                            <div class="text-center mb-3">
                                <cfoutput>
                                    <a href="export.cfm?type=unmatched&batch=#batchFilter#" class="btn btn-warning btn-lg">
                                        <i class="fas fa-download"></i> Export All Unmatched (#unmatchedCount.TotalCount#)
                                    </a>
                                </cfoutput>
                            </div>
                            
                            <div class="table-responsive">
                                <table class="table table-striped table-hover">
                                    <thead>
                                        <tr>
                                            <th>Email</th>
                                            <th>First Name</th>
                                            <th>Last Name</th>
                                            <th>Full Contact Info</th>
                                            <th>Hours</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <cfoutput query="unmatched">
                                            <tr>
                                                <td>#ClientEmail#</td>
                                                <td>#ClientFirstName#</td>
                                                <td>#ClientLastName#</td>
                                                <td><small>#ClientContact#</small></td>
                                                <td>#numberFormat(RecordedHours, "999.99")#</td>
                                            </tr>
                                        </cfoutput>
                                    </tbody>
                                </table>
                            </div>
                            
                            <!--- Pagination for Unmatched --->
                            <cfif totalPages GT 1>
                                <nav aria-label="Unmatched clients pagination">
                                    <ul class="pagination justify-content-center">
                                        <cfoutput>
                                            <li class="page-item <cfif currentPage EQ 1>disabled</cfif>">
                                                <a class="page-link" href="dashboard.cfm?batch=#batchFilter#&page=#currentPage - 1#">
                                                    <i class="fas fa-chevron-left"></i> Previous
                                                </a>
                                            </li>
                                            
                                            <cfloop from="1" to="#totalPages#" index="p">
                                                <cfif p EQ currentPage>
                                                    <li class="page-item active">
                                                        <span class="page-link">#p#</span>
                                                    </li>
                                                <cfelseif abs(p - currentPage) LT 3 OR p EQ 1 OR p EQ totalPages>
                                                    <li class="page-item">
                                                        <a class="page-link" href="dashboard.cfm?batch=#batchFilter#&page=#p#">#p#</a>
                                                    </li>
                                                <cfelseif abs(p - currentPage) EQ 3>
                                                    <li class="page-item disabled">
                                                        <span class="page-link">...</span>
                                                    </li>
                                                </cfif>
                                            </cfloop>
                                            
                                            <li class="page-item <cfif currentPage EQ totalPages>disabled</cfif>">
                                                <a class="page-link" href="dashboard.cfm?batch=#batchFilter#&page=#currentPage + 1#">
                                                    Next <i class="fas fa-chevron-right"></i>
                                                </a>
                                            </li>
                                        </cfoutput>
                                    </ul>
                                </nav>
                                
                                <cfoutput>
                                    <p class="text-center text-muted">
                                        Showing #startRow# - #min(startRow + pageSize - 1, unmatchedCount.TotalCount)# of #unmatchedCount.TotalCount# unmatched clients
                                        (Page #currentPage# of #totalPages#)
                                    </p>
                                </cfoutput>
                            </cfif>
                            
                            <!--- Export Button at Bottom Too --->
                            <div class="text-center mt-3">
                                <cfoutput>
                                    <a href="export.cfm?type=unmatched&batch=#batchFilter#" class="btn btn-warning btn-lg">
                                        <i class="fas fa-download"></i> Export All Unmatched (#unmatchedCount.TotalCount#)
                                    </a>
                                </cfoutput>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        <cfelse>
            <div class="alert alert-success">
                <i class="fas fa-check-circle"></i> <strong>Great!</strong> All clients were successfully matched.
            </div>
        </cfif>
        
        <!--- Quick Actions --->
        <div class="row mt-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header bg-secondary text-white">
                        <h5><i class="fas fa-bolt"></i> Quick Actions</h5>
                    </div>
                    <div class="card-body">
                        <div class="d-grid gap-2 d-md-flex">
                            <cfoutput>
                                <a href="export.cfm?type=all<cfif batchFilter GT 0>&batch=#batchFilter#</cfif>" class="btn btn-success">
                                    <i class="fas fa-download"></i> Export All Data
                                </a>
                                <a href="export.cfm?type=directorate<cfif batchFilter GT 0>&batch=#batchFilter#</cfif>" class="btn btn-primary">
                                    <i class="fas fa-building"></i> Export by Directorate
                                </a>
                                <a href="index.cfm" class="btn btn-info">
                                    <i class="fas fa-upload"></i> Import New File
                                </a>
                            </cfoutput>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Directorate Chart
        const dirData = {
            labels: [<cfoutput query="directorateStats">'#Directorate#'<cfif currentRow LT recordCount>,</cfif></cfoutput>],
            datasets: [{
                label: 'Hours',
                data: [<cfoutput query="directorateStats">#TotalHours#<cfif currentRow LT recordCount>,</cfif></cfoutput>],
                backgroundColor: ['#0d6efd', '#6c757d', '#198754', '#dc3545', '#ffc107', '#0dcaf0', '#d63384', '#fd7e14']
            }]
        };
        
        new Chart(document.getElementById('directorateChart'), {
            type: 'bar',
            data: dirData,
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false }
                }
            }
        });
        
        // Distribution Pie Chart
        new Chart(document.getElementById('distributionChart'), {
            type: 'pie',
            data: dirData,
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    </script>
</body>
</html>
