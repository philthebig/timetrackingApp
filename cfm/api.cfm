<!--- 
    API Endpoint for AJAX Operations
    Handles various AJAX requests from the frontend
--->

<cfparam name="url.action" default="">
<cfparam name="url.batchId" default="0">

<!--- Set response headers --->
<cfheader name="Content-Type" value="application/json">
<cfcontent reset="true">

<cfswitch expression="#url.action#">
    
    <!--- Get batch status --->
    <cfcase value="getBatchStatus">
        <cfquery name="batchStatus" datasource="yourDatasource">
            SELECT 
                BatchID,
                FileName,
                ProcessingStatus,
                TotalRecords,
                MatchedRecords,
                UnmatchedRecords,
                CASE 
                    WHEN TotalRecords > 0 
                    THEN CAST(MatchedRecords AS FLOAT) / TotalRecords * 100 
                    ELSE 0 
                END AS MatchPercentage,
                DATEDIFF(SECOND, ImportDate, ISNULL(CompletedDate, GETDATE())) AS ProcessingTimeSeconds
            FROM dbo.ImportBatch
            WHERE BatchID = <cfqueryparam value="#url.batchId#" cfsqltype="cf_sql_integer">
        </cfquery>
        
        <cfif batchStatus.recordCount GT 0>
            <cfset response = {
                "success": true,
                "data": {
                    "batchId": batchStatus.BatchID,
                    "fileName": batchStatus.FileName,
                    "status": batchStatus.ProcessingStatus,
                    "totalRecords": batchStatus.TotalRecords,
                    "matchedRecords": batchStatus.MatchedRecords,
                    "unmatchedRecords": batchStatus.UnmatchedRecords,
                    "matchPercentage": numberFormat(batchStatus.MatchPercentage, "99.9"),
                    "processingTime": batchStatus.ProcessingTimeSeconds
                }
            }>
        <cfelse>
            <cfset response = {
                "success": false,
                "error": "Batch not found"
            }>
        </cfif>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfcase>
    
    <!--- Get dashboard statistics --->
    <cfcase value="getDashboardStats">
        <cfquery name="stats" datasource="yourDatasource">
            SELECT 
                COUNT(DISTINCT DirectorateID) AS TotalDirectorates,
                COUNT(DISTINCT DivisionID) AS TotalDivisions,
                COUNT(DISTINCT ClientEmail) AS TotalClients,
                COUNT(*) AS TotalProjects,
                SUM(RecordedHours) AS TotalHours,
                AVG(RecordedHours) AS AvgHoursPerProject
            FROM dbo.TimekeepingEnriched
            WHERE MatchStatus = 'Matched'
            <cfif url.batchId GT 0>
                AND ImportBatchID = <cfqueryparam value="#url.batchId#" cfsqltype="cf_sql_integer">
            </cfif>
        </cfquery>
        
        <cfset response = {
            "success": true,
            "data": {
                "totalDirectorates": stats.TotalDirectorates,
                "totalDivisions": stats.TotalDivisions,
                "totalClients": stats.TotalClients,
                "totalProjects": stats.TotalProjects,
                "totalHours": numberFormat(stats.TotalHours, "999999.99"),
                "avgHoursPerProject": numberFormat(stats.AvgHoursPerProject, "999.99")
            }
        }>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfcase>
    
    <!--- Get directorate breakdown --->
    <cfcase value="getDirectorateBreakdown">
        <cfquery name="directorates" datasource="yourDatasource">
            SELECT TOP 10
                DirectorateNameE,
                DirectorateAcronymE,
                UniqueClients,
                TotalProjects,
                TotalHours
            FROM dbo.vw_HoursByDirectorate
            ORDER BY TotalHours DESC
        </cfquery>
        
        <cfset data = []>
        <cfloop query="directorates">
            <cfset arrayAppend(data, {
                "name": directorates.DirectorateNameE,
                "acronym": directorates.DirectorateAcronymE,
                "clients": directorates.UniqueClients,
                "projects": directorates.TotalProjects,
                "hours": numberFormat(directorates.TotalHours, "999999.99")
            })>
        </cfloop>
        
        <cfset response = {
            "success": true,
            "data": data
        }>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfcase>
    
    <!--- Get recent imports --->
    <cfcase value="getRecentImports">
        <cfquery name="recentImports" datasource="yourDatasource">
            SELECT TOP 20
                BatchID,
                FileName,
                ImportDate,
                TotalRecords,
                MatchedRecords,
                UnmatchedRecords,
                ProcessingStatus,
                ImportedBy,
                CASE 
                    WHEN TotalRecords > 0 
                    THEN CAST(MatchedRecords AS FLOAT) / TotalRecords * 100 
                    ELSE 0 
                END AS MatchPercentage
            FROM dbo.ImportBatch
            ORDER BY ImportDate DESC
        </cfquery>
        
        <cfset data = []>
        <cfloop query="recentImports">
            <cfset arrayAppend(data, {
                "batchId": recentImports.BatchID,
                "fileName": recentImports.FileName,
                "importDate": dateFormat(recentImports.ImportDate, "yyyy-mm-dd") & " " & timeFormat(recentImports.ImportDate, "HH:mm"),
                "totalRecords": recentImports.TotalRecords,
                "matchedRecords": recentImports.MatchedRecords,
                "unmatchedRecords": recentImports.UnmatchedRecords,
                "matchPercentage": numberFormat(recentImports.MatchPercentage, "99.9"),
                "status": recentImports.ProcessingStatus,
                "importedBy": recentImports.ImportedBy
            })>
        </cfloop>
        
        <cfset response = {
            "success": true,
            "data": data
        }>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfcase>
    
    <!--- Search clients --->
    <cfcase value="searchClients">
        <cfparam name="url.query" default="">
        
        <cfquery name="clients" datasource="yourDatasource">
            SELECT TOP 20
                ClientFirstName + ' ' + ClientLastName AS ClientName,
                ClientEmail,
                DirectorateNameE,
                DivisionNameE,
                TotalProjects,
                TotalHours
            FROM dbo.vw_TopClientsByHours
            WHERE (
                ClientEmail LIKE <cfqueryparam value="%#url.query#%" cfsqltype="cf_sql_varchar">
                OR ClientFirstName LIKE <cfqueryparam value="%#url.query#%" cfsqltype="cf_sql_varchar">
                OR ClientLastName LIKE <cfqueryparam value="%#url.query#%" cfsqltype="cf_sql_varchar">
            )
            ORDER BY TotalHours DESC
        </cfquery>
        
        <cfset data = []>
        <cfloop query="clients">
            <cfset arrayAppend(data, {
                "name": clients.ClientName,
                "email": clients.ClientEmail,
                "directorate": clients.DirectorateNameE,
                "division": clients.DivisionNameE,
                "projects": clients.TotalProjects,
                "hours": numberFormat(clients.TotalHours, "999.99")
            })>
        </cfloop>
        
        <cfset response = {
            "success": true,
            "data": data,
            "count": arrayLen(data)
        }>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfcase>
    
    <!--- Delete batch --->
    <cfcase value="deleteBatch">
        <cftry>
            <cftransaction>
                <!--- Delete enriched records --->
                <cfquery datasource="yourDatasource">
                    DELETE FROM dbo.TimekeepingEnriched
                    WHERE ImportBatchID = <cfqueryparam value="#url.batchId#" cfsqltype="cf_sql_integer">
                </cfquery>
                
                <!--- Delete staging records --->
                <cfquery datasource="yourDatasource">
                    DELETE FROM dbo.TimekeepingStaging
                    WHERE ImportBatchID = <cfqueryparam value="#url.batchId#" cfsqltype="cf_sql_integer">
                </cfquery>
                
                <!--- Delete unmatched records --->
                <cfquery datasource="yourDatasource">
                    DELETE FROM dbo.UnmatchedClients
                    WHERE ImportBatchID = <cfqueryparam value="#url.batchId#" cfsqltype="cf_sql_integer">
                </cfquery>
                
                <!--- Delete batch record --->
                <cfquery datasource="yourDatasource">
                    DELETE FROM dbo.ImportBatch
                    WHERE BatchID = <cfqueryparam value="#url.batchId#" cfsqltype="cf_sql_integer">
                </cfquery>
            </cftransaction>
            
            <cfset response = {
                "success": true,
                "message": "Batch deleted successfully"
            }>
            
            <cfcatch type="any">
                <cfset response = {
                    "success": false,
                    "error": cfcatch.message
                }>
            </cfcatch>
        </cftry>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfcase>
    
    <!--- Get unmatched clients --->
    <cfcase value="getUnmatchedClients">
        <cfquery name="unmatched" datasource="yourDatasource">
            SELECT 
                ClientEmail,
                ClientFirstName,
                ClientLastName,
                ClientContact,
                RecordedHours
            FROM dbo.UnmatchedClients
            WHERE ImportBatchID = <cfqueryparam value="#url.batchId#" cfsqltype="cf_sql_integer">
            ORDER BY RecordedHours DESC
        </cfquery>
        
        <cfset data = []>
        <cfloop query="unmatched">
            <cfset arrayAppend(data, {
                "email": unmatched.ClientEmail,
                "firstName": unmatched.ClientFirstName,
                "lastName": unmatched.ClientLastName,
                "contact": unmatched.ClientContact,
                "hours": numberFormat(unmatched.RecordedHours, "999.99")
            })>
        </cfloop>
        
        <cfset response = {
            "success": true,
            "data": data,
            "count": arrayLen(data)
        }>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfcase>
    
    <!--- Default: Invalid action --->
    <cfdefaultcase>
        <cfset response = {
            "success": false,
            "error": "Invalid action specified"
        }>
        
        <cfoutput>#serializeJSON(response)#</cfoutput>
    </cfdefaultcase>
    
</cfswitch>
