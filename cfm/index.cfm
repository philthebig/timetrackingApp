<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Timekeeping Import Tool</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <link href="../css/styles.css" rel="stylesheet">
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
                <a href="dashboard.cfm" class="btn btn-outline-light me-2">
                    <i class="fas fa-chart-line"></i> Dashboard
                </a>
                <a href="export.cfm" class="btn btn-outline-light">
                    <i class="fas fa-download"></i> Export
                </a>
            </div>
        </div>
    </nav>

    <div class="container mt-5">
        <div class="row">
            <div class="col-md-8 offset-md-2">
                
                <cfif structKeyExists(form, "uploadFile")>
                    <cftry>
                        <cfset uploadResult = processUpload()>
                        
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

                        <div id="processingIndicator" class="text-center mt-4" style="display: none;">
                            <div class="spinner-border text-primary" role="status">
                                <span class="visually-hidden">Processing...</span>
                            </div>
                            <p class="mt-2">Processing your file... Please wait.</p>
                        </div>
                    </div>
                </div>

                <!--- Recent Imports with Pagination --->
                <div class="card shadow mt-4">
                    <div class="card-header bg-secondary text-white">
                        <h5><i class="fas fa-history"></i> Recent Imports</h5>
                    </div>
                    <div class="card-body">
                        <cfparam name="url.page" default="1">
                        <cfset currentPage = val(url.page)>
                        <cfset pageSize = 10>
                        <cfset startRow = (currentPage - 1) * pageSize + 1>
                        
                        <cfquery name="recentImportsCount" datasource="PMSD_SATS">
                            SELECT COUNT(*) AS TotalCount
                            FROM dbo.ImportBatch
                        </cfquery>
                        
                        <cfset totalPages = ceiling(recentImportsCount.TotalCount / pageSize)>
                        
                        <cfquery name="recentImports" datasource="PMSD_SATS">
                            SELECT 
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
                            OFFSET <cfqueryparam value="#startRow - 1#" cfsqltype="cf_sql_integer"> ROWS
                            FETCH NEXT <cfqueryparam value="#pageSize#" cfsqltype="cf_sql_integer"> ROWS ONLY
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
                                            <th>Actions</th>
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
                                                    <a href="dashboard.cfm?batch=#BatchID#" class="btn btn-sm btn-outline-primary" title="View Dashboard">
                                                        <i class="fas fa-eye"></i>
                                                    </a>
                                                    <a href="export.cfm?batch=#BatchID#" class="btn btn-sm btn-outline-success" title="Export">
                                                        <i class="fas fa-download"></i>
                                                    </a>
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

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="../js/upload.js"></script>
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
        <cfquery name="createBatch" datasource="PMSD_SATS">
            INSERT INTO dbo.ImportBatch (FileName, ImportedBy, Notes, TotalRecords)
            VALUES (
                <cfqueryparam value="#uploadInfo.clientFile#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#form.importedBy#" cfsqltype="cf_sql_varchar" null="#trim(form.importedBy) EQ ''#">,
                <cfqueryparam value="#form.notes#" cfsqltype="cf_sql_varchar" null="#trim(form.notes) EQ ''#">,
                0
            );
            SELECT SCOPE_IDENTITY() AS BatchID;
        </cfquery>
        
        <!--- Get BatchID --->
        <cfif createBatch.recordCount GT 0>
            <cfset var batchID = createBatch.BatchID[1]>
        <cfelse>
            <cfthrow message="Failed to retrieve BatchID after insert.">
        </cfif>
        
        <!--- Read Excel file - Triple fallback --->
        <cfset var excelData = "">
        <cfset var sheetName = "Data">
        
        <cftry>
            <cfspreadsheet action="read" src="#filePath#" query="excelData" sheetname="#sheetName#" headerrow="1" excludeHeaderRow="true">
            <cfcatch type="any">
                <cftry>
                    <cfspreadsheet action="read" src="#filePath#" query="excelData" sheet="1" headerrow="1" excludeHeaderRow="true">
                    <cfcatch type="any">
                        <cfspreadsheet action="read" src="#filePath#" query="excelData" headerrow="1" excludeHeaderRow="true">
                    </cfcatch>
                </cftry>
            </cfcatch>
        </cftry>
        
        <cfif NOT isQuery(excelData) OR excelData.recordCount EQ 0>
            <cfthrow message="No data found in Excel file.">
        </cfif>
        
        <!--- Find Contact Name column --->
        <cfset var contactNameCol = "">
        <cfset var columns = listToArray(excelData.columnList)>
        
        <cfloop array="#columns#" index="colName">
            <cfif compareNoCase(colName, "Contact_Name") EQ 0 OR compareNoCase(colName, "ContactName") EQ 0 OR findNoCase("contact", colName) GT 0>
                <cfset contactNameCol = colName>
                <cfbreak>
            </cfif>
        </cfloop>
        
        <cfif contactNameCol EQ "" AND listLen(excelData.columnList) GTE 5>
            <cfset contactNameCol = listGetAt(excelData.columnList, 5)>
        </cfif>
        
        <!--- Find Hours column --->
        <cfset var hoursCol = "">
        <cfloop array="#columns#" index="colName">
            <cfif findNoCase("hour", colName) GT 0 OR findNoCase("recorded", colName) GT 0>
                <cfset hoursCol = colName>
                <cfbreak>
            </cfif>
        </cfloop>
        
        <cfif hoursCol EQ "">
            <cfset hoursCol = listLast(excelData.columnList)>
        </cfif>
        
        <!--- Process each row --->
        <cfset var recordCount = 0>
        <cfset var skippedCount = 0>
        
        <cfloop query="excelData">
            <cfset var clientContact = "">
            <cfset var clientEmail = "">
            <cfset var firstName = "">
            <cfset var lastName = "">
            <cfset var hours = 0>
            
            <cftry>
                <cfif contactNameCol NEQ "" AND isDefined("excelData.#contactNameCol#")>
                    <cfset clientContact = trim(excelData[contactNameCol][currentRow])>
                </cfif>
                
                <cfif hoursCol NEQ "" AND isDefined("excelData.#hoursCol#")>
                    <cfset var hoursValue = excelData[hoursCol][currentRow]>
                    <cfif isNumeric(hoursValue)>
                        <cfset hours = hoursValue>
                    </cfif>
                </cfif>
                
                <cfcatch>
                    <cfset skippedCount = skippedCount + 1>
                    <cfcontinue>
                </cfcatch>
            </cftry>
            
            <!--- Extract email and name --->
            <cfif clientContact NEQ "">
                <cfset var emailMatch = reMatchNoCase("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", clientContact)>
                <cfif arrayLen(emailMatch) GT 0>
                    <cfset clientEmail = lCase(trim(emailMatch[1]))>
                    
                    <cfset var nameStr = clientContact>
                    <cfif find("[", nameStr) GT 0>
                        <cfset nameStr = left(nameStr, find("[", nameStr) - 1)>
                    </cfif>
                    <cfset nameStr = trim(nameStr)>
                    
                    <cfif find(",", nameStr) GT 0>
                        <cfset var nameParts = listToArray(nameStr, ",")>
                        <cfif arrayLen(nameParts) GTE 2>
                            <cfset lastName = trim(nameParts[1])>
                            <cfset firstName = trim(nameParts[2])>
                        </cfif>
                    </cfif>
                </cfif>
            </cfif>
            
            <cfif clientEmail NEQ "">
                <cfquery datasource="PMSD_SATS">
                    INSERT INTO dbo.TimekeepingStaging (ImportBatchID, RowNumber, Category, ProjectMatter, ClientContact, ClientEmail, ClientFirstName, ClientLastName, RecordedHours)
                    VALUES (
                        <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">,
                        <cfqueryparam value="#currentRow#" cfsqltype="cf_sql_integer">,
                        <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#clientContact#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#clientEmail#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#firstName#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#lastName#" cfsqltype="cf_sql_varchar">,
                        <cfqueryparam value="#hours#" cfsqltype="cf_sql_decimal">
                    )
                </cfquery>
                <cfset recordCount = recordCount + 1>
            <cfelse>
                <cfset skippedCount = skippedCount + 1>
            </cfif>
        </cfloop>
        
        <cfquery datasource="PMSD_SATS">
            UPDATE dbo.ImportBatch SET TotalRecords = <cfqueryparam value="#recordCount#" cfsqltype="cf_sql_integer"> WHERE BatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <!--- Inline enrichment --->
        <cfquery datasource="PMSD_SATS">
            INSERT INTO dbo.TimekeepingEnriched (ImportBatchID, Category, ProjectMatter, ClientContact, ClientEmail, ClientFirstName, ClientLastName, ClientUserID, RecordedHours, DirectorateNameE, DirectorateNameF, DirectorateAcronymE, DirectorateAcronymF, DirectorateID, DivisionNameE, DivisionNameF, DivisionAcronymE, DivisionAcronymF, DivisionID, BranchNameE, BranchNameF, BranchAcronymE, BranchAcronymF, BranchID, SectionNameE, SectionNameF, SectionAcronymE, SectionAcronymF, SectionID, ClientPhone, PositionLevel, IsManager, MatchStatus, ProcessedDate)
            SELECT s.ImportBatchID, s.Category, s.ProjectMatter, s.ClientContact, s.ClientEmail, s.ClientFirstName, s.ClientLastName, u.userID, s.RecordedHours, u.DirectorateNameE, u.DirectorateNameF, u.DirectorateAcronymE, u.DirectorateAcronymF, u.DirectorateID, u.DivisionNameE, u.DivisionNameF, u.DivisionAcronymE, u.DivisionAcronymF, u.DivisionID, u.BranchNameE, u.BranchNameF, u.BranchAcronymE, u.BranchAcronymF, u.BranchID, u.SectionNameE, u.SectionNameF, u.SectionAcronymE, u.SectionAcronymF, u.SectionID, u.phone, u.PositionLevel, u.IsManager, 'Matched', GETDATE()
            FROM dbo.TimekeepingStaging s
            LEFT JOIN [BRANCH_Directory].[dbo].[vUserInfo] u ON LOWER(LTRIM(RTRIM(s.ClientEmail))) = LOWER(LTRIM(RTRIM(u.userID))) OR (LOWER(LTRIM(RTRIM(s.ClientFirstName))) = LOWER(LTRIM(RTRIM(u.firstName))) AND LOWER(LTRIM(RTRIM(s.ClientLastName))) = LOWER(LTRIM(RTRIM(u.lastName))))
            WHERE s.ImportBatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer"> AND s.ProcessingStatus = 'Pending' AND u.userID IS NOT NULL
        </cfquery>
        
        <cfquery name="matchedCount" datasource="PMSD_SATS">
            SELECT COUNT(*) AS MatchCount FROM dbo.TimekeepingEnriched WHERE ImportBatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <cfquery datasource="PMSD_SATS">
            UPDATE s SET ProcessingStatus = 'Matched' FROM dbo.TimekeepingStaging s WHERE s.ImportBatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer"> AND s.ProcessingStatus = 'Pending' AND EXISTS (SELECT 1 FROM dbo.TimekeepingEnriched e WHERE e.ImportBatchID = s.ImportBatchID AND e.ClientEmail = s.ClientEmail)
        </cfquery>
        
        <cfquery datasource="PMSD_SATS">
            INSERT INTO dbo.UnmatchedClients (ImportBatchID, ClientEmail, ClientFirstName, ClientLastName, ClientContact, RecordedHours)
            SELECT s.ImportBatchID, s.ClientEmail, s.ClientFirstName, s.ClientLastName, s.ClientContact, s.RecordedHours FROM dbo.TimekeepingStaging s WHERE s.ImportBatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer"> AND s.ProcessingStatus = 'Pending'
        </cfquery>
        
        <cfquery name="unmatchedCount" datasource="PMSD_SATS">
            SELECT COUNT(*) AS UnmatchCount FROM dbo.UnmatchedClients WHERE ImportBatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <cfquery datasource="PMSD_SATS">
            UPDATE s SET ProcessingStatus = 'Unmatched', ErrorMessage = 'No matching user found in directory' FROM dbo.TimekeepingStaging s WHERE s.ImportBatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer"> AND s.ProcessingStatus = 'Pending'
        </cfquery>
        
        <cfquery datasource="PMSD_SATS">
            UPDATE dbo.ImportBatch SET MatchedRecords = <cfqueryparam value="#matchedCount.MatchCount#" cfsqltype="cf_sql_integer">, UnmatchedRecords = <cfqueryparam value="#unmatchedCount.UnmatchCount#" cfsqltype="cf_sql_integer">, ProcessingStatus = 'Completed', CompletedDate = GETDATE() WHERE BatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <cffile action="delete" file="#filePath#">
        
        <cfset result.success = true>
        <cfset result.batchID = batchID>
        <cfset result.fileName = uploadInfo.clientFile>
        <cfset result.totalRecords = recordCount>
        <cfset result.matchedRecords = matchedCount.MatchCount>
        <cfset result.unmatchedRecords = unmatchedCount.UnmatchCount>
        <cfif recordCount GT 0>
            <cfset result.matchRate = (matchedCount.MatchCount / recordCount) * 100>
        <cfelse>
            <cfset result.matchRate = 0>
        </cfif>
        
        <cfcatch type="any">
            <cfset result.success = false>
            <cfset result.errorMessage = cfcatch.message & " - " & cfcatch.detail>
        </cfcatch>
    </cftry>
    
    <cfreturn result>
</cffunction>
