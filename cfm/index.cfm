<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Timekeeping Import Tool</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <link href="css/styles.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-dark bg-primary">
        <div class="container-fluid">
            <span class="navbar-brand mb-0 h1">
                <i class="fas fa-clock"></i> Timekeeping Import & Analytics
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

    <div class="container mt-5">
        <div class="row">
            <div class="col-md-8 offset-md-2">
                <div class="card shadow">
                    <div class="card-header bg-primary text-white">
                        <h4><i class="fas fa-file-excel"></i> Import Timekeeping Data</h4>
                    </div>
                    <div class="card-body">
                        <cfif structKeyExists(form, "uploadFile")>
                            <cfset uploadResult = processUpload()>
                            
                            <cfif uploadResult.success>
                                <div class="alert alert-success" role="alert">
                                    <h5 class="alert-heading"><i class="fas fa-check-circle"></i> Import Successful!</h5>
                                    <hr>
                                    <p><strong>Batch ID:</strong> #uploadResult.batchID#</p>
                                    <p><strong>File Name:</strong> #uploadResult.fileName#</p>
                                    <p><strong>Total Records:</strong> #uploadResult.totalRecords#</p>
                                    <p><strong>Matched Records:</strong> #uploadResult.matchedRecords#</p>
                                    <p><strong>Unmatched Records:</strong> #uploadResult.unmatchedRecords#</p>
                                    <p><strong>Match Rate:</strong> #numberFormat(uploadResult.matchRate, "99.9")#%</p>
                                    <hr>
                                    <a href="dashboard.cfm?batch=#uploadResult.batchID#" class="btn btn-primary">
                                        View Dashboard <i class="fas fa-arrow-right"></i>
                                    </a>
                                </div>
                            <cfelse>
                                <div class="alert alert-danger" role="alert">
                                    <h5 class="alert-heading"><i class="fas fa-exclamation-triangle"></i> Import Failed</h5>
                                    <p>#uploadResult.errorMessage#</p>
                                </div>
                            </cfif>
                        </cfif>

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
                                    Upload your timekeeping report Excel file. The system will automatically match clients with directorate information.
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
                                       placeholder="Your name" 
                                       value="">
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

                        <div id="processingIndicator" class="text-center mt-4" style="display: none;">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Processing...</span>
                            </div>
                            <p class="mt-2">Processing your file... Please wait.</p>
                        </div>
                    </div>
                </div>

                <!-- Recent Imports -->
                <div class="card shadow mt-4">
                    <div class="card-header bg-secondary text-white">
                        <h5><i class="fas fa-history"></i> Recent Imports</h5>
                    </div>
                    <div class="card-body">
                        <cfquery name="recentImports" datasource="yourDatasource">
                            SELECT TOP 10
                                BatchID,
                                FileName,
                                ImportDate,
                                TotalRecords,
                                MatchedRecords,
                                UnmatchedRecords,
                                ProcessingStatus,
                                ImportedBy
                            FROM dbo.ImportBatch
                            ORDER BY ImportDate DESC
                        </cfquery>

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
                                            <th>Action</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <cfoutput query="recentImports">
                                            <tr>
                                                <td>##BatchID##</td>
                                                <td>#FileName#</td>
                                                <td>#dateFormat(ImportDate, "yyyy-mm-dd")# #timeFormat(ImportDate, "HH:mm")#</td>
                                                <td>#TotalRecords#</td>
                                                <td>
                                                    <cfif TotalRecords GT 0>
                                                        <cfset matchRate = (MatchedRecords / TotalRecords) * 100>
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
                                                <td>
                                                    <a href="dashboard.cfm?batch=#BatchID#" class="btn btn-sm btn-outline-primary">
                                                        View <i class="fas fa-eye"></i>
                                                    </a>
                                                </td>
                                            </tr>
                                        </cfoutput>
                                    </tbody>
                                </table>
                            </div>
                        <cfelse>
                            <p class="text-muted">No imports yet. Upload your first file above!</p>
                        </cfif>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="js/upload.js"></script>
</body>
</html>

