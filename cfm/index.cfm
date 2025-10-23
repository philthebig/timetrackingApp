<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Timekeeping Import Tool</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-dark bg-primary">
        <div class="container-fluid">
            <span class="navbar-brand mb-0 h1">
                <i class="fas fa-clock"></i> Timekeeping Import & Analytics
            </span>
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
                                    <a href="dashboard.cfm?batch=#uploadResult.batchID#" class="btn btn-primary">
                                        View Dashboard <i class="fas fa-arrow-right"></i>
                                    </a>
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
                        <form action="index.cfm" method="post" enctype="multipart/form-data">
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

                            <button type="submit" class="btn btn-primary btn-lg w-100">
                                <i class="fas fa-upload"></i> Upload and Process
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
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
        
        <!--- Read Excel file - Using your proven approach with multiple fallbacks --->
        <cfset var excelData = "">
        <cfset var sheetName = "Data">
        
        <!--- Try reading with sheetname attribute first --->
        <cftry>
            <cfspreadsheet action="read" 
                          src="#filePath#" 
                          query="excelData" 
                          sheetname="#sheetName#"
                          headerrow="1"
                          excludeHeaderRow="true">
            
            <cflog file="timekeeping_import" 
                   text="Batch #batchID#: Read using sheetname=#sheetName#"
                   type="information">
            
            <cfcatch type="any">
                <!--- Fallback 1: Try sheet index 1 --->
                <cftry>
                    <cfspreadsheet action="read" 
                                  src="#filePath#" 
                                  query="excelData" 
                                  sheet="1"
                                  headerrow="1"
                                  excludeHeaderRow="true">
                    
                    <cflog file="timekeeping_import" 
                           text="Batch #batchID#: Read using sheet=1 (first sheet)"
                           type="information">
                    
                    <cfcatch type="any">
                        <!--- Fallback 2: Try without sheet specification --->
                        <cfspreadsheet action="read" 
                                      src="#filePath#" 
                                      query="excelData" 
                                      headerrow="1"
                                      excludeHeaderRow="true">
                        
                        <cflog file="timekeeping_import" 
                               text="Batch #batchID#: Read using default (no sheet specified)"
                               type="information">
                    </cfcatch>
                </cftry>
            </cfcatch>
        </cftry>
        
        <!--- Verify we got data --->
        <cfif NOT isQuery(excelData) OR excelData.recordCount EQ 0>
            <cfthrow message="No data found in Excel file. Please check the file format.">
        </cfif>
        
        <!--- Log columns found --->
        <cflog file="timekeeping_import" 
               text="Batch #batchID#: Found columns: #excelData.columnList#"
               type="information">
        
        <!--- Process Excel data --->
        <cfset var recordCount = 0>
        <cfset var skippedCount = 0>
        
        <!--- Find Contact Name column (handles underscore conversion) --->
        <cfset var contactNameCol = "">
        <cfset var columns = listToArray(excelData.columnList)>
        
        <cfloop array="#columns#" index="colName">
            <cfif compareNoCase(colName, "Contact_Name") EQ 0 OR 
                  compareNoCase(colName, "Contact Name") EQ 0 OR
                  findNoCase("contact", colName) GT 0>
                <cfset contactNameCol = colName>
                <cfbreak>
            </cfif>
        </cfloop>
        
        <cfif contactNameCol EQ "">
            <!--- Fallback to column 5 if we can't find it by name --->
            <cfif listLen(excelData.columnList) GTE 5>
                <cfset contactNameCol = listGetAt(excelData.columnList, 5)>
            <cfelse>
                <cfthrow message="Could not find Contact Name column in Excel file">
            </cfif>
        </cfif>
        
        <!--- Find Hours column --->
        <cfset var hoursCol = "">
        <cfloop array="#columns#" index="colName">
            <cfif findNoCase("hour", colName) GT 0 OR 
                  findNoCase("recorded", colName) GT 0>
                <cfset hoursCol = colName>
                <cfbreak>
            </cfif>
        </cfloop>
        
        <cfif hoursCol EQ "">
            <cfset hoursCol = listLast(excelData.columnList)>
        </cfif>
        
        <!--- Log column mapping --->
        <cflog file="timekeeping_import" 
               text="Batch #batchID#: Using Contact column: #contactNameCol#, Hours column: #hoursCol#"
               type="information">
        
        <!--- Process each row --->
        <cfloop query="excelData">
            <cfset var clientContact = "">
            <cfset var clientEmail = "">
            <cfset var firstName = "">
            <cfset var lastName = "">
            <cfset var hours = 0>
            
            <cftry>
                <!--- Get Contact Name value --->
                <cfif contactNameCol NEQ "" AND isDefined("excelData.#contactNameCol#")>
                    <cfset clientContact = trim(excelData[contactNameCol][currentRow])>
                </cfif>
                
                <!--- Get Hours value --->
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
            
            <!--- Extract email and name from contact field --->
            <cfif clientContact NEQ "">
                <!--- Extract email --->
                <cfset var emailMatch = reMatchNoCase("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", clientContact)>
                <cfif arrayLen(emailMatch) GT 0>
                    <cfset clientEmail = lCase(trim(emailMatch[1]))>
                    
                    <!--- Extract name: "LastName, FirstName [...]" format --->
                    <!--- Remove everything after [ --->
                    <cfset var nameStr = clientContact>
                    <cfif find("[", nameStr) GT 0>
                        <cfset nameStr = left(nameStr, find("[", nameStr) - 1)>
                    </cfif>
                    <cfset nameStr = trim(nameStr)>
                    
                    <!--- Split by comma --->
                    <cfif find(",", nameStr) GT 0>
                        <cfset var nameParts = listToArray(nameStr, ",")>
                        <cfif arrayLen(nameParts) GTE 2>
                            <cfset lastName = trim(nameParts[1])>
                            <cfset firstName = trim(nameParts[2])>
                        </cfif>
                    </cfif>
                </cfif>
            </cfif>
            
            <!--- Only insert if we have an email --->
            <cfif clientEmail NEQ "">
                <cfquery datasource="PMSD_SATS">
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
        
        <!--- Log processing summary --->
        <cflog file="timekeeping_import" 
               text="Batch #batchID#: Processed #recordCount# records, skipped #skippedCount# rows"
               type="information">
        
        <!--- Update batch with total records --->
        <cfquery datasource="PMSD_SATS">
            UPDATE dbo.ImportBatch
            SET TotalRecords = <cfqueryparam value="#recordCount#" cfsqltype="cf_sql_integer">
            WHERE BatchID = <cfqueryparam value="#batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <!--- Process and enrich data --->
        <cfstoredproc procedure="sp_EnrichTimekeepingData" datasource="PMSD_SATS">
            <cfprocparam value="#batchID#" cfsqltype="cf_sql_integer">
            <cfprocresult name="enrichResult">
        </cfstoredproc>
        
        <!--- Get final results --->
        <cfquery name="finalResults" datasource="PMSD_SATS">
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
        <cfif finalResults.TotalRecords GT 0>
            <cfset result.matchRate = (finalResults.MatchedRecords / finalResults.TotalRecords) * 100>
        <cfelse>
            <cfset result.matchRate = 0>
        </cfif>
        
        <cfcatch type="any">
            <cfset result.success = false>
            <cfset result.errorMessage = cfcatch.message & " - " & cfcatch.detail>
            
            <!--- Log error --->
            <cflog file="timekeeping_errors" 
                   text="Error: #cfcatch.message# - #cfcatch.detail#"
                   type="error">
        </cfcatch>
    </cftry>
    
    <cfreturn result>
</cffunction>
