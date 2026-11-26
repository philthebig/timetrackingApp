<cfinclude template="navbar.cfm">
    <div class="container-fluid mt-perso">
        <cfparam name="url.type" default="all">
        <cfparam name="url.batch" default="0">
        <cfset exportType = url.type>
        <cfset batchFilter = val(url.batch)>
        <cfset args = {
            batchFilter = batchFilter
        }>

        <cfinvoke component="#application.query#" method="quickStatistics" returnvariable="quickStats" argumentcollection="#args#">
        
        <!--- Process Export if requested --->
        <cfif structKeyExists(url, "download") AND url.download EQ "true">
            <cftry>
                <!--- Create exports directory if it doesn't exist --->
                <cfset exportsDir = expandPath("./exports")>
                <cfif NOT directoryExists(exportsDir)>
                    <cfdirectory action="create" directory="#exportsDir#">
                </cfif>
                
                <!--- Generate filename with timestamp --->
                <cfset timestamp = dateFormat(now(), "yyyymmdd") & "_" & timeFormat(now(), "HHmmss")>
                <cfset fileName = "timekeeping_" & exportType & "_" & timestamp & ".xlsx">
                <cfset filePath = exportsDir & "/" & fileName>
                
                <!--- Query based on export type --->
                <cfswitch expression="#exportType#">
                    <cfcase value="unmatched">
                        <cfinvoke component="#application.query#" method="unmatchedExport" returnvariable="exportData" argumentcollection="#args#">
                    </cfcase>
                    
                    <cfcase value="directorate">
                        <cfinvoke component="#application.query#" method="directorateExport" returnvariable="exportData" argumentcollection="#args#">
                    </cfcase>
                    
                    <cfdefaultcase>
                        <!--- Export All --->
                        <cfinvoke component="#application.query#" method="allExport" returnvariable="exportData" argumentcollection="#args#">
                    </cfdefaultcase>
                </cfswitch>
                
                <!--- Create Excel file --->
                <cfif exportData.recordCount GT 0>
                    <cfspreadsheet action="write" 
                                  filename="#filePath#" 
                                  query="exportData" 
                                  overwrite="true"
                                  sheetname="Data">
                    
                    <!--- Set success flag --->
                    <cfset exportSuccess = true>
                    <cfset exportRecordCount = exportData.recordCount>
                    <cfset exportFileName = fileName>
                <cfelse>
                    <cfset exportSuccess = false>
                    <cfset exportError = "No data found to export.">
                </cfif>
                
                <cfcatch type="any">
                    <cfset exportSuccess = false>
                    <cfset exportError = cfcatch.message & " - " & cfcatch.detail>
                </cfcatch>
            </cftry>
        </cfif>
        
        <div class="row">
            <div class="col-md-8 offset-md-2">
                
                <!--- Show success/error message after export --->
                <cfif isDefined("exportSuccess")>
                    <cfif exportSuccess>
                        <div class="alert alert-success alert-dismissible fade show" role="alert">
                            <h5 class="alert-heading">
                                <i class="fas fa-check-circle"></i> Export Successful!
                            </h5>
                            <hr>
                            <cfoutput>
                                <p><strong>File:</strong> #exportFileName#</p>
                                <p><strong>Records Exported:</strong> #numberFormat(exportRecordCount)#</p>
                                <p><strong>Location:</strong> /exports/#exportFileName#</p>
                            </cfoutput>
                            <hr>
                            <div class="d-grid gap-2">
                                <cfoutput>
                                    <a href="exports/#exportFileName#" class="btn btn-success btn-lg" download>
                                        <i class="fas fa-download"></i> Download File
                                    </a>
                                </cfoutput>
                                <a href="dashboard.cfm" class="btn btn-primary">
                                    <i class="fas fa-chart-line"></i> Back to Dashboard
                                </a>
                            </div>
                            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                        </div>
                    <cfelse>
                        <div class="alert alert-danger alert-dismissible fade show" role="alert">
                            <h5 class="alert-heading">
                                <i class="fas fa-exclamation-triangle"></i> Export Failed
                            </h5>
                            <cfoutput>
                                <p><strong>Error:</strong> #exportError#</p>
                            </cfoutput>
                            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                        </div>
                    </cfif>
                </cfif>
                
                <!--- Export Options --->
                <div class="card shadow">
                    <div class="card-header bg-primary text-white">
                        <h4><i class="fas fa-download"></i> Export Data</h4>
                    </div>
                    <div class="card-body">
                        <p class="text-muted">Select the type of data you want to export to Excel format.</p>
                        
                        <!--- Batch filter display --->
                        <cfif batchFilter GT 0>
                            <cfinvoke component="#application.query#" method="batchInfo" returnvariable="info">
                                <cfinvokeargument name="batchFilter" value="#batchFilter#">
                            </cfinvoke>
                            <cfif info.recordCount GT 0>
                                <cfoutput>
                                    <div class="alert alert-info">
                                        <strong>Filtered to Batch ###batchFilter#:</strong> #info.FileName# 
                                        (Imported: #dateFormat(info.ImportDate, "yyyy-mm-dd")#)
                                        <a href="export.cfm" class="btn btn-sm btn-outline-primary ms-2">Clear Filter</a>
                                    </div>
                                </cfoutput>
                            </cfif>
                        </cfif>
                        
                        <div class="row g-3">
                            <!--- Export All --->
                            <div class="col-md-4">
                                <div class="card h-100">
                                    <div class="card-body text-center">
                                        <i class="fas fa-database fa-3x text-success mb-3"></i>
                                        <h5>All Data</h5>
                                        <p class="text-muted">Export all matched records with full organizational details.</p>
                                        <cfoutput>
                                            <a href="export.cfm?type=all&batch=#batchFilter#&download=true" class="btn btn-success">
                                                <i class="fas fa-download"></i> Export All
                                            </a>
                                        </cfoutput>
                                    </div>
                                </div>
                            </div>
                            
                            <!--- Export by Directorate --->
                            <div class="col-md-4">
                                <div class="card h-100">
                                    <div class="card-body text-center">
                                        <i class="fas fa-building fa-3x text-primary mb-3"></i>
                                        <h5>By Directorate</h5>
                                        <p class="text-muted">Export data grouped by directorate for organizational reporting.</p>
                                        <cfoutput>
                                            <a href="export.cfm?type=directorate&batch=#batchFilter#&download=true" class="btn btn-primary">
                                                <i class="fas fa-download"></i> Export by Dir.
                                            </a>
                                        </cfoutput>
                                    </div>
                                </div>
                            </div>
                            
                            <!--- Export Unmatched --->
                            <div class="col-md-4">
                                <div class="card h-100">
                                    <div class="card-body text-center">
                                        <i class="fas fa-exclamation-triangle fa-3x text-warning mb-3"></i>
                                        <h5>Unmatched Only</h5>
                                        <p class="text-muted">Export clients that could not be matched with the directory.</p>
                                        <cfoutput>
                                            <a href="export.cfm?type=unmatched&batch=#batchFilter#&download=true" class="btn btn-warning">
                                                <i class="fas fa-download"></i> Export Unmatched
                                            </a>
                                        </cfoutput>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <!--- Quick Stats --->
                        <div class="mt-4">
                            <h5>Quick Statistics</h5>                            
                            <cfoutput query="quickStats">
                                <div class="row text-center">
                                    <div class="col-md-4">
                                        <div class="border rounded p-3">
                                            <h3 class="text-success">#numberFormat(MatchedCount)#</h3>
                                            <small class="text-muted">Matched Records</small>
                                        </div>
                                    </div>
                                    <div class="col-md-4">
                                        <div class="border rounded p-3">
                                            <h3 class="text-warning">#numberFormat(UnmatchedCount)#</h3>
                                            <small class="text-muted">Unmatched Records</small>
                                        </div>
                                    </div>
                                    <div class="col-md-4">
                                        <div class="border rounded p-3">
                                            <h3 class="text-primary">#numberFormat(DirectorateCount)#</h3>
                                            <small class="text-muted">Directorates</small>
                                        </div>
                                    </div>
                                </div>
                            </cfoutput>
                        </div>
                    </div>
                </div>
                
                <!--- Recent Exports --->
                <div class="card shadow mt-4">
                    <div class="card-header bg-secondary text-white">
                        <h5><i class="fas fa-history"></i> Recent Exports</h5>
                    </div>
                    <div class="card-body">
                        <cfset exportsDir = expandPath("./exports")>
                        <cfif directoryExists(exportsDir)>
                            <cfdirectory action="list" 
                                        directory="#exportsDir#" 
                                        name="recentExports" 
                                        filter="*.xlsx"
                                        sort="datelastmodified DESC">
                            
                            <cfif recentExports.recordCount GT 0>
                                <div class="table-responsive">
                                    <table class="table table-hover">
                                        <thead>
                                            <tr>
                                                <th>File Name</th>
                                                <th>Date</th>
                                                <th>Size</th>
                                                <th>Action</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <cfoutput query="recentExports" maxrows="10">
                                                <tr>
                                                    <td>#name#</td>
                                                    <td>#dateFormat(datelastmodified, "yyyy-mm-dd")# #timeFormat(datelastmodified, "HH:mm")#</td>
                                                    <td>#numberFormat(size/1024, "999.9")# KB</td>
                                                    <td>
                                                        <a href="exports/#name#" class="btn btn-sm btn-success" download>
                                                            <i class="fas fa-download"></i> Download
                                                        </a>
                                                    </td>
                                                </tr>
                                            </cfoutput>
                                        </tbody>
                                    </table>
                                </div>
                            <cfelse>
                                <p class="text-muted">No exports available yet.</p>
                            </cfif>
                        <cfelse>
                            <p class="text-muted">Exports directory not found.</p>
                        </cfif>
                    </div>
                </div>
                
                <!--- Quick Navigation --->
                <div class="text-center mt-4">
                    <a href="index.cfm" class="btn btn-outline-primary me-2">
                        <i class="fas fa-upload"></i> New Import
                    </a>
                    <a href="dashboard.cfm" class="btn btn-outline-primary">
                        <i class="fas fa-chart-line"></i> View Dashboard
                    </a>
                </div>
            </div>
        </div>
    </div>

    <script src="/PMSD/SATS/Timetracking/resources/bootstrap/bootstrap/js/bootstrap.bundle.min.js"></script>
</body>
</html>