<cffunction name="processUpload" returntype="struct">
    <cfset var result = structNew()>
    <cfset result.success = false>
    
    <cftry>
        <!--- Upload file --->
        <cffile action="upload"
                fileField="uploadFile"
                destination="#expandPath('./uploads/')#"
                nameConflict="makeUnique"
                result="uploadInfo">
        
        <cfset var filePath = uploadInfo.serverDirectory & "/" & uploadInfo.serverFile>
        
        <!--- Create import batch record --->
        <cfquery name="createBatch" datasource="yourDatasource" result="batchResult">
            INSERT INTO dbo.ImportBatch (FileName, ImportedBy, Notes, TotalRecords)
            VALUES (
                <cfqueryparam value="#uploadInfo.clientFile#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#form.importedBy#" cfsqltype="cf_sql_varchar" null="#trim(form.importedBy) EQ ''#">,
                <cfqueryparam value="#form.notes#" cfsqltype="cf_sql_varchar" null="#trim(form.notes) EQ ''#">,
                0
            )
            SELECT SCOPE_IDENTITY() AS BatchID
        </cfquery>
        
        <cfset var batchID = batchResult.IDENTITYCOL>
        
        <!--- Read Excel file --->
        <cfspreadsheet action="read" 
                      src="#filePath#" 
                      query="excelData" 
                      headerrow="3"
                      excludeHeaderRow="true">
        
        <!--- Process Excel data --->
        <cfset var recordCount = 0>
        <cfset var currentCategory = "">
        <cfset var currentProject = "">
        
        <cfloop query="excelData">
            <cfset var rowLabel = trim(excelData["col_1"][currentRow])>
            <cfset var hours = excelData["col_2"][currentRow]>
            
            <!--- Skip empty rows --->
            <cfif rowLabel EQ "" OR NOT isNumeric(hours)>
                <cfcontinue>
            </cfif>
            
            <!--- Determine if this is a category, project, or client --->
            <cfset var isEmail = findNoCase("@", rowLabel) GT 0>
            
            <cfif isEmail>
                <!--- This is a client row --->
                <cfset var emailMatch = reMatchNoCase("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", rowLabel)>
                <cfset var clientEmail = "">
                <cfset var clientName = "">
                <cfset var firstName = "">
                <cfset var lastName = "">
                
                <cfif arrayLen(emailMatch) GT 0>
                    <cfset clientEmail = emailMatch[1]>
                    
                    <!--- Extract name --->
                    <cfset var nameMatch = reMatchNoCase("([A-Z][a-z]+),\s*([A-Z][a-z]+)", rowLabel)>
                    <cfif arrayLen(nameMatch) GT 0>
                        <cfset var nameParts = listToArray(nameMatch[1], ",")>
                        <cfif arrayLen(nameParts) EQ 2>
                            <cfset lastName = trim(nameParts[1])>
                            <cfset firstName = trim(nameParts[2])>
                        </cfif>
                    </cfif>
                    
                    <!--- Insert into staging --->
                    <cfquery datasource="yourDatasource">
                        INSERT INTO dbo.TimekeepingStaging (
                            ImportBatchID,
                            RowNumber,
                            Category,
                            ProjectMatter,
                            ClientContact,
                            ClientEmail,
                            ClientFirstName,
                            ClientLastName,
                            RecordedHours
                        ) VALUES (
                            <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">,
                            <cfqueryparam value="#currentRow#" cfsqltype="cf_sql_integer">,
                            <cfqueryparam value="#currentCategory#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#currentProject#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#rowLabel#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#clientEmail#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#firstName#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#lastName#" cfsqltype="cf_sql_varchar">,
                            <cfqueryparam value="#hours#" cfsqltype="cf_sql_decimal">
                        )
                    </cfquery>
                    <cfset recordCount = recordCount + 1>
                </cfif>
            <cfelseif hours GT 100>
                <!--- Likely a category (high hours) --->
                <cfset currentCategory = rowLabel>
            <cfelse>
                <!--- Likely a project --->
                <cfset currentProject = rowLabel>
            </cfif>
        </cfloop>
        
        <!--- Update batch with total records --->
        <cfquery datasource="yourDatasource">
            UPDATE dbo.ImportBatch
            SET TotalRecords = <cfqueryparam value="#recordCount#" cfsqltype="cf_sql_integer">
            WHERE BatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <!--- Process and enrich data --->
        <cfstoredproc procedure="sp_EnrichTimekeepingData" datasource="yourDatasource">
            <cfprocparam value="#batchID#" cfsqltype="cf_sql_integer">
            <cfprocresult name="enrichResult">
        </cfstoredproc>
        
        <!--- Get final results --->
        <cfquery name="finalResults" datasource="yourDatasource">
            SELECT 
                MatchedRecords,
                UnmatchedRecords,
                TotalRecords
            FROM dbo.ImportBatch
            WHERE BatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <!--- Clean up uploaded file --->
        <cffile action="delete" file="#filePath#">
        
        <!--- Set success result --->
        <cfset result.success = true>
        <cfset result.batchID = batchID>
        <cfset result.fileName = uploadInfo.clientFile>
        <cfset result.totalRecords = finalResults.TotalRecords>
        <cfset result.matchedRecords = finalResults.MatchedRecords>
        <cfset result.unmatchedRecords = finalResults.UnmatchedRecords>
        <cfset result.matchRate = (finalResults.MatchedRecords / finalResults.TotalRecords) * 100>
        
        <cfcatch type="any">
            <cfset result.success = false>
            <cfset result.errorMessage = cfcatch.message & " - " & cfcatch.detail>
        </cfcatch>
    </cftry>
    
    <cfreturn result>
</cffunction>
