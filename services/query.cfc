<cfcomponent>
    <!---Main function, calls all necessary functions--->
    <cffunction name="processUpload" access="public" returntype="struct" output="false">
        <cfset var result = {
            success = false,
            batchID = 0,
            fileName = "",
            totalRecords = 0,
            matchedRecords = 0,
            unmatchedRecords = 0,
            skippedRecords = 0,
            matchRate = 0,
            errorMessage = ""
        }>
        <cfset var uploadInfo = {}>
        <cfset var filePath = "">
        <cfset var batchID = 0>
        <cfset var excelData = queryNew("")>
        <cfset var columns = []>
        <cfset var contactNameCol = "">
        <cfset var hoursCol = "">
        <cfset var importStats = {}>
        <cfset var processingStats = {}>

        <cftry>
            <!---Makes sure there is a valid directory--->
            <cfset ensureUploadDirectory()>

            <!---Uploads the file--->
            <cffile
                action="upload"
                fileField="uploadFile"
                destination="#expandPath('./uploads/')#"
                nameConflict="makeUnique"
                result="uploadInfo">

            <cfset filePath = uploadInfo.serverDirectory & "/" & uploadInfo.serverFile>
            <cfset result.fileName = uploadInfo.clientFile>

            <!---Makes sure it's a valide file--->
            <cfset validateUploadedFile(uploadInfo)>

            <!---Creates the import batch--->
            <cfset batchID = createImportBatch(uploadInfo.clientFile)>
            <cfset result.batchID = batchID>

            <!---Reads the Excel file--->
            <cfset excelData = readExcelData(filePath)>

            <!---Puts the columns into an array--->
            <cfset columns = listToArray(excelData.columnList)>

            <!---Finds the contact column--->
            <cfset contactNameCol = findContactColumn(columns)>

            <!---Finds the hours column--->
            <cfset hoursCol = findHoursColumn(columns)>

            <!---Imports and inserts the Excel file's data--->
            <cfset importStats = importStagingRows(
                excelData = excelData,
                batchID = batchID,
                contactNameCol = contactNameCol,
                hoursCol = hoursCol
            )>

            <!---Updates the batch info--->
            <cfset updateBatchTotal(batchID, importStats.recordCount + importStats.skippedCount)>

            <!---Process the batch to send data to the rigt table--->
            <cfset processingStats = processStagingBatch(batchID)>

            <!---Completes the batch info--->
            <cfset completeImportBatch(
                batchID = batchID,
                matchedRecords = processingStats.matchedCount,
                unmatchedRecords = processingStats.unmatchedCount,
                skippedRecords = importStats.skippedCount
            )>
            <cfset result.success = true>
            <cfset result.totalRecords = importStats.recordCount + importStats.skippedCount>
            <cfset result.skippedRecords = importStats.skippedCount>
            <cfset result.matchedRecords = processingStats.matchedCount>
            <cfset result.unmatchedRecords = processingStats.unmatchedCount>
            <cfset var processedRecords = processingStats.matchedCount + processingStats.unmatchedCount>

            <cfif processedRecords GT 0>
                <cfset result.matchRate = (processingStats.matchedCount / processedRecords) * 100>
            </cfif>

            <cfcatch type="any">
                <cfset result.success = false>

                <!---Builds the error message--->
                <cfset result.errorMessage = buildErrorMessage(cfcatch)>

                <cfif batchID GT 0>
                    <!---Mark the batch as failed--->
                    <cfset markImportBatchFailed(batchID, result.errorMessage)>
                </cfif>
            </cfcatch>

            <cffinally>
                <!---Delete the file after everything is done--->
                <cfif len(filePath) AND fileExists(filePath)>
                    <cftry>
                        <cffile action="delete" file="#filePath#">
                        <cfcatch type="any">
                        </cfcatch>
                    </cftry>
                </cfif>
            </cffinally>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---Makes sure there is a directory for the Excel file--->
    <cffunction name="ensureUploadDirectory" access="private" returntype="void" output="false">
        <cfset var uploadDirectory = expandPath("./uploads/")>

        <!---Makes sure the directory does not exist before creating it--->
        <cfif NOT directoryExists(uploadDirectory)>
            <cfdirectory action="create" directory="#uploadDirectory#">
        </cfif>
    </cffunction>

    <!---Checks the type of the file to make sure it's a .xls or a .xlsx--->
    <cffunction name="validateUploadedFile" access="private" returntype="void" output="false">
        <cfargument name="uploadInfo" type="struct" required="true">
        <cfset var extension = lcase(arguments.uploadInfo.serverFileExt)>

        <!---Throw an error if the type is not the right one--->
        <cfif NOT listFindNoCase("xls,xlsx", extension)>
            <cfthrow
                type="Import.InvalidFileType"
                message="Type of file is not valid."
                detail="Only Excel files(.xls, .xlsx) are accepted.">
        </cfif>
    </cffunction>

    <!---Creates the basic import batch--->
    <cffunction name="createImportBatch" access="private" returntype="numeric" output="false">
        <cfargument name="fileName" type="string" required="true">
        <cfset var createBatch = queryNew("")>
        <cfset var importedBy = structKeyExists(form, "importedBy") ? trim(form.importedBy) : "">
        <cfset var notes = structKeyExists(form, "notes") ? trim(form.notes) : "">

        <cfquery name="createBatch" datasource="PMSD_SATS">
            INSERT INTO dbo.ImportBatch (
                FileName,
                ImportedBy,
                Notes,
                TotalRecords,
                ProcessingStatus
            )
            VALUES (
                <cfqueryparam value="#arguments.fileName#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#importedBy#" cfsqltype="cf_sql_varchar" null="#NOT len(importedBy)#">,
                <cfqueryparam value="#notes#" cfsqltype="cf_sql_varchar" null="#NOT len(notes)#">,
                0,
                'Processing'
            );
            SELECT CAST(SCOPE_IDENTITY() AS INT) AS BatchID;
        </cfquery>

        <cfif createBatch.recordCount EQ 0 OR NOT isNumeric(createBatch.BatchID[1])>
            <cfthrow
                type="Import.BatchCreationFailed"
                message="BatchID can't be fetched after the insertion.">
        </cfif>

        <cfreturn createBatch.BatchID[1]>
    </cffunction>

    <!---Sets the total records for the batch--->
    <cffunction name="updateBatchTotal" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="recordCount" type="numeric" required="true">

        <cfquery datasource="PMSD_SATS">
            UPDATE dbo.ImportBatch
            SET TotalRecords = <cfqueryparam value="#arguments.recordCount#" cfsqltype="cf_sql_integer">
            WHERE BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
    </cffunction>

    <!---Updates the batch after it's finished--->
    <cffunction name="completeImportBatch" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="matchedRecords" type="numeric" required="true">
        <cfargument name="unmatchedRecords" type="numeric" required="true">
        <cfargument name="skippedRecords" type="numeric" required="true">

        <cfquery datasource="PMSD_SATS">
            UPDATE dbo.ImportBatch
            SET
                MatchedRecords = <cfqueryparam value="#arguments.matchedRecords#" cfsqltype="cf_sql_integer">,
                UnmatchedRecords = <cfqueryparam value="#arguments.unmatchedRecords#" cfsqltype="cf_sql_integer">,
                SkippedRecords = <cfqueryparam value="#arguments.skippedRecords#" cfsqltype="cf_sql_integer">,
                ProcessingStatus = 'Completed',
                CompletedDate = GETDATE()
            WHERE BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
    </cffunction>

    <!---Marks the batch as failed--->
    <cffunction name="markImportBatchFailed" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="errorMessage" type="string" required="true">

        <cftry>
            <cfquery datasource="PMSD_SATS">
                UPDATE dbo.ImportBatch
                SET
                    ProcessingStatus = 'Failed',
                    CompletedDate = GETDATE()
                WHERE BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
            </cfquery>
            <cfcatch type="any">
            </cfcatch>
        </cftry>
    </cffunction>

    <!---Reads the Excel file--->
    <cffunction name="readExcelData" access="private" returntype="query" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfset var excelData = queryNew("")>

        <cftry>
            <cfspreadsheet
                action="read"
                src="#arguments.filePath#"
                query="excelData"
                sheetname="Data"
                headerrow="1"
                excludeHeaderRow="true">

            <cfcatch type="any">
                <cftry>
                    <cfspreadsheet
                        action="read"
                        src="#arguments.filePath#"
                        query="excelData"
                        sheet="1"
                        headerrow="1"
                        excludeHeaderRow="true">

                    <cfcatch type="any">
                        <cfspreadsheet
                            action="read"
                            src="#arguments.filePath#"
                            query="excelData"
                            headerrow="1"
                            excludeHeaderRow="true">
                    </cfcatch>
                </cftry>
            </cfcatch>
        </cftry>

        <cfif NOT isQuery(excelData) OR excelData.recordCount EQ 0>
            <cfthrow
                type="Import.EmptySpreadsheet"
                message="No data found in the Excel file.">
        </cfif>

        <cfreturn excelData>
    </cffunction>

    <!---Finds the contact column--->
    <cffunction name="findContactColumn" access="private" returntype="string" output="false">
        <cfargument name="columns" type="array" required="true">
        <cfset var columnName = "">

        <!---Search through the columns to find one that bears the name Contact_Name or ContactName or the first column with contact in it--->
        <cfloop array="#arguments.columns#" index="columnName">
            <cfif compareNoCase(columnName, "Contact_Name") EQ 0
                OR compareNoCase(columnName, "ContactName") EQ 0
                OR findNoCase("contact", columnName) GT 0>
                <cfreturn columnName>
            </cfif>
        </cfloop>

        <cfif arrayLen(arguments.columns) GTE 5>
            <cfreturn arguments.columns[5]>
        </cfif>

        <cfthrow
            type="Import.ContactColumnMissing"
            message="The contact column was not found.">
    </cffunction>

    <!---Finds the hours column--->
    <cffunction name="findHoursColumn" access="private" returntype="string" output="false">
        <cfargument name="columns" type="array" required="true">
        <cfset var columnName = "">

        <!---Search through the columns to find the first column with hour or recorded in it--->
        <cfloop array="#arguments.columns#" index="columnName">
            <cfif findNoCase("hour", columnName) GT 0 OR findNoCase("recorded", columnName) GT 0>
                <cfreturn columnName>
            </cfif>
        </cfloop>

        <cfif arrayLen(arguments.columns) GT 0>
            <cfreturn arguments.columns[arrayLen(arguments.columns)]>
        </cfif>

        <cfthrow
            type="Import.HoursColumnMissing"
            message="The hours column was not found.">
    </cffunction>

    <!---Imports and calls the insert function--->
    <cffunction name="importStagingRows" access="private" returntype="struct" output="false">
        <cfargument name="excelData" type="query" required="true">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="contactNameCol" type="string" required="true">
        <cfargument name="hoursCol" type="string" required="true">

        <cfset var stats = {recordCount = 0, skippedCount = 0}>
        <cfset var currentRowNumber = 0>
        <cfset var clientContact = "">
        <cfset var hoursValue = "">
        <cfset var hours = 0>

        <!---Loops through the data and fill in the info--->
        <cfloop query="arguments.excelData">
            <cfset currentRowNumber = arguments.excelData.currentRow>
            <cfset clientContact = "">
            <cfset hoursValue = "">
            <cfset hours = 0>

            <cftry>
                <cfset clientContact = trim(arguments.excelData[arguments.contactNameCol][currentRowNumber])>
                <cfset hoursValue = arguments.excelData[arguments.hoursCol][currentRowNumber]>

                <cfcatch type="any">
                    <cfset stats.skippedCount = stats.skippedCount + 1>
                    <cfcontinue>
                </cfcatch>
            </cftry>

            <cfif NOT len(clientContact)>
                <cfset stats.skippedCount = stats.skippedCount + 1>
                <cfcontinue>
            </cfif>
            <cfif NOT isNumeric(hoursValue)>
                <cfset stats.skippedCount = stats.skippedCount + 1>
                <cfcontinue>
            </cfif>

            <cfset hours = val(hoursValue)>

            <!---Call the insert function--->
            <cfset insertStagingRow(
                batchID = arguments.batchID,
                rowNumber = currentRowNumber,
                clientContact = clientContact,
                hours = hours
            )>
            <cfset stats.recordCount = stats.recordCount + 1>
        </cfloop>

        <cfreturn stats>
    </cffunction>

    <!---Turns "Last, First - [Role]" into last and first name pairs.--->
    <cffunction name="parseContactNames" access="private" returntype="array" output="false">
        <cfargument name="clientContact" type="string" required="true">
        <cfset var names = []>
        <cfset var seen = {}>
        <cfset var normalized = trim(arguments.clientContact)>
        <cfset var lines = []>
        <cfset var line = "">
        <cfset var bracketAt = 0>
        <cfset var namePortion = "">
        <cfset var commaAt = 0>
        <cfset var lastName = "">
        <cfset var firstName = "">
        <cfset var personKey = "">

        <cfif NOT len(normalized)>
            <cfreturn names>
        </cfif>

        <cfset normalized = reReplace(normalized, "[\r\n]+", chr(10), "all")>
        <cfset normalized = reReplace(normalized, "\]\s+(?=\p{L})", "]" & chr(10), "all")>
        <cfset lines = listToArray(normalized, chr(10))>

        <cfloop array="#lines#" index="line">
            <cfset line = trim(line)>
            <cfset bracketAt = find("[", line)>

            <cfif bracketAt GT 0>
                <cfset namePortion = trim(left(line, bracketAt - 1))>
            <cfelse>
                <cfset namePortion = line>
            </cfif>

            <cfset namePortion = trim(reReplace(namePortion, "\s*-\s*$", ""))>
            <cfset commaAt = find(",", namePortion)>

            <cfif commaAt LTE 1>
                <cfcontinue>
            </cfif>

            <cfset lastName = trim(left(namePortion, commaAt - 1))>
            <cfset firstName = trim(mid(namePortion, commaAt + 1, len(namePortion)))>
            <cfset firstName = trim(reReplace(firstName, "\s*-\s*$", ""))>

            <cfif find(",", firstName)>
                <cfset firstName = trim(listFirst(firstName, ","))>
            </cfif>

            <cfif len(lastName) LT 2 OR NOT len(firstName) OR find("@", firstName) OR find("@", lastName)>
                <cfcontinue>
            </cfif>

            <cfset personKey = lcase(lastName & "|" & firstName)>

            <cfif structKeyExists(seen, personKey)>
                <cfcontinue>
            </cfif>

            <cfset seen[personKey] = true>
            <cfset arrayAppend(names, {
                lastName = lastName,
                firstName = firstName
            })>
        </cfloop>

        <cfreturn names>
    </cffunction>

    <!---Compares names without spaces, hyphens, or apostrophes.--->
    <cffunction name="compactName" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="true">
        <cfreturn lcase(reReplace(arguments.value, "[\s\-\.'’]", "", "all"))>
    </cffunction>

    <cffunction name="escapeLdapValue" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="true">
        <cfset var escaped = arguments.value>

        <cfset escaped = replace(escaped, "\", "\5c", "all")>
        <cfset escaped = replace(escaped, "*", "\2a", "all")>
        <cfset escaped = replace(escaped, "(", "\28", "all")>
        <cfset escaped = replace(escaped, ")", "\29", "all")>
        <cfset escaped = replace(escaped, chr(0), "\00", "all")>
        <cfset escaped = replace(escaped, '"', "\22", "all")>

        <cfreturn escaped>
    </cffunction>

    <cffunction name="queryActiveDirectoryByName" access="private" returntype="query" output="false">
        <cfargument name="filter" type="string" required="true">

        <!---The LDAP tag writes this query into the caller scope, same as the email lookup.--->
        <cftry>
            <cf_ldap
                filter="#arguments.filter#"
                attributes="cn,mail,givenName,sn,department,division,company"
                name="qryADByName">
            <cfcatch type="any">
                <cfset qryADByName = queryNew("")>
            </cfcatch>
        </cftry>

        <cfif NOT isQuery(qryADByName)>
            <cfset qryADByName = queryNew("")>
        </cfif>

        <cfreturn qryADByName>
    </cffunction>

    <!---Maps an Active Directory department to one current directorate.--->
    <cffunction name="findDirectoratesByOrgText" access="private" returntype="query" output="false">
        <cfargument name="orgText" type="string" required="true">
        <cfset var qryDirectorate = queryNew("")>
        <cfset var orgValue = trim(arguments.orgText)>

        <cfif NOT len(orgValue)>
            <cfreturn qryDirectorate>
        </cfif>

        <cfquery name="qryDirectorate" datasource="#application.branchDatasource#">
            SELECT
                ID,
                NameE,
                NameF,
                AcronymE,
                AcronymF
            FROM dbo.tblDirectorates
            WHERE DateTo IS NULL
            AND BranchID = 1
            AND (
                NameE = <cfqueryparam value="#orgValue#" cfsqltype="cf_sql_varchar">
                OR NameF = <cfqueryparam value="#orgValue#" cfsqltype="cf_sql_varchar">
                OR AcronymE = <cfqueryparam value="#orgValue#" cfsqltype="cf_sql_varchar">
                OR AcronymF = <cfqueryparam value="#orgValue#" cfsqltype="cf_sql_varchar">
                OR (
                    LEN(NameE) >= 8
                    AND <cfqueryparam value="#orgValue#" cfsqltype="cf_sql_varchar"> LIKE '%' + NameE + '%'
                )
                OR (
                    LEN(NameF) >= 8
                    AND <cfqueryparam value="#orgValue#" cfsqltype="cf_sql_varchar"> LIKE '%' + NameF + '%'
                )
            )
        </cfquery>

        <cfreturn qryDirectorate>
    </cffunction>

    <cffunction name="directoryOrgValue" access="private" returntype="string" output="false">
        <cfargument name="directoryQuery" type="query" required="true">
        <cfargument name="columnName" type="string" required="true">
        <cfargument name="rowNumber" type="numeric" required="false" default="1">

        <cfif NOT listFindNoCase(arguments.directoryQuery.columnList, arguments.columnName)>
            <cfreturn "">
        </cfif>

        <cfreturn trim(arguments.directoryQuery[arguments.columnName][arguments.rowNumber] & "")>
    </cffunction>

    <!---Uses Active Directory when the person is missing from the branch directory.--->
    <cffunction name="lookupDirectorateInActiveDirectory" access="private" returntype="struct" output="false">
        <cfargument name="firstName" type="string" required="true">
        <cfargument name="lastName" type="string" required="true">

        <cfset var result = {
            found = false,
            errorMessage = "",
            userID = "",
            email = "",
            firstName = arguments.firstName,
            lastName = arguments.lastName,
            directorateNameE = "",
            directorateNameF = "",
            directorateAcronymE = "",
            directorateAcronymF = "",
            directorateID = ""
        }>
        <cfset var exactFilter = "">
        <cfset var prefixFilter = "">
        <cfset var qryADByName = queryNew("")>
        <cfset var accounts = {}>
        <cfset var accountId = "">
        <cfset var orgColumn = "">
        <cfset var orgText = "">
        <cfset var seenOrgText = "">
        <cfset var qryDirectorate = queryNew("")>

        <cfset exactFilter = "(&(objectCategory=person)(objectClass=user)(sn="
            & escapeLdapValue(arguments.lastName)
            & ")(givenName="
            & escapeLdapValue(arguments.firstName)
            & "))">
        <cfset qryADByName = queryActiveDirectoryByName(exactFilter)>

        <cfif NOT isQuery(qryADByName) OR qryADByName.recordCount EQ 0>
            <cfset prefixFilter = "(&(objectCategory=person)(objectClass=user)(sn="
                & escapeLdapValue(arguments.lastName)
                & ")(givenName="
                & escapeLdapValue(arguments.firstName)
                & "*))">
            <cfset qryADByName = queryActiveDirectoryByName(prefixFilter)>
        </cfif>

        <cfif NOT isQuery(qryADByName) OR qryADByName.recordCount EQ 0>
            <cfset result.errorMessage = "No matching user found for name: #arguments.lastName#, #arguments.firstName#">
            <cfreturn result>
        </cfif>

        <cfloop query="qryADByName">
            <cfset accountId = directoryOrgValue(qryADByName, "cn", qryADByName.currentRow)>
            <cfif NOT len(accountId)>
                <cfset accountId = "row-" & qryADByName.currentRow>
            </cfif>
            <cfset accounts[accountId] = true>
        </cfloop>

        <cfif structCount(accounts) NEQ 1>
            <cfset result.errorMessage = "More than one Active Directory account matches #arguments.lastName#, #arguments.firstName#">
            <cfreturn result>
        </cfif>

        <cfset result.userID = left(directoryOrgValue(qryADByName, "cn"), 50)>
        <cfset result.email = lcase(directoryOrgValue(qryADByName, "mail"))>
        <cfif len(directoryOrgValue(qryADByName, "givenName"))>
            <cfset result.firstName = directoryOrgValue(qryADByName, "givenName")>
        </cfif>
        <cfif len(directoryOrgValue(qryADByName, "sn"))>
            <cfset result.lastName = directoryOrgValue(qryADByName, "sn")>
        </cfif>
        <cfif NOT len(result.userID)>
            <cfset result.userID = left(
                "ad-" & compactName(arguments.lastName) & "-" & compactName(arguments.firstName),
                50
            )>
        </cfif>

        <cfloop list="department,division,company" index="orgColumn">
            <cfset orgText = directoryOrgValue(qryADByName, orgColumn)>
            <cfif NOT len(orgText)>
                <cfcontinue>
            </cfif>

            <cfset seenOrgText = orgText>
            <cfset qryDirectorate = findDirectoratesByOrgText(orgText)>

            <cfif qryDirectorate.recordCount EQ 1>
                <cfset result.found = true>
                <cfset result.directorateID = qryDirectorate.ID[1]>
                <cfset result.directorateNameE = qryDirectorate.NameE[1] & "">
                <cfset result.directorateNameF = qryDirectorate.NameF[1] & "">
                <cfset result.directorateAcronymE = qryDirectorate.AcronymE[1] & "">
                <cfset result.directorateAcronymF = qryDirectorate.AcronymF[1] & "">
                <cfset result.errorMessage = "">
                <cfreturn result>
            </cfif>

            <cfif qryDirectorate.recordCount GT 1>
                <cfset result.errorMessage = "Active Directory #orgColumn# '#orgText#' matches more than one directorate for #arguments.lastName#, #arguments.firstName#">
                <cfreturn result>
            </cfif>
        </cfloop>

        <cfif len(seenOrgText)>
            <cfset result.errorMessage = "Active Directory department '#seenOrgText#' does not match a directorate for #arguments.lastName#, #arguments.firstName#">
        <cfelse>
            <cfset result.errorMessage = "No directorate was found in Active Directory for #arguments.lastName#, #arguments.firstName#">
        </cfif>

        <cfreturn result>
    </cffunction>

    <cffunction name="findUsersByName" access="private" returntype="query" output="false">
        <cfargument name="firstName" type="string" required="true">
        <cfargument name="lastName" type="string" required="true">
        <cfset var qryByName = queryNew("")>
        <cfset var compactFirst = compactName(arguments.firstName)>
        <cfset var compactLast = compactName(arguments.lastName)>

        <cfif NOT len(compactFirst) OR NOT len(compactLast)>
            <cfreturn qryByName>
        </cfif>

        <cfquery name="qryByName" datasource="#application.branchDatasource#">
            SELECT
                userID,
                firstName,
                lastName,
                phone,
                PositionLevel,
                IsManager,
                DirectorateNameE,
                DirectorateNameF,
                DirectorateAcronymE,
                DirectorateAcronymF,
                DirectorateID,
                DivisionNameE,
                DivisionNameF,
                DivisionAcronymE,
                DivisionAcronymF,
                DivisionID,
                BranchNameE,
                BranchNameF,
                BranchAcronymE,
                BranchAcronymF,
                BranchID,
                SectionNameE,
                SectionNameF,
                SectionAcronymE,
                SectionAcronymF,
                SectionID
            FROM dbo.vUserInfo
            WHERE LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(lastName, ''), '-', ''), ' ', ''), '''', ''), '.', ''), NCHAR(8217), ''))
                COLLATE Latin1_General_CI_AI = <cfqueryparam value="#compactLast#" cfsqltype="cf_sql_varchar">
            AND LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(firstName, ''), '-', ''), ' ', ''), '''', ''), '.', ''), NCHAR(8217), ''))
                COLLATE Latin1_General_CI_AI = <cfqueryparam value="#compactFirst#" cfsqltype="cf_sql_varchar">
        </cfquery>

        <cfreturn qryByName>
    </cffunction>

    <cffunction name="directoryHit" access="private" returntype="struct" output="false">
        <cfargument name="userQuery" type="query" required="true">
        <cfset var row = arguments.userQuery.currentRow>

        <cfreturn {
            userID = arguments.userQuery.userID[row] & "",
            firstName = arguments.userQuery.firstName[row] & "",
            lastName = arguments.userQuery.lastName[row] & "",
            phone = arguments.userQuery.phone[row] & "",
            positionLevel = arguments.userQuery.PositionLevel[row] & "",
            isManager = arguments.userQuery.IsManager[row],
            directorateNameE = arguments.userQuery.DirectorateNameE[row] & "",
            directorateNameF = arguments.userQuery.DirectorateNameF[row] & "",
            directorateAcronymE = arguments.userQuery.DirectorateAcronymE[row] & "",
            directorateAcronymF = arguments.userQuery.DirectorateAcronymF[row] & "",
            directorateID = arguments.userQuery.DirectorateID[row],
            divisionNameE = arguments.userQuery.DivisionNameE[row] & "",
            divisionNameF = arguments.userQuery.DivisionNameF[row] & "",
            divisionAcronymE = arguments.userQuery.DivisionAcronymE[row] & "",
            divisionAcronymF = arguments.userQuery.DivisionAcronymF[row] & "",
            divisionID = arguments.userQuery.DivisionID[row],
            branchNameE = arguments.userQuery.BranchNameE[row] & "",
            branchNameF = arguments.userQuery.BranchNameF[row] & "",
            branchAcronymE = arguments.userQuery.BranchAcronymE[row] & "",
            branchAcronymF = arguments.userQuery.BranchAcronymF[row] & "",
            branchID = arguments.userQuery.BranchID[row],
            sectionNameE = arguments.userQuery.SectionNameE[row] & "",
            sectionNameF = arguments.userQuery.SectionNameF[row] & "",
            sectionAcronymE = arguments.userQuery.SectionAcronymE[row] & "",
            sectionAcronymF = arguments.userQuery.SectionAcronymF[row] & "",
            sectionID = arguments.userQuery.SectionID[row]
        }>
    </cffunction>

    <cffunction name="applyDirectoryUser" access="private" returntype="void" output="false">
        <cfargument name="client" type="struct" required="true">
        <cfargument name="hit" type="struct" required="true">

        <cfset arguments.client.found = true>
        <cfset arguments.client.userID = arguments.hit.userID>
        <cfset arguments.client.firstName = arguments.hit.firstName>
        <cfset arguments.client.lastName = arguments.hit.lastName>
        <cfset arguments.client.phone = arguments.hit.phone>
        <cfset arguments.client.positionLevel = arguments.hit.positionLevel>
        <cfset arguments.client.isManager = arguments.hit.isManager>
        <cfset arguments.client.directorateNameE = arguments.hit.directorateNameE>
        <cfset arguments.client.directorateNameF = arguments.hit.directorateNameF>
        <cfset arguments.client.directorateAcronymE = arguments.hit.directorateAcronymE>
        <cfset arguments.client.directorateAcronymF = arguments.hit.directorateAcronymF>
        <cfset arguments.client.directorateID = arguments.hit.directorateID>
        <cfset arguments.client.divisionNameE = arguments.hit.divisionNameE>
        <cfset arguments.client.divisionNameF = arguments.hit.divisionNameF>
        <cfset arguments.client.divisionAcronymE = arguments.hit.divisionAcronymE>
        <cfset arguments.client.divisionAcronymF = arguments.hit.divisionAcronymF>
        <cfset arguments.client.divisionID = arguments.hit.divisionID>
        <cfset arguments.client.branchNameE = arguments.hit.branchNameE>
        <cfset arguments.client.branchNameF = arguments.hit.branchNameF>
        <cfset arguments.client.branchAcronymE = arguments.hit.branchAcronymE>
        <cfset arguments.client.branchAcronymF = arguments.hit.branchAcronymF>
        <cfset arguments.client.branchID = arguments.hit.branchID>
        <cfset arguments.client.sectionNameE = arguments.hit.sectionNameE>
        <cfset arguments.client.sectionNameF = arguments.hit.sectionNameF>
        <cfset arguments.client.sectionAcronymE = arguments.hit.sectionAcronymE>
        <cfset arguments.client.sectionAcronymF = arguments.hit.sectionAcronymF>
        <cfset arguments.client.sectionID = arguments.hit.sectionID>
        <cfset arguments.client.errorMessage = "">
    </cffunction>

    <!---Finds the right client--->
    <cffunction name="resolveClient" access="private" returntype="struct" output="false">
        <cfargument name="clientContact" type="string" required="true">

        <cfset var client = {
            found = false,
            email = "",
            userID = "",
            firstName = "",
            lastName = "",
            phone = "",
            positionLevel = "",
            isManager = false,
            directorateNameE = "",
            directorateNameF = "",
            directorateAcronymE = "",
            directorateAcronymF = "",
            directorateID = "",
            divisionNameE = "",
            divisionNameF = "",
            divisionAcronymE = "",
            divisionAcronymF = "",
            divisionID = "",
            branchNameE = "",
            branchNameF = "",
            branchAcronymE = "",
            branchAcronymF = "",
            branchID = "",
            sectionNameE = "",
            sectionNameF = "",
            sectionAcronymE = "",
            sectionAcronymF = "",
            sectionID = "",
            errorMessage = ""
        }>

        <!---Finds the email with the right format--->
        <cfset var emailMatches = reMatchNoCase("[^@\s]+@(?:cra-arc\.gc\.ca|canada\.ca)", arguments.clientContact)>

        <!---Finds other type of email--->
        <cfset var emails = reMatchNoCase("[^@\s]+@[^@\s]+\.ca", arguments.clientContact)>

        <!---If there is a match give the client the matching email--->
        <cfif arrayLen(emailMatches) GT 0>
            <cfset client.email = lcase(trim(emailMatches[1]))>
        <cfelseif arrayLen(emails) GT 0>
            <!---Else give the client the other email and fill in the error message--->
            <cfset client.email = lcase(trim(emails[1]))>
            <cfset client.errorMessage = "No valid email address found in contact">
        <cfelse>
            <!---No email at all: leave unmatched instead of crashing on empty array access--->
            <cfset client.email = "">
            <cfset client.errorMessage = "No valid email address found in contact">
        </cfif>

        <!---Loop throught the emails and the first one to match an account(branch directory or active directory) is the client--->
        <cfloop array="#emailMatches#" index="candidateEmail">
            <!---Search throught the Active directory for the email--->
            <cf_ldap filter="mail=#candidateEmail#" attributes="cn" name="qryAD">

            <!---If the email is not found go to the next email--->
            <cfif NOT isQuery(qryAD) OR qryAD.recordCount EQ 0>
                <cfcontinue>
            </cfif>

            <!---If the email is found take the UserId and search it in the branch directory--->
            <cfquery name="qryUser" datasource="#application.branchDatasource#">
                SELECT TOP (1)
                    userID,
                    firstName,
                    lastName,
                    phone,
                    PositionLevel,
                    IsManager,
                    DirectorateNameE,
                    DirectorateNameF,
                    DirectorateAcronymE,
                    DirectorateAcronymF,
                    DirectorateID,
                    DivisionNameE,
                    DivisionNameF,
                    DivisionAcronymE,
                    DivisionAcronymF,
                    DivisionID,
                    BranchNameE,
                    BranchNameF,
                    BranchAcronymE,
                    BranchAcronymF,
                    BranchID,
                    SectionNameE,
                    SectionNameF,
                    SectionAcronymE,
                    SectionAcronymF,
                    SectionID
                FROM dbo.vUserInfo
                WHERE userId = <cfqueryparam value="#qryAD.cn[1]#" cfsqltype="cf_sql_varchar">
            </cfquery>

            <!---If the UserId is found fill in the client info--->
            <cfif qryUser.recordCount GT 0>
                <cfset client.found = true>
                <cfset client.email = lcase(trim(candidateEmail))>
                <cfset client.userID = qryUser.userID[1]>
                <cfset client.firstName = qryUser.firstName[1]>
                <cfset client.lastName = qryUser.lastName[1]>
                <cfset client.phone = qryUser.phone[1]>
                <cfset client.positionLevel = qryUser.PositionLevel[1]>
                <cfset client.isManager = qryUser.IsManager[1]>
                <cfset client.directorateNameE = qryUser.DirectorateNameE[1]>
                <cfset client.directorateNameF = qryUser.DirectorateNameF[1]>
                <cfset client.directorateAcronymE = qryUser.DirectorateAcronymE[1]>
                <cfset client.directorateAcronymF = qryUser.DirectorateAcronymF[1]>
                <cfset client.directorateID = qryUser.DirectorateID[1]>
                <cfset client.divisionNameE = qryUser.DivisionNameE[1]>
                <cfset client.divisionNameF = qryUser.DivisionNameF[1]>
                <cfset client.divisionAcronymE = qryUser.DivisionAcronymE[1]>
                <cfset client.divisionAcronymF = qryUser.DivisionAcronymF[1]>
                <cfset client.divisionID = qryUser.DivisionID[1]>
                <cfset client.branchNameE = qryUser.BranchNameE[1]>
                <cfset client.branchNameF = qryUser.BranchNameF[1]>
                <cfset client.branchAcronymE = qryUser.BranchAcronymE[1]>
                <cfset client.branchAcronymF = qryUser.BranchAcronymF[1]>
                <cfset client.branchID = qryUser.BranchID[1]>
                <cfset client.sectionNameE = qryUser.SectionNameE[1]>
                <cfset client.sectionNameF = qryUser.SectionNameF[1]>
                <cfset client.sectionAcronymE = qryUser.SectionAcronymE[1]>
                <cfset client.sectionAcronymF = qryUser.SectionAcronymF[1]>
                <cfset client.sectionID = qryUser.SectionID[1]>
                <cfbreak>
            </cfif>
        </cfloop>

        <cfif client.found>
            <cfreturn client>
        </cfif>

        <!---An email that is not in the branch directory stays unmatched.--->
        <cfif arrayLen(emailMatches) GT 0>
            <cfif NOT len(trim(client.errorMessage))>
                <cfset client.errorMessage = "No matching user found for email: #client.email#">
            </cfif>
            <cfreturn client>
        </cfif>

        <!---No email: match the primary contact when exactly one employee has that name.--->
        <cfset var parsedNames = parseContactNames(arguments.clientContact)>
        <cfset var qryByName = queryNew("")>
        <cfset var directoryRow = {}>
        <cfset var seenUsers = {}>
        <cfset var onlyUserKeys = []>
        <cfset var directoryMatch = {}>

        <cfif arrayLen(parsedNames) EQ 0>
            <cfreturn client>
        </cfif>

        <cfset client.firstName = parsedNames[1].firstName>
        <cfset client.lastName = parsedNames[1].lastName>
        <cfset qryByName = findUsersByName(
            firstName = parsedNames[1].firstName,
            lastName = parsedNames[1].lastName
        )>

        <cfloop query="qryByName">
            <cfset directoryRow = directoryHit(qryByName)>

            <cfif len(trim(directoryRow.userID)) AND NOT structKeyExists(seenUsers, directoryRow.userID)>
                <cfset seenUsers[directoryRow.userID] = directoryRow>
            </cfif>
        </cfloop>

        <cfset onlyUserKeys = structKeyArray(seenUsers)>

        <cfif arrayLen(onlyUserKeys) EQ 1>
            <cfset applyDirectoryUser(client, seenUsers[onlyUserKeys[1]])>
            <cfreturn client>
        </cfif>

        <cfif arrayLen(onlyUserKeys) GT 1>
            <cfset client.errorMessage = "More than one employee matches #parsedNames[1].lastName#, #parsedNames[1].firstName#">
            <cfreturn client>
        </cfif>

        <!---Not in the branch directory: take the directorate from Active Directory.--->
        <cfset directoryMatch = lookupDirectorateInActiveDirectory(
            firstName = parsedNames[1].firstName,
            lastName = parsedNames[1].lastName
        )>

        <cfif directoryMatch.found>
            <cfset client.found = true>
            <cfset client.userID = directoryMatch.userID>
            <cfset client.firstName = directoryMatch.firstName>
            <cfset client.lastName = directoryMatch.lastName>
            <cfif len(trim(directoryMatch.email))>
                <cfset client.email = directoryMatch.email>
            </cfif>
            <cfset client.directorateNameE = directoryMatch.directorateNameE>
            <cfset client.directorateNameF = directoryMatch.directorateNameF>
            <cfset client.directorateAcronymE = directoryMatch.directorateAcronymE>
            <cfset client.directorateAcronymF = directoryMatch.directorateAcronymF>
            <cfset client.directorateID = directoryMatch.directorateID>
            <cfset client.errorMessage = "">
            <cfreturn client>
        </cfif>

        <cfif len(trim(directoryMatch.errorMessage))>
            <cfset client.errorMessage = directoryMatch.errorMessage>
        <cfelse>
            <cfset client.errorMessage = "No matching user found for name: #parsedNames[1].lastName#, #parsedNames[1].firstName#">
        </cfif>

        <cfreturn client>
    </cffunction>

    <!---Inserts data into the staging table--->
    <cffunction name="insertStagingRow" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="rowNumber" type="numeric" required="true">
        <cfargument name="clientContact" type="string" required="true">
        <cfargument name="hours" type="numeric" required="true">

        <cfquery datasource="PMSD_SATS">
            INSERT INTO dbo.TimekeepingStaging (
                ImportBatchID,
                RowNumber,
                ClientContact,
                RecordedHours,
                ProcessingStatus
            )
            VALUES (
                <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">,
                <cfqueryparam value="#arguments.rowNumber#" cfsqltype="cf_sql_integer">,
                <cfqueryparam value="#arguments.clientContact#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.hours#" cfsqltype="cf_sql_decimal" scale="2">,
                'Pending'
            )
        </cfquery>
    </cffunction>

    <!---Inserts info into the enriched table--->
    <cffunction name="insertEnrichedClient" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="clientContact" type="string" required="true">
        <cfargument name="recordedHours" type="numeric" required="true">
        <cfargument name="client" type="struct" required="true">

        <cfif NOT structKeyExists(arguments.client, "found")
            OR NOT arguments.client.found
            OR NOT structKeyExists(arguments.client, "userID")
            OR NOT len(trim(arguments.client.userID))>

            <cfthrow
                type="Import.InvalidResolvedClient"
                message="The resolved client does not contain a valid UserID.">
        </cfif>

        <cfquery datasource="PMSD_SATS">
            INSERT INTO dbo.TimekeepingEnriched (
                ImportBatchID,
                Category,
                ProjectMatter,
                ClientContact,
                ClientEmail,
                ClientFirstName,
                ClientLastName,
                ClientUserID,
                RecordedHours,
                DirectorateNameE,
                DirectorateNameF,
                DirectorateAcronymE,
                DirectorateAcronymF,
                DirectorateID,
                DivisionNameE,
                DivisionNameF,
                DivisionAcronymE,
                DivisionAcronymF,
                DivisionID,
                BranchNameE,
                BranchNameF,
                BranchAcronymE,
                BranchAcronymF,
                BranchID,
                SectionNameE,
                SectionNameF,
                SectionAcronymE,
                SectionAcronymF,
                SectionID,
                ClientPhone,
                PositionLevel,
                IsManager,
                MatchStatus,
                ProcessedDate
            )
            VALUES (
                <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">,
                <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.clientContact#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.client.email#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.email))#">,
                <cfqueryparam value="#arguments.client.firstName#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.firstName))#">,
                <cfqueryparam value="#arguments.client.lastName#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.lastName))#">,
                <cfqueryparam value="#arguments.client.userID#" cfsqltype="cf_sql_varchar">,
                <cfqueryparam value="#arguments.recordedHours#" cfsqltype="cf_sql_decimal" scale="2">,
                <cfqueryparam value="#arguments.client.directorateNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.directorateNameE))#">,
                <cfqueryparam value="#arguments.client.directorateNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.directorateNameF))#">,
                <cfqueryparam value="#arguments.client.directorateAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.directorateAcronymE))#">,
                <cfqueryparam value="#arguments.client.directorateAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.directorateAcronymF))#">,
                <cfqueryparam value="#arguments.client.directorateID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(arguments.client.directorateID)#">,
                <cfqueryparam value="#arguments.client.divisionNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.divisionNameE))#">,
                <cfqueryparam value="#arguments.client.divisionNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.divisionNameF))#">,
                <cfqueryparam value="#arguments.client.divisionAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.divisionAcronymE))#">,
                <cfqueryparam value="#arguments.client.divisionAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.divisionAcronymF))#">,
                <cfqueryparam value="#arguments.client.divisionID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(arguments.client.divisionID)#">,
                <cfqueryparam value="#arguments.client.branchNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.branchNameE))#">,
                <cfqueryparam value="#arguments.client.branchNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.branchNameF))#">,
                <cfqueryparam value="#arguments.client.branchAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.branchAcronymE))#">,
                <cfqueryparam value="#arguments.client.branchAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.branchAcronymF))#">,
                <cfqueryparam value="#arguments.client.branchID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(arguments.client.branchID)#">,
                <cfqueryparam value="#arguments.client.sectionNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.sectionNameE))#">,
                <cfqueryparam value="#arguments.client.sectionNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.sectionNameF))#">,
                <cfqueryparam value="#arguments.client.sectionAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.sectionAcronymE))#">,
                <cfqueryparam value="#arguments.client.sectionAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.sectionAcronymF))#">,
                <cfqueryparam value="#arguments.client.sectionID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(arguments.client.sectionID)#">,
                <cfqueryparam value="#arguments.client.phone#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.phone))#">,
                <cfqueryparam value="#arguments.client.positionLevel#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(arguments.client.positionLevel))#">,
                <cfqueryparam value="#arguments.client.isManager#" cfsqltype="cf_sql_bit" null="#NOT isBoolean(arguments.client.isManager) AND NOT isNumeric(arguments.client.isManager)#">,
                'Matched',
                GETDATE()
            )
        </cfquery>
    </cffunction>

    <!---Process the batch and put the data into the staging or the unmatched tables--->
    <cffunction name="processStagingBatch" access="private" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">

        <cfset var stats = {
            matchedCount = 0,
            unmatchedCount = 0
        }>

        <cfset var stagingRows = queryNew("")>
        <cfset var client = {}>
        <cfset var stagingID = 0>

        <cfset var clientCache = {}>
        <cfset var contactCacheKey = "">
        <cfset var storedEmail = "">
        <cfset var rowError = "">

        <cfquery name="stagingRows" datasource="PMSD_SATS">
            SELECT
                StagingID,
                ImportBatchID,
                RowNumber,
                Category,
                ProjectMatter,
                ClientContact,
                RecordedHours
            FROM dbo.TimekeepingStaging
            WHERE ImportBatchID = <cfqueryparam
                value="#arguments.batchID#"
                cfsqltype="cf_sql_integer">
            AND ProcessingStatus = 'Pending'
            ORDER BY RowNumber
        </cfquery>

        <cfloop query="stagingRows">
            <cfset stagingID = stagingRows.StagingID[stagingRows.currentRow]>

            <cfset contactCacheKey = lcase(trim(stagingRows.ClientContact[stagingRows.currentRow] & ""))>

            <cfif structKeyExists(clientCache, contactCacheKey)>
                <cfset client = clientCache[contactCacheKey]>
            <cfelse>
                <!---Finds the right client--->
                <cfset client = resolveClient(
                    stagingRows.ClientContact[stagingRows.currentRow]
                )>
                <cfset clientCache[contactCacheKey] = client>
            </cfif>

            <cfif client.found>
                <cftransaction>
                    <!---Insert the data into the enriched table--->
                    <cfset insertEnrichedClient(
                        batchID = arguments.batchID,
                        clientContact =
                            stagingRows.ClientContact[stagingRows.currentRow],
                        recordedHours =
                            stagingRows.RecordedHours[stagingRows.currentRow],
                        client = client
                    )>

                    <!---Update the staging table--->
                    <cfquery datasource="PMSD_SATS">
                        UPDATE dbo.TimekeepingStaging
                        SET
                            ClientEmail = <cfqueryparam
                                value="#client.email#"
                                cfsqltype="cf_sql_varchar">,
                            ClientFirstName = <cfqueryparam
                                value="#client.firstName#"
                                cfsqltype="cf_sql_varchar">,
                            ClientLastName = <cfqueryparam
                                value="#client.lastName#"
                                cfsqltype="cf_sql_varchar">,
                            ProcessingStatus = 'Matched',
                            ErrorMessage = NULL
                        WHERE StagingID = <cfqueryparam
                            value="#stagingID#"
                            cfsqltype="cf_sql_integer">

                        AND ProcessingStatus = 'Pending'
                    </cfquery>
                </cftransaction>
                <cfset stats.matchedCount++>
            <cfelse>
                <!---A blank email used to collapse every person into one unmatched row.--->
                <cfset storedEmail = trim(client.email)>
                <cfif NOT len(storedEmail)>
                    <cfset storedEmail = "c:" & lcase(hash(
                        lcase(trim(stagingRows.ClientContact[stagingRows.currentRow] & "")),
                        "SHA-256"
                    ))>
                </cfif>

                <cfif len(trim(client.errorMessage))>
                    <cfset rowError = client.errorMessage>
                <cfelseif len(trim(client.email))>
                    <cfset rowError = "No matching user found for email: " & client.email>
                <cfelse>
                    <cfset rowError = "No valid email address found in contact">
                </cfif>

                <cftransaction>
                    <!---Insert into the unmatched table--->
                    <cfquery datasource="PMSD_SATS">
                        INSERT INTO dbo.UnmatchedClients (
                            ImportBatchID,
                            ClientEmail,
                            ClientFirstName,
                            ClientLastName,
                            ClientContact,
                            RecordedHours,
                            ErrorMessage,
                            Active
                        )
                        VALUES (
                            <cfqueryparam
                                value="#arguments.batchID#"
                                cfsqltype="cf_sql_integer">,
                            <cfqueryparam
                                value="#storedEmail#"
                                cfsqltype="cf_sql_varchar">,
                            <cfqueryparam
                                value="#client.firstName#"
                                cfsqltype="cf_sql_varchar"
                                null="#NOT len(trim(client.firstName & ""))#">,
                            <cfqueryparam
                                value="#client.lastName#"
                                cfsqltype="cf_sql_varchar"
                                null="#NOT len(trim(client.lastName & ""))#">,
                            <cfqueryparam
                                value="#stagingRows.ClientContact[stagingRows.currentRow]#"
                                cfsqltype="cf_sql_varchar">,
                            <cfqueryparam
                                value="#stagingRows.RecordedHours[stagingRows.currentRow]#"
                                cfsqltype="cf_sql_decimal"
                                scale="2">,
                            <cfqueryparam
                                value="#rowError#"
                                cfsqltype="cf_sql_varchar">,
                            1
                        )
                    </cfquery>

                    <!---Update the staging table--->
                    <cfquery datasource="PMSD_SATS">
                        UPDATE dbo.TimekeepingStaging
                        SET
                            ClientEmail = <cfqueryparam
                                value="#storedEmail#"
                                cfsqltype="cf_sql_varchar">,
                            ClientFirstName = <cfqueryparam
                                value="#client.firstName#"
                                cfsqltype="cf_sql_varchar"
                                null="#NOT len(trim(client.firstName & ""))#">,
                            ClientLastName = <cfqueryparam
                                value="#client.lastName#"
                                cfsqltype="cf_sql_varchar"
                                null="#NOT len(trim(client.lastName & ""))#">,
                            ProcessingStatus = 'Unmatched',
                            ErrorMessage = <cfqueryparam
                                value="#rowError#"
                                cfsqltype="cf_sql_varchar">
                        WHERE StagingID = <cfqueryparam
                            value="#stagingID#"
                            cfsqltype="cf_sql_integer">
                        AND ProcessingStatus = 'Pending'
                    </cfquery>
                </cftransaction>
                <cfset stats.unmatchedCount++>
            </cfif>
        </cfloop>
        <cfreturn stats>
    </cffunction>

    <!---Builds the error message--->
    <cffunction name="buildErrorMessage" access="private" returntype="string" output="false">
        <cfargument name="caughtError" type="any" required="true">
        <cfset var message = "An error occured during the import.">

        <cfif structKeyExists(arguments.caughtError, "message") AND len(arguments.caughtError.message)>
            <cfset message = arguments.caughtError.message>
        </cfif>

        <cfif structKeyExists(arguments.caughtError, "detail") AND len(arguments.caughtError.detail)>
            <cfset message &= " - " & arguments.caughtError.detail>
        </cfif>

        <cfreturn message>
    </cffunction>

    <!---Gets all the batches--->
    <cffunction name="allBatches" access="public" returntype="query">
        <cfquery name="qryAllBatches" datasource="PMSD_SATS">
			SELECT BatchID, FileName, ImportDate 
			FROM dbo.ImportBatch 
			ORDER BY ImportDate DESC
		</cfquery>

        <cfreturn qryAllBatches>
    </cffunction>

    <!---Gets the info for one batch--->
    <cffunction name="batchInfo" access="public" returntype="query">
        <cfargument name="batchFilter" type="numeric" required="true">
        <cfquery name="qryBatchInfo" datasource="PMSD_SATS">
            SELECT * FROM dbo.ImportBatch WHERE BatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
        </cfquery>

        <cfreturn qryBatchInfo>
    </cffunction>

    <!---Gets the stats for all or one specific batch--->
    <cffunction name="stats" access="public" returntype="struct">
        <cfargument name="batchFilter" type="numeric" required="true">

        <cfquery name="qryStats" datasource="PMSD_SATS">
            SELECT
                i.BatchID,
                i.MatchedRecords,
                ISNULL(u.UnmatchedRecords, 0) AS UnmatchedRecords,
                i.SkippedRecords,
                ISNULL(SUM(e.RecordedHours), 0) AS TotalHours
            FROM dbo.ImportBatch i
            LEFT JOIN dbo.TimekeepingEnriched e
                ON e.ImportBatchID = i.BatchID
            LEFT JOIN (
                SELECT
                    ImportBatchID,
                    COUNT(*) AS UnmatchedRecords
                FROM dbo.UnmatchedClients
                WHERE Active = 1
                GROUP BY ImportBatchID
            ) u
                ON u.ImportBatchID = i.BatchID

            <cfif arguments.batchFilter GT 0>
                WHERE i.BatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>

            GROUP BY
                i.BatchID,
                i.MatchedRecords,
                u.UnmatchedRecords,
                i.SkippedRecords
        </cfquery>

        <!---If all batches do a sum of all the data--->
        <cfif arguments.batchFilter EQ 0>

            <cfset dashMatchedRecords = 0>
            <cfset dashUnmatchedRecords = 0>
            <cfset dashSkippedRecords = 0>
            <cfset dashTotalHours = 0>

            <cfloop query="qryStats">
                <cfset dashMatchedRecords += val(qryStats.MatchedRecords)>
                <cfset dashUnmatchedRecords += val(qryStats.UnmatchedRecords)>
                <cfset dashSkippedRecords += val(qryStats.SkippedRecords)>
                <cfset dashTotalHours += val(qryStats.TotalHours)>
            </cfloop>

        <!---Else return the data--->
        <cfelse>
            <cfif qryStats.recordCount GT 0>
                <cfset dashMatchedRecords = val(qryStats.MatchedRecords)>
                <cfset dashUnmatchedRecords = val(qryStats.UnmatchedRecords)>
                <cfset dashSkippedRecords = val(qryStats.SkippedRecords)>
                <cfset dashTotalHours = val(qryStats.TotalHours)>
            <cfelse>
                <cfset dashMatchedRecords = 0>
                <cfset dashUnmatchedRecords = 0>
                <cfset dashSkippedRecords = 0>
                <cfset dashTotalHours = 0>
            </cfif>

        </cfif>

        <cfset processedRecords = dashMatchedRecords + dashUnmatchedRecords>

        <cfset matchRate =
            processedRecords GT 0
            ? (dashMatchedRecords / processedRecords) * 100
            : 0
        >

        <cfreturn {
            "dashTotalRecords" = processedRecords,
            "dashMatchedRecords" = dashMatchedRecords,
            "dashUnmatchedRecords" = dashUnmatchedRecords,
            "dashSkippedRecords" = dashSkippedRecords,
            "dashTotalHours" = dashTotalHours,
            "matchRate" = matchRate
        }>
    </cffunction>

    <!---Gets the directorate's stats for all or one specific batch--->
    <cffunction name="directorateStats" access="public" returntype="query">
        <cfargument name="batchFilter" type="numeric" required="true">

        <cfquery name="qryDirectorateStats" datasource="PMSD_SATS">
            SELECT 
                ISNULL(DirectorateNameE, 'Unknown') AS Directorate,
                COUNT(*) AS RecordCount,
                ISNULL(SUM(RecordedHours), 0) AS TotalHours
            FROM dbo.TimekeepingEnriched
            <cfif arguments.batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
            GROUP BY DirectorateNameE
            ORDER BY SUM(RecordedHours) DESC
        </cfquery>

        <cfreturn qryDirectorateStats>
    </cffunction>

    <!---Returns the unmatched table for all or one specific batch, and everything is ready for the pagination--->
    <cffunction name="unmatchedPages" access="public" returntype="struct" output="false">
        <cfargument name="batchFilter" type="numeric" required="true">
        <cfargument name="startRow" type="numeric" required="true">
        <cfargument name="pageSize" type="numeric" required="true">
        <cfargument name="tab" type="string" required="true">

        <cfset var offset = max(arguments.startRow - 1, 0)>
        <cfset var qryUnmatched = "">
        <cfset var statsUnmatched = structNew("ordered")>
        <cfset var emailKey = "">
        <cfset var totalItems = 0>
        <cfset var totalRows = 0>

        <!---Puts all client's emails and return the information from the unmatched table--->
        <cfquery name="qryUnmatched" datasource="PMSD_SATS">
            WITH GroupedUnmatched AS (
                SELECT
                    LOWER(LTRIM(RTRIM(ClientEmail))) AS ClientEmail,
                    COUNT(*) AS Occurrences,
                    SUM(COALESCE(RecordedHours, 0)) AS Hours,
                    MAX(ClientContact) AS ClientContact,
                    MAX(ErrorMessage) AS ErrorMessage
                FROM dbo.UnmatchedClients
                <cfif compareNoCase(arguments.tab, "Active") EQ 0>
                    WHERE Active = 1
                <cfelse>
                    WHERE Active = 0
                </cfif>

                <cfif arguments.batchFilter GT 0>
                    AND ImportBatchID =
                        <cfqueryparam
                            value="#arguments.batchFilter#"
                            cfsqltype="cf_sql_integer">
                </cfif>

                GROUP BY LOWER(LTRIM(RTRIM(ClientEmail)))
            )

            SELECT
                ClientEmail,
                Occurrences,
                ClientContact,
                Hours,
                ErrorMessage,
                COUNT(*) OVER() AS TotalEmails,
                SUM(Occurrences) OVER() AS TotalRows
            FROM GroupedUnmatched
            ORDER BY Occurrences DESC, ClientEmail ASC
            OFFSET
                <cfqueryparam value="#offset#" cfsqltype="cf_sql_integer">
                ROWS
            FETCH NEXT
                <cfqueryparam value="#arguments.pageSize#" cfsqltype="cf_sql_integer">
                ROWS ONLY
        </cfquery>

        <cfloop query="qryUnmatched">
            <cfset emailKey = trim(qryUnmatched.ClientEmail)>
            <cfset statsUnmatched[emailKey] = {
                occurrences = val(qryUnmatched.Occurrences),
                clientContact = qryUnmatched.ClientContact,
                hours = val(qryUnmatched.Hours),
                errorMessage = qryUnmatched.ErrorMessage
            }>
        </cfloop>

        <cfif qryUnmatched.recordCount GT 0>
            <cfset totalItems = val(qryUnmatched.TotalEmails[1])>
            <cfset totalRows = val(qryUnmatched.TotalRows[1])>
        </cfif>

        <cfreturn {
            items = statsUnmatched,
            totalItems = totalItems,
            totalRows = totalRows
        }>
    </cffunction>

    <!---Edits the email address in all lines containing this customer's email address--->
    <cffunction name="editEmail" access="public" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="oldEmail" type="string" required="true">
        <cfargument name="newEmail" type="string" required="true">

        <cfset var result = {
            success = false,
            found = false,
            processedRecords = 0,
            matchedRecords = 0,
            unmatchedRecords = 0,
            errorMessage = ""
        }>

        <cfset var normalizedOldEmail = lcase(trim(arguments.oldEmail))>
        <cfset var normalizedNewEmail = lcase(trim(arguments.newEmail))>
        <cfset var unmatchedRows = queryNew("")>
        <cfset var client = {}>
        <cfset var currentUnmatchedID = 0>

        <cftry>
            <cfquery name="unmatchedRows" datasource="PMSD_SATS">
                SELECT
                    UnmatchedID,
                    ImportBatchID,
                    ClientEmail,
                    ClientContact,
                    RecordedHours,
                    ErrorMessage,
                    Active
                FROM dbo.UnmatchedClients
                WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                AND LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam value="#normalizedOldEmail#" cfsqltype="cf_sql_varchar">
                AND Active = 1
                ORDER BY UnmatchedID
            </cfquery>

            <!---Finds the right client--->
            <cfset client = resolveClient(normalizedNewEmail)>

            <!---If the client exists, insert the client into the enriched table--->
            <cfif client.found>
                <cftransaction>
                    <cfloop query="unmatchedRows">

                        <cfset currentUnmatchedID = unmatchedRows.UnmatchedID[unmatchedRows.currentRow]>

                        <cfquery datasource="PMSD_SATS">
                            INSERT INTO dbo.TimekeepingEnriched (
                                ImportBatchID,
                                Category,
                                ProjectMatter,
                                ClientContact,
                                ClientEmail,
                                ClientFirstName,
                                ClientLastName,
                                ClientUserID,
                                RecordedHours,
                                DirectorateNameE,
                                DirectorateNameF,
                                DirectorateAcronymE,
                                DirectorateAcronymF,
                                DirectorateID,
                                DivisionNameE,
                                DivisionNameF,
                                DivisionAcronymE,
                                DivisionAcronymF,
                                DivisionID,
                                BranchNameE,
                                BranchNameF,
                                BranchAcronymE,
                                BranchAcronymF,
                                BranchID,
                                SectionNameE,
                                SectionNameF,
                                SectionAcronymE,
                                SectionAcronymF,
                                SectionID,
                                ClientPhone,
                                PositionLevel,
                                IsManager,
                                MatchStatus,
                                ProcessedDate
                            )
                            VALUES (
                                <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">,
                                <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
                                <cfqueryparam value="" cfsqltype="cf_sql_varchar">,
                                <cfqueryparam value="#unmatchedRows.ClientContact[unmatchedRows.currentRow]#" cfsqltype="cf_sql_varchar">,
                                <cfqueryparam value="#client.email#" cfsqltype="cf_sql_varchar">,
                                <cfqueryparam value="#client.firstName#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.firstName))#">,
                                <cfqueryparam value="#client.lastName#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.lastName))#">,
                                <cfqueryparam value="#client.userID#" cfsqltype="cf_sql_varchar">,
                                <cfqueryparam value="#unmatchedRows.RecordedHours[unmatchedRows.currentRow]#" cfsqltype="cf_sql_decimal" scale="2">,
                                <cfqueryparam value="#client.directorateNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.directorateNameE))#">,
                                <cfqueryparam value="#client.directorateNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.directorateNameF))#">,
                                <cfqueryparam value="#client.directorateAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.directorateAcronymE))#">,
                                <cfqueryparam value="#client.directorateAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.directorateAcronymF))#">,
                                <cfqueryparam value="#client.directorateID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(client.directorateID)#">,
                                <cfqueryparam value="#client.divisionNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.divisionNameE))#">,
                                <cfqueryparam value="#client.divisionNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.divisionNameF))#">,
                                <cfqueryparam value="#client.divisionAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.divisionAcronymE))#">,
                                <cfqueryparam value="#client.divisionAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.divisionAcronymF))#">,
                                <cfqueryparam value="#client.divisionID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(client.divisionID)#">,
                                <cfqueryparam value="#client.branchNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.branchNameE))#">,
                                <cfqueryparam value="#client.branchNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.branchNameF))#">,
                                <cfqueryparam value="#client.branchAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.branchAcronymE))#">,
                                <cfqueryparam value="#client.branchAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.branchAcronymF))#">,
                                <cfqueryparam value="#client.branchID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(client.branchID)#">,
                                <cfqueryparam value="#client.sectionNameE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.sectionNameE))#">,
                                <cfqueryparam value="#client.sectionNameF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.sectionNameF))#">,
                                <cfqueryparam value="#client.sectionAcronymE#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.sectionAcronymE))#">,
                                <cfqueryparam value="#client.sectionAcronymF#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.sectionAcronymF))#">,
                                <cfqueryparam value="#client.sectionID#" cfsqltype="cf_sql_integer" null="#NOT isNumeric(client.sectionID)#">,
                                <cfqueryparam value="#client.phone#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.phone))#">,
                                <cfqueryparam value="#client.positionLevel#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.positionLevel))#">,
                                <cfqueryparam value="#client.isManager#" cfsqltype="cf_sql_bit" null="#NOT isBoolean(client.isManager) AND NOT isNumeric(client.isManager)#">,
                                'Matched',
                                GETDATE()
                            )
                        </cfquery>

                        <cfquery datasource="PMSD_SATS">
                            DELETE FROM dbo.UnmatchedClients
                            WHERE UnmatchedID = <cfqueryparam value="#currentUnmatchedID#" cfsqltype="cf_sql_integer">
                        </cfquery>
                    </cfloop>

                    <cfquery datasource="PMSD_SATS">
                        UPDATE dbo.TimekeepingStaging
                        SET
                            ClientEmail = <cfqueryparam value="#client.email#" cfsqltype="cf_sql_varchar">,
                            ClientFirstName = <cfqueryparam value="#client.firstName#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.firstName))#">,
                            ClientLastName = <cfqueryparam value="#client.lastName#" cfsqltype="cf_sql_varchar" null="#NOT len(trim(client.lastName))#">,
                            ProcessingStatus = 'Matched',
                            ErrorMessage = NULL
                        WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                        AND ProcessingStatus = 'Unmatched'
                        AND LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam value="#normalizedOldEmail#" cfsqltype="cf_sql_varchar">
                    </cfquery>

                    <cfset recalculateBatchStats(arguments.batchID)>
                </cftransaction>

                <cfset result.found = true>
                <cfset result.matchedRecords = unmatchedRows.recordCount>

            <!---Else put the client back in the unmatched table with the new email and error message--->
            <cfelse>
                <cftransaction>
                    <cfquery datasource="PMSD_SATS">
                        UPDATE dbo.UnmatchedClients
                        SET
                            ClientEmail = <cfqueryparam value="#normalizedNewEmail#" cfsqltype="cf_sql_varchar">,
                            ErrorMessage = <cfqueryparam value="No matching user found for email: #normalizedNewEmail#" cfsqltype="cf_sql_varchar">
                        WHERE ImportBatchID = <cfqueryparam      value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                        AND LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam value="#normalizedOldEmail#" cfsqltype="cf_sql_varchar">
                    </cfquery>

                    <cfquery datasource="PMSD_SATS">
                        UPDATE dbo.TimekeepingStaging
                        SET
                            ClientEmail = <cfqueryparam value="#normalizedNewEmail#" cfsqltype="cf_sql_varchar">,
                            ProcessingStatus = 'Unmatched',
                            ErrorMessage = <cfqueryparam value="No matching user found for email: #normalizedNewEmail#" cfsqltype="cf_sql_varchar">
                        WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                        AND ProcessingStatus = 'Unmatched'
                        AND LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam value="#normalizedOldEmail#" cfsqltype="cf_sql_varchar">
                    </cfquery>
                </cftransaction>

                <cfset result.unmatchedRecords = unmatchedRows.recordCount>
            </cfif>

            <cfset result.success = true>
            <cfset result.processedRecords = unmatchedRows.recordCount>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.errorMessage = buildErrorMessage(cfcatch)>
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---Updates the batch with the new info--->
    <cffunction name="recalculateBatchStats" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">

        <cfquery datasource="PMSD_SATS">
            UPDATE batch
            SET
                MatchedRecords = (
                    SELECT COUNT(*)
                    FROM dbo.TimekeepingEnriched enriched
                    WHERE enriched.ImportBatchID = batch.BatchID
                ),
                UnmatchedRecords = (
                    SELECT COUNT(*)
                    FROM dbo.UnmatchedClients unmatched
                    WHERE unmatched.ImportBatchID = batch.BatchID
                    AND unmatched.Active = 1
                )
            FROM dbo.ImportBatch batch
            WHERE batch.BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
    </cffunction>

    <!---Deletes the unmatched client--->
    <cffunction name="deleteClient" access="public" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="email" type="string" required="true">

        <cfset var result = {
            success = false,
            errorMessage = ""
        }>

        <cftry>
            <!---Sets the client to inactive to 'delete' it--->
            <cfquery name="qryDelete" datasource="PMSD_SATS">
                UPDATE dbo.UnmatchedClients
                SET
                    Active = 0,
                    DeletedDate = GETDATE(),
                    DeletedBy = <cfqueryparam value="" cfsqltype="cf_sql_varchar">
                WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                AND LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam value="#arguments.email#" cfsqltype="cf_sql_varchar">
                AND Active = 1
            </cfquery>

            <!---Recalculates the batch's stats--->
            <cfset recalculateBatchStats(arguments.batchID)>

            <cfset result.success = true>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.errorMessage = buildErrorMessage(cfcatch)>
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---Deletes an import batch and all related records--->
    <cffunction name="deleteBatch" access="public" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">

        <cfset var result = {
            success = false,
            errorMessage = ""
        }>
        <cfset var existingBatch = queryNew("")>

        <cftry>
            <cfif arguments.batchID LTE 0>
                <cfthrow
                    type="Import.InvalidBatch"
                    message="A valid batch ID is required to delete.">
            </cfif>

            <cfquery name="existingBatch" datasource="PMSD_SATS">
                SELECT BatchID
                FROM dbo.ImportBatch
                WHERE BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
            </cfquery>

            <cfif existingBatch.recordCount EQ 0>
                <cfthrow
                    type="Import.BatchNotFound"
                    message="Batch ###arguments.batchID# was not found.">
            </cfif>

            <cftransaction>
                <cfquery datasource="PMSD_SATS">
                    DELETE FROM dbo.TimekeepingEnriched
                    WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                </cfquery>

                <cfquery datasource="PMSD_SATS">
                    DELETE FROM dbo.TimekeepingStaging
                    WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                </cfquery>

                <cfquery datasource="PMSD_SATS">
                    DELETE FROM dbo.UnmatchedClients
                    WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                </cfquery>

                <cfquery datasource="PMSD_SATS">
                    DELETE FROM dbo.ImportBatch
                    WHERE BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                </cfquery>
            </cftransaction>

            <cfset result.success = true>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.errorMessage = buildErrorMessage(cfcatch)>
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---Returns all the directorates--->
    <cffunction name="getDirectorates" access="public" returntype="query">
        <cfquery name="qryDirectorate" datasource="#application.branchDatasource#">
            SELECT ID, NameE FROM dbo.tblDirectorates
            WHERE BranchID = 1 AND DateTo is null AND AcronymE != 'RP'
            ORDER BY NameE
        </cfquery>

        <cfreturn qryDirectorate>
    </cffunction>

    <!---Force add an umatched client into a selected directorate--->
    <cffunction name="forceAdd" access="public" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="directorateID" type="numeric" required="true">
        <cfargument name="email" type="string" required="true">

        <cfset var result = {
            success = false,
            errorMessage = ""
        }>

        <cfset var client = {}>
        <cfset var normalizedEmail = lcase(trim(arguments.email))>
        
        <cftry>
            <cfquery name="qryDirectorateInfo" datasource="#application.branchDatasource#">
                SELECT * FROM dbo.tblDirectorates
                WHERE ID = <cfqueryparam value="#arguments.directorateID#" cfsqltype="cf_sql_integer">
            </cfquery>

            <cfif qryDirectorateInfo.recordCount NEQ 1>
                <cfthrow
                    type="ForceAdd.InvalidDirectorate"
                    message="The directorate was not found">
            </cfif>

            <!---Gets the user info--->
            <cfquery name="qryUserInfo" datasource="PMSD_SATS">
                SELECT
                    StagingID,
                    ClientContact,
                    RecordedHours
                FROM dbo.TimekeepingStaging
                WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                AND ProcessingStatus = 'Unmatched'
                <cfif NOT len(normalizedEmail)>
                    AND NULLIF(LTRIM(RTRIM(ClientEmail)), '') IS NULL
                <cfelse>
                    AND LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam
                        value="#normalizedEmail#"
                        cfsqltype="cf_sql_varchar">
                </cfif>
                ORDER BY RowNumber, StagingID
            </cfquery>

            <cfif qryUserInfo.recordCount EQ 0>
                <cfthrow
                    type="ForceAdd.NoUnmatchedRecords"
                    message="No unmatched records was found for this email in this batch.">
            </cfif>

            <cfset client = {
                found = true,
                email = normalizedEmail,
                userID = "N/A",
                firstName = "",
                lastName = "",
                phone = "",
                positionLevel = "",
                isManager = false,
                directorateNameE = qryDirectorateInfo.NameE[1],
                directorateNameF = qryDirectorateInfo.NameF[1],
                directorateAcronymE = qryDirectorateInfo.AcronymE[1],
                directorateAcronymF = qryDirectorateInfo.AcronymF[1],
                directorateID = arguments.directorateID,
                divisionNameE = "",
                divisionNameF = "",
                divisionAcronymE = "",
                divisionAcronymF = "",
                divisionID = "",
                branchNameE = "",
                branchNameF = "",
                branchAcronymE = "",
                branchAcronymF = "",
                branchID = "",
                sectionNameE = "",
                sectionNameF = "",
                sectionAcronymE = "",
                sectionAcronymF = "",
                sectionID = ""
            }>

            <cftransaction>
                <!---Loops through the client's rows and inserts into the enriched table--->
                <cfloop query="qryUserInfo">
                    <cfset currentStagingID = qryUserInfo.StagingID[qryUserInfo.currentRow]>

                    <!---Inserts into the enriched table--->
                    <cfset insertEnrichedClient(
                        batchID = arguments.batchID,
                        clientContact = qryUserInfo.ClientContact[qryUserInfo.currentRow],
                        recordedHours = qryUserInfo.RecordedHours[qryUserInfo.currentRow],
                        client = client
                    )>

                    <!---Updates the client's info in the staging table--->
                    <cfquery datasource="PMSD_SATS">
                        UPDATE dbo.TimekeepingStaging
                        SET
                            ClientEmail = <cfqueryparam value="#normalizedEmail#" cfsqltype="cf_sql_varchar" null="#NOT len(arguments.email)#">,
                            ClientFirstName = NULL,
                            ClientLastName = NULL,
                            ProcessingStatus = 'Matched',
                            ErrorMessage = NULL
                        WHERE StagingID = <cfqueryparam value="#currentStagingID#" cfsqltype="cf_sql_integer">
                        AND ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                        AND ProcessingStatus = 'Unmatched'
                    </cfquery>
                </cfloop>

                <!---Sets the client to inactive--->
                <cfquery datasource="PMSD_SATS">
                    UPDATE dbo.UnmatchedClients
                    SET
                        Active = 0,
                        DeletedDate = GETDATE()
                    WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                    <cfif NOT len(normalizedEmail)>
                        AND NULLIF(LTRIM(RTRIM(ClientEmail)), '') IS NULL
                    <cfelse>
                        AND LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam value="#normalizedEmail#" cfsqltype="cf_sql_varchar">
                    </cfif>
                    AND Active = 1
                </cfquery>

                <!---Recalculates the batch's stats--->
                <cfset recalculateBatchStats(arguments.batchID)>
            </cftransaction>
            
            <cfset result.success = true>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.errorMessage = buildErrorMessage(cfcatch)>
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---Recovers the selected client--->
    <cffunction name="recoverClient" access="public" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="email" type="string" required="true">

        <cfset var result = {
            success = false,
            errorMessage = ""
        }>

        <cfset var normalizedEmail = lcase(trim(arguments.email))>
        <cftry>
            <!---Gets the right client--->
            <cfquery name="qryResolve" datasource="PMSD_SATS">
                UPDATE dbo.UnmatchedClients
                SET Active = 1
                WHERE LOWER(LTRIM(RTRIM(ClientEmail))) = <cfqueryparam value="#normalizedEmail#" cfsqltype="cf_sql_varchar">
            </cfquery>

            <!---Recalculates the batch's info--->
            <cfset recalculateBatchStats(arguments.batchID)>

            <cfset result.success = true>

            <cfcatch type="any">
                <cfset result.success = false>
                <cfset result.errorMessage = buildErrorMessage(cfcatch)>
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <!---Gets the stats for the export page--->
    <cffunction name="quickStatistics" access="public" returntype="query" output="false">
        <cfargument name="batchFilter" type="numeric" required="true">

        <cfquery name="qryStats" datasource="PMSD_SATS">
            SELECT 
                (SELECT COUNT(*) FROM dbo.TimekeepingEnriched 
                    <cfif arguments.batchFilter GT 0>WHERE ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer"></cfif>) AS MatchedCount,
                (SELECT COUNT(*) FROM dbo.UnmatchedClients 
                    <cfif arguments.batchFilter GT 0>WHERE ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer"> AND Active = 1 </cfif>) AS UnmatchedCount,
                (SELECT COUNT(DISTINCT DirectorateNameE) FROM dbo.TimekeepingEnriched 
                    <cfif arguments.batchFilter GT 0>WHERE ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer"></cfif>) AS DirectorateCount
        </cfquery>

        <cfreturn qryStats>
    </cffunction>

    <!---Prepares to export the unmatched table--->
    <cffunction name="unmatchedExport" access="public" returntype="query" output="false">
        <cfargument name="batchFilter" type="numeric" required="true">

        <cfquery name="qryExport" datasource="PMSD_SATS">
            SELECT 
                ClientEmail,
                ClientFirstName,
                ClientLastName,
                ClientContact,
                RecordedHours
            FROM dbo.UnmatchedClients
            WHERE Active = 1
            <cfif arguments.batchFilter GT 0>
                AND ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
            ORDER BY ClientLastName, ClientFirstName
        </cfquery>

        <cfreturn qryExport>
    </cffunction>

    <!---Prepares to export the enriched table by directorate--->
    <cffunction name="directorateExport" access="public" returntype="query" output="false">
        <cfargument name="batchFilter" type="numeric" required="true">

        <cfquery name="qryExport" datasource="PMSD_SATS">
            SELECT 
                DirectorateNameE AS Directorate,
                DirectorateAcronymE AS Acronym,
                ClientFirstName AS FirstName,
                ClientLastName AS LastName,
                ClientEmail AS Email,
                RecordedHours AS Hours
            FROM dbo.TimekeepingEnriched
            <cfif arguments.batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
            ORDER BY DirectorateNameE, ClientLastName, ClientFirstName
        </cfquery>

        <cfreturn qryExport>
    </cffunction>

    <!---Prepares to export all of the enriched table--->
    <cffunction name="allExport" access="public" returntype="query" output="false">
        <cfargument name="batchFilter" type="numeric" required="true">

        <cfquery name="qryExport" datasource="PMSD_SATS">
            SELECT 
                ClientFirstName,
                ClientLastName,
                ClientEmail,
                ClientUserID,
                RecordedHours,
                DirectorateNameE,
                DirectorateAcronymE,
                DivisionNameE,
                DivisionAcronymE,
                BranchNameE,
                BranchAcronymE,
                SectionNameE,
                SectionAcronymE,
                PositionLevel,
                IsManager
            FROM dbo.TimekeepingEnriched
            <cfif arguments.batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
            ORDER BY DirectorateNameE, ClientLastName, ClientFirstName
        </cfquery>

        <cfreturn qryExport>
    </cffunction>

    <!---Counts all of the batches--->
    <cffunction name="importCount" access="public" returntype="query" output="false">
        <cfquery name="qryCount" datasource="PMSD_SATS">
            SELECT COUNT(*) AS TotalCount
            FROM dbo.ImportBatch
        </cfquery>

        <cfreturn qryCount>
    </cffunction>

    <!---Returns all of the recents import--->
    <cffunction name="recentImport" access="public" returntype="query" output="false">
        <cfargument name="startRow" type="numeric" required="true">
        <cfargument name="pageSize" type="numeric" required="true">

        <cfquery name="qryRecents" datasource="PMSD_SATS">
            SELECT
                BatchID,
                FileName,
                ImportDate,
                COALESCE(TotalRecords, 0) AS TotalRecords,
                COALESCE(MatchedRecords, 0) AS MatchedRecords,
                COALESCE(UnmatchedRecords, 0) AS UnmatchedRecords,
                ProcessingStatus,
                ImportedBy
            FROM dbo.ImportBatch
            ORDER BY ImportDate DESC
            OFFSET <cfqueryparam
                value="#arguments.startRow - 1#"
                cfsqltype="cf_sql_integer"> ROWS
            FETCH NEXT <cfqueryparam value="#arguments.pageSize#" cfsqltype="cf_sql_integer"> 
            ROWS ONLY
        </cfquery>

        <cfreturn qryRecents>
    </cffunction>
</cfcomponent>