<cfif structKeyExists(url, "page") AND url.page EQ 'AccessDenied'>
    <cfinclude template="AccessDenied.cfm">
<cfelse>
    <cfparam name="url.page" default="1">
    <cfset deleteBatchError = "">

    <cfif structKeyExists(form, "deleteBatchButton")>
        <cfinvoke
            component="#application.query#"
            method="deleteBatch"
            returnvariable="deleteBatchResult">
            <cfinvokeargument
                name="batchID"
                value="#structKeyExists(form, 'deleteBatchID') ? val(form.deleteBatchID) : 0#">
        </cfinvoke>

        <cfif deleteBatchResult.success>
            <cflocation url="index.cfm?page=#val(url.page)#&batchDeleted=1" addtoken="false">
        <cfelse>
            <cfset deleteBatchError = deleteBatchResult.errorMessage>
        </cfif>
    </cfif>

    <cfinclude template="navbar.cfm">
    <cfset currentPage = val(url.page)>
    <cfset pageSize = 10>
    <cfset startRow = (currentPage - 1) * pageSize + 1>
    <cfset args = {
        startRow = startRow,
        pageSize = pageSize
    }>

    <cfinvoke component="#application.query#" method="importCount" returnvariable="recentImportsCount">
    <cfinvoke component="#application.query#" method="recentImport" returnvariable="recentImports" argumentcollection="#args#">

    <!-- Loading Overlay -->
    <div class="loading-overlay" id="loadingOverlay">
        <div class="loading-content">
            <div class="loading-spinner"></div>
            <h4 class="mb-3">Processing Your File...</h4>
            <div class="progress mb-3" style="height: 30px;">
                <div class="progress-bar progress-bar-striped progress-bar-animated bg-primary" 
                    role="progressbar" 
                    style="width: 100%"
                    id="progressBar">
                </div>
            </div>
            <div class="loading-stage" id="loadingStage">
                <i class="fas fa-upload"></i> Uploading file...
            </div>
            <p class="text-muted mt-3 mb-0">
                <small>This may take a few moments depending on file size.</small>
            </p>
        </div>
    </div>

    <div class="container-fluid mt-perso">
        <div class="row">
            <div class="col-md-8 offset-md-2">

                <cfif structKeyExists(url, "batchDeleted") AND val(url.batchDeleted) EQ 1>
                    <div class="alert alert-success alert-dismissible fade show" role="alert">
                        <i class="fas fa-check-circle"></i> Batch deleted successfully.
                        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                    </div>
                </cfif>

                <cfif len(deleteBatchError)>
                    <div class="alert alert-danger alert-dismissible fade show" role="alert">
                        <strong>Delete failed:</strong>
                        <cfoutput>#encodeForHTML(deleteBatchError)#</cfoutput>
                        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                    </div>
                </cfif>
                
                <cfif structKeyExists(form, "uploadFile")>
                    <cftry>
                        <cfinvoke
                            component="#application.query#"
                            method="processUpload"
                            returnvariable="uploadResult">
                        </cfinvoke>
                        
                        <cfif uploadResult.success>
                            <div class="alert alert-success" role="alert">
                                <h5 class="alert-heading"><i class="fas fa-check-circle"></i> Import Successful!</h5>
                                <hr>
                                <cfoutput>
                                    <p><strong>Batch ID:</strong> #uploadResult.batchID#</p>
                                    <p><strong>File Name:</strong> #uploadResult.fileName#</p>
                                    <p><strong>Total Records:</strong> #uploadResult.totalRecords#</p>
                                    <p><strong>Matched Records:</strong> #uploadResult.matchedRecords#</p>
                                    <p><strong>Unmatched Records:</strong> #uploadResult.unmatchedRecords#</p>
                                    <p><strong>Match Rate:</strong> #numberFormat(uploadResult.matchRate, "99.9")#%</p>
                                    <hr>
                                    <div class="d-grid gap-2">
                                        <a href="dashboard.cfm?batch=#uploadResult.batchID#" class="btn btn-primary btn-lg">
                                            <i class="fas fa-chart-line"></i> View Dashboard
                                        </a>
                                        <a href="export.cfm?batch=#uploadResult.batchID#" class="btn btn-success">
                                            <i class="fas fa-download"></i> Export Data
                                        </a>
                                    </div>
                                </cfoutput>
                            </div>
                        <cfelse>
                            <div class="alert alert-danger" role="alert">
                                <h5 class="alert-heading"><i class="fas fa-exclamation-triangle"></i> Import Failed</h5>
                                <cfoutput>
                                    <p><strong>Error:</strong> #uploadResult.errorMessage#</p>
                                </cfoutput>
                            </div>
                        </cfif>
                        
                        <cfcatch type="any">
                            <div class="alert alert-danger">
                                <h4>Error During Processing</h4>
                                <cfoutput>
                                    <p><strong>Type:</strong> #cfcatch.type#</p>
                                    <p><strong>Message:</strong> #cfcatch.message#</p>
                                    <p><strong>Detail:</strong> #cfcatch.detail#</p>
                                </cfoutput>
                            </div>
                        </cfcatch>
                    </cftry>
                </cfif>

                <div class="card shadow">
                    <div class="card-header bg-primary text-white">
                        <h4><i class="fas fa-file-excel"></i> Import Timekeeping Data</h4>
                    </div>
                    <div class="card-body">
                        <form action="index.cfm" method="post" enctype="multipart/form-data" id="uploadForm">
                            <div class="mb-3">
                                <label for="uploadFile" class="form-label">
                                    Select Excel File (.xlsx)
                                </label>
                                <input type="file" 
                                    class="form-control" 
                                    id="uploadFile" 
                                    name="uploadFile" 
                                    accept=".xlsx,.xls" 
                                    required>
                                <div class="form-text">
                                    Upload your timekeeping report Excel file.
                                </div>
                            </div>

                            <div class="mb-3">
                                <label for="importedBy" class="form-label">
                                    Imported By
                                </label>
                                <input type="text" 
                                    class="form-control" 
                                    id="importedBy" 
                                    name="importedBy" 
                                    placeholder="Your name">
                            </div>

                            <div class="mb-3">
                                <label for="notes" class="form-label">
                                    Notes (Optional)
                                </label>
                                <textarea class="form-control" 
                                        id="notes" 
                                        name="notes" 
                                        rows="3" 
                                        placeholder="Any notes about this import..."></textarea>
                            </div>

                            <button type="submit" class="btn btn-primary btn-lg w-100" id="submitBtn">
                                <i class="fas fa-upload"></i> Upload and Process
                            </button>
                        </form>
                    </div>
                </div>

                <!--- Recent Imports with Pagination --->
                <div class="card shadow mt-4">
                    <div class="card-header bg-secondary text-white">
                        <h5><i class="fas fa-history"></i> Recent Imports</h5>
                    </div>
                    <div class="card-body">                            
                        <cfset totalPages = ceiling(recentImportsCount.TotalCount / pageSize)>

                        <cfif recentImports.recordCount GT 0>
                            <div class="table-responsive">
                                <table class="table table-hover">
                                    <thead>
                                        <tr>
                                            <th>Batch ID</th>
                                            <th>File Name</th>
                                            <th>Import Date</th>
                                            <th>Records</th>
                                            <th>Match Rate</th>
                                            <th>Status</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <cfoutput query="recentImports">
                                            <tr>
                                                <td>###BatchID#</td>
                                                <td>#FileName#</td>
                                                <td>#dateFormat(ImportDate, "yyyy-mm-dd")# #timeFormat(ImportDate, "HH:mm")#</td>
                                                <td>#TotalRecords#</td>
                                                <td>
                                                    <cfif val(TotalRecords) GT 0>
                                                        <cfset matchRate = (
                                                            val(MatchedRecords) / val(TotalRecords)
                                                        ) * 100>

                                                        <span class="badge bg-<cfif matchRate GTE 90>success<cfelseif matchRate GTE 70>warning<cfelse>danger</cfif>">
                                                            #numberFormat(matchRate, "99.9")#%
                                                        </span>
                                                    <cfelse>
                                                        N/A
                                                    </cfif>
                                                </td>
                                                <td>
                                                    <span class="badge bg-<cfif ProcessingStatus EQ 'Completed'>success<cfelseif ProcessingStatus EQ 'Processing'>warning<cfelse>danger</cfif>">
                                                        #ProcessingStatus#
                                                    </span>
                                                </td>
                                                <td class="text-nowrap">
                                                    <a href="dashboard.cfm?batch=#BatchID#" class="btn btn-sm btn-outline-primary" title="View Dashboard">
                                                        <i class="fas fa-eye"></i>
                                                    </a>
                                                    <a href="export.cfm?batch=#BatchID#" class="btn btn-sm btn-outline-success" title="Export">
                                                        <i class="fas fa-download"></i>
                                                    </a>
                                                    <form action="index.cfm?page=#currentPage#" method="post" class="d-inline" onsubmit="return confirm('Delete batch ###BatchID# (#jsStringFormat(FileName)#) and all of its imported data? This cannot be undone.');">
                                                        <input type="hidden" name="deleteBatchID" value="#BatchID#">
                                                        <button type="submit" name="deleteBatchButton" value="1" class="btn btn-sm btn-outline-danger" title="Delete Batch">
                                                            <i class="fas fa-trash"></i>
                                                        </button>
                                                    </form>
                                                </td>
                                            </tr>
                                        </cfoutput>
                                    </tbody>
                                </table>
                            </div>
                            
                            <!--- Pagination Controls --->
                            <cfif totalPages GT 1>
                                <nav aria-label="Page navigation">
                                    <ul class="pagination justify-content-center">
                                        <cfoutput>
                                            <!--- Previous --->
                                            <li class="page-item <cfif currentPage EQ 1>disabled</cfif>">
                                                <a class="page-link" href="index.cfm?page=#currentPage - 1#">Previous</a>
                                            </li>
                                            
                                            <!--- Page numbers --->
                                            <cfloop from="1" to="#totalPages#" index="p">
                                                <cfif p EQ currentPage>
                                                    <li class="page-item active">
                                                        <span class="page-link">#p#</span>
                                                    </li>
                                                <cfelseif abs(p - currentPage) LT 3 OR p EQ 1 OR p EQ totalPages>
                                                    <li class="page-item">
                                                        <a class="page-link" href="index.cfm?page=#p#">#p#</a>
                                                    </li>
                                                <cfelseif abs(p - currentPage) EQ 3>
                                                    <li class="page-item disabled">
                                                        <span class="page-link">...</span>
                                                    </li>
                                                </cfif>
                                            </cfloop>
                                            
                                            <!--- Next --->
                                            <li class="page-item <cfif currentPage EQ totalPages>disabled</cfif>">
                                                <a class="page-link" href="index.cfm?page=#currentPage + 1#">Next</a>
                                            </li>
                                        </cfoutput>
                                    </ul>
                                </nav>
                                
                                <cfoutput>
                                    <p class="text-center text-muted">
                                        Showing page #currentPage# of #totalPages# 
                                        (#recentImportsCount.TotalCount# total imports)
                                    </p>
                                </cfoutput>
                            </cfif>
                        <cfelse>
                            <p class="text-muted">No imports yet. Upload your first file above!</p>
                        </cfif>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="/PMSD/SATS/Timetracking/resources/js/loading.js"></script>
    <script src="/PMSD/SATS/Timetracking/resources/bootstrap/bootstrap/js/bootstrap.bundle.min.js"></script>
</body>
</html>
</cfif>