<!--- Export data to Excel based on type --->
<cfparam name="url.type" default="directorate">
<cfparam name="url.batch" default="0">

<cfswitch expression="#url.type#">
    <cfcase value="directorate">
        <cfquery name="exportData" datasource="yourDatasource">
            SELECT 
                te.DirectorateNameE AS 'Directorate Name (English)',
                te.DirectorateNameF AS 'Directorate Name (French)',
                te.DirectorateAcronymE AS 'Acronym',
                te.DivisionNameE AS 'Division',
                te.BranchNameE AS 'Branch',
                te.Category,
                te.ProjectMatter AS 'Project/Matter',
                te.ClientFirstName + ' ' + te.ClientLastName AS 'Client Name',
                te.ClientEmail AS 'Client Email',
                te.ClientPhone AS 'Phone',
                te.PositionLevel AS 'Position Level',
                te.RecordedHours AS 'Hours',
                te.ImportDate AS 'Import Date'
            FROM dbo.TimekeepingEnriched te
            WHERE te.MatchStatus = 'Matched'
            <cfif url.batch GT 0>
                AND te.ImportBatchID = <cfqueryparam value="#url.batch#" cfsqltype="cf_sql_integer">
            </cfif>
            ORDER BY te.DirectorateNameE, te.DivisionNameE, te.RecordedHours DESC
        </cfquery>
        <cfset fileName = "Timekeeping_By_Directorate_#dateFormat(now(), 'yyyymmdd')#.xlsx">
    </cfcase>
    
    <cfcase value="category">
        <cfquery name="exportData" datasource="yourDatasource">
            SELECT 
                te.Category,
                te.ProjectMatter AS 'Project/Matter',
                te.ClientFirstName + ' ' + te.ClientLastName AS 'Client Name',
                te.ClientEmail AS 'Client Email',
                te.DirectorateNameE AS 'Directorate',
                te.DivisionNameE AS 'Division',
                te.RecordedHours AS 'Hours',
                te.ImportDate AS 'Import Date'
            FROM dbo.TimekeepingEnriched te
            WHERE te.MatchStatus = 'Matched'
            <cfif url.batch GT 0>
                AND te.ImportBatchID = <cfqueryparam value="#url.batch#" cfsqltype="cf_sql_integer">
            </cfif>
            ORDER BY te.Category, te.RecordedHours DESC
        </cfquery>
        <cfset fileName = "Timekeeping_By_Category_#dateFormat(now(), 'yyyymmdd')#.xlsx">
    </cfcase>
    
    <cfcase value="clients">
        <cfquery name="exportData" datasource="yourDatasource">
            SELECT 
                te.ClientFirstName + ' ' + te.ClientLastName AS 'Client Name',
                te.ClientEmail AS 'Email',
                te.ClientPhone AS 'Phone',
                te.DirectorateNameE AS 'Directorate',
                te.DivisionNameE AS 'Division',
                te.BranchNameE AS 'Branch',
                te.PositionLevel AS 'Position Level',
                CASE WHEN te.IsManager = 1 THEN 'Yes' ELSE 'No' END AS 'Manager',
                COUNT(*) AS 'Number of Projects',
                SUM(te.RecordedHours) AS 'Total Hours',
                AVG(te.RecordedHours) AS 'Average Hours per Project',
                MIN(te.ImportDate) AS 'First Entry',
                MAX(te.ImportDate) AS 'Latest Entry'
            FROM dbo.TimekeepingEnriched te
            WHERE te.MatchStatus = 'Matched'
            <cfif url.batch GT 0>
                AND te.ImportBatchID = <cfqueryparam value="#url.batch#" cfsqltype="cf_sql_integer">
            </cfif>
            GROUP BY 
                te.ClientFirstName,
                te.ClientLastName,
                te.ClientEmail,
                te.ClientPhone,
                te.DirectorateNameE,
                te.DivisionNameE,
                te.BranchNameE,
                te.PositionLevel,
                te.IsManager
            ORDER BY SUM(te.RecordedHours) DESC
        </cfquery>
        <cfset fileName = "Timekeeping_Client_Summary_#dateFormat(now(), 'yyyymmdd')#.xlsx">
    </cfcase>
    
    <cfcase value="unmatched">
        <cfquery name="exportData" datasource="yourDatasource">
            SELECT 
                uc.ClientEmail AS 'Email',
                uc.ClientFirstName AS 'First Name',
                uc.ClientLastName AS 'Last Name',
                uc.ClientContact AS 'Full Contact Info',
                uc.RecordedHours AS 'Hours',
                uc.ImportDate AS 'Import Date'
            FROM dbo.UnmatchedClients uc
            WHERE uc.ImportBatchID = <cfqueryparam value="#url.batch#" cfsqltype="cf_sql_integer">
            ORDER BY uc.RecordedHours DESC
        </cfquery>
        <cfset fileName = "Unmatched_Clients_#dateFormat(now(), 'yyyymmdd')#.xlsx">
    </cfcase>
    
    <cfdefaultcase>
        <cfoutput>Invalid export type specified.</cfoutput>
        <cfabort>
    </cfdefaultcase>
</cfswitch>

<!--- Create Excel file --->
<cfspreadsheet action="write"
               query="exportData"
               filename="#expandPath('./exports/')##fileName#"
               overwrite="true"
               sheetname="Data">

<!--- Format the Excel file --->
<cfspreadsheet action="read"
               src="#expandPath('./exports/')##fileName#"
               name="spreadsheetObj"
               format="object">

<!--- Format header row --->
<cfset spreadsheetFormatRow(spreadsheetObj, {
    bold=true,
    fgcolor="light_blue",
    alignment="center"
}, 1)>

<!--- Auto-size columns --->
<cfset colCount = exportData.columnList.listLen()>
<cfloop from="1" to="#colCount#" index="i">
    <cfset spreadsheetFormatColumn(spreadsheetObj, {width=20}, i)>
</cfloop>

<!--- Add freeze pane on header --->
<cfset spreadsheetAddFreezePane(spreadsheetObj, 0, 1)>

<!--- Write formatted spreadsheet --->
<cfspreadsheet action="write"
               filename="#expandPath('./exports/')##fileName#"
               name="spreadsheetObj"
               overwrite="true">

<!--- Send file to browser --->
<cfheader name="Content-Disposition" value="attachment; filename=#fileName#">
<cfcontent type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" 
           file="#expandPath('./exports/')##fileName#"
           deletefile="true">
