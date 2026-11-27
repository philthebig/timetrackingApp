<cfcomponent>
    <!---Main function, calls all necessary functions--->
    <cffunction name="processUpload" access="public" returntype="struct" output="false">
        <cfsetting requesttimeout="600">
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
        <cfset var sourceGrid = {}>
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

            <!---Keeps the original workbook so export can add one column to that file.--->
            <cfset storeOriginalUpload(batchID, filePath)>

            <!---Reads every column from the data sheet and keeps it for export.--->
            <cfset sourceGrid = readSourceGrid(filePath)>
            <cfset saveSourceGrid(batchID, sourceGrid)>

            <!---Imports and inserts the Excel file's data--->
            <cfset importStats = importStagingRows(
                batchID = batchID,
                sourceGrid = sourceGrid
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

    <!---Keeps a byte-for-byte copy of the uploaded workbook.--->
    <cffunction name="storeOriginalUpload" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="filePath" type="string" required="true">

        <cfset var sourceDirectory = expandPath("./uploads/sources/")>
        <cfset var extension = lcase(listLast(arguments.filePath, "."))>
        <cfset var storedPath = "">

        <cfset ensureSourceStorage()>
        <cfif NOT directoryExists(sourceDirectory)>
            <cfdirectory action="create" directory="#sourceDirectory#">
        </cfif>
        <cfif NOT len(extension)>
            <cfset extension = "xlsx">
        </cfif>

        <cfset storedPath = sourceDirectory & "batch-" & arguments.batchID & "." & extension>
        <cffile action="copy" source="#arguments.filePath#" destination="#storedPath#" nameconflict="overwrite">

        <cfquery datasource="PMSD_SATS">
            UPDATE dbo.ImportBatch
            SET SourceFile = <cfqueryparam value="#storedPath#" cfsqltype="cf_sql_varchar">
            WHERE BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
        </cfquery>
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

    <!---Creates the tables that keep the original spreadsheet.--->
    <cffunction name="ensureSourceStorage" access="private" returntype="void" output="false">
        <cfif structKeyExists(application, "sourceStorageReady") AND application.sourceStorageReady>
            <cfreturn>
        </cfif>

        <cfquery datasource="PMSD_SATS">
            IF COL_LENGTH('dbo.ImportBatch', 'SourceHeaders') IS NULL
                ALTER TABLE dbo.ImportBatch ADD SourceHeaders NVARCHAR(MAX) NULL
        </cfquery>

        <cfquery datasource="PMSD_SATS">
            IF COL_LENGTH('dbo.ImportBatch', 'SourceFile') IS NULL
                ALTER TABLE dbo.ImportBatch ADD SourceFile NVARCHAR(500) NULL
        </cfquery>

        <cfquery datasource="PMSD_SATS">
            IF OBJECT_ID('dbo.TimekeepingSourceRow', 'U') IS NULL
            BEGIN
                CREATE TABLE dbo.TimekeepingSourceRow (
                    SourceRowID INT IDENTITY(1,1) PRIMARY KEY,
                    ImportBatchID INT NOT NULL,
                    RowNumber INT NOT NULL,
                    SourceData NVARCHAR(MAX) NOT NULL
                )
            END
        </cfquery>

        <cfquery datasource="PMSD_SATS">
            IF NOT EXISTS (
                SELECT 1
                FROM sys.indexes
                WHERE name = 'IX_TimekeepingSourceRow_Batch'
                AND object_id = OBJECT_ID('dbo.TimekeepingSourceRow')
            )
                CREATE INDEX IX_TimekeepingSourceRow_Batch
                ON dbo.TimekeepingSourceRow(ImportBatchID, RowNumber)
        </cfquery>

        <cfset application.sourceStorageReady = true>
    </cffunction>

    <!---Reads the uploaded sheet, including the original column names.--->
    <cffunction name="readSourceGrid" access="private" returntype="struct" output="false">
        <cfargument name="filePath" type="string" required="true">

        <cfset var workbook = spreadsheetRead(arguments.filePath)>
        <cfset var poiBook = "">
        <cfset var sheetIndex = 0>
        <cfset var sheet = "">
        <cfset var headers = []>
        <cfset var formats = []>
        <cfset var rows = []>
        <cfset var contactIndex = 0>
        <cfset var hoursIndex = 0>
        <cfset var lastRow = 0>
        <cfset var rowIndex = 0>
        <cfset var row = "">
        <cfset var cells = []>
        <cfset var columnIndex = 0>
        <cfset var rawCell = "">
        <cfset var parsed = {}>
        <cfset var hasValue = false>
        <cfset var headerIndex = 0>
        <cfset var format = "">
        <cfset var grid = {}>

        <cftry>
            <cfset poiBook = workbook.getWorkBook()>
            <cfcatch type="any">
                <cftry>
                    <cfset poiBook = workbook.getWorkbook()>
                    <cfcatch type="any">
                        <cfthrow
                            type="Import.SpreadsheetReadFailed"
                            message="The Excel file could not be opened."
                            detail="#cfcatch.message#">
                    </cfcatch>
                </cftry>
            </cfcatch>
        </cftry>

        <cfset sheetIndex = chooseDataSheet(poiBook)>
        <cfset sheet = poiBook.getSheetAt(javacast("int", sheetIndex))>
        <cfset headers = readHeaderLabels(sheet)>

        <cfif NOT arrayLen(headers)>
            <cfset closeWorkbook(poiBook)>
            <cfthrow
                type="Import.EmptySpreadsheet"
                message="No data found in the Excel file.">
        </cfif>

        <cfloop from="1" to="#arrayLen(headers)#" index="headerIndex">
            <cfif NOT len(headers[headerIndex])>
                <cfset headers[headerIndex] = "Column #headerIndex#">
            </cfif>
            <cfset arrayAppend(formats, "")>
        </cfloop>

        <cfset contactIndex = findHeaderIndex(headers, "contact")>
        <cfset hoursIndex = findHeaderIndex(headers, "hours")>

        <cfif contactIndex LT 1>
            <cfset closeWorkbook(poiBook)>
            <cfthrow
                type="Import.ContactColumnMissing"
                message="The contact column was not found.">
        </cfif>
        <cfif hoursIndex LT 1>
            <cfset closeWorkbook(poiBook)>
            <cfthrow
                type="Import.HoursColumnMissing"
                message="The hours column was not found.">
        </cfif>

        <cfset lastRow = sheet.getLastRowNum()>
        <cfloop from="1" to="#lastRow#" index="rowIndex">
            <cfset row = sheet.getRow(javacast("int", rowIndex))>
            <cfset cells = []>
            <cfset hasValue = false>

            <cfif isNull(row)>
                <cfcontinue>
            </cfif>

            <cfloop from="0" to="#arrayLen(headers) - 1#" index="columnIndex">
                <cfset rawCell = row.getCell(javacast("int", columnIndex))>
                <cfif isNull(rawCell)>
                    <cfset parsed = {t = "s", v = ""}>
                <cfelse>
                    <cfset parsed = readPoiCell(rawCell)>
                    <cfset format = readCellFormat(rawCell)>
                    <cfif len(format) AND NOT len(formats[columnIndex + 1])>
                        <cfset formats[columnIndex + 1] = format>
                    </cfif>
                </cfif>
                <cfif len(trim(parsed.v & ""))>
                    <cfset hasValue = true>
                </cfif>
                <cfset arrayAppend(cells, parsed)>
            </cfloop>

            <cfif hasValue>
                <cfset arrayAppend(rows, {
                    rowNumber = rowIndex + 1,
                    cells = cells
                })>
            </cfif>
        </cfloop>

        <cfloop from="1" to="#arrayLen(formats)#" index="headerIndex">
            <cfif NOT len(formats[headerIndex])>
                <cfset formats[headerIndex] = "General">
            </cfif>
        </cfloop>

        <cfif NOT arrayLen(rows)>
            <cfset closeWorkbook(poiBook)>
            <cfthrow
                type="Import.EmptySpreadsheet"
                message="No data found in the Excel file.">
        </cfif>

        <cfset grid = {
            sheetName = poiBook.getSheetName(javacast("int", sheetIndex)) & "",
            columns = headers,
            formats = formats,
            contactIndex = contactIndex,
            hoursIndex = hoursIndex,
            rows = rows
        }>
        <cfset closeWorkbook(poiBook)>
        <cfreturn grid>
    </cffunction>

    <!---Prefers the sheet named data, which is the uploaded timekeeping report.--->
    <cffunction name="chooseDataSheet" access="private" returntype="numeric" output="false">
        <cfargument name="poiBook" type="any" required="true">

        <cfset var sheetCount = arguments.poiBook.getNumberOfSheets()>
        <cfset var sheetIndex = 0>
        <cfset var headers = []>
        <cfset var bestIndex = -1>
        <cfset var bestRows = -1>
        <cfset var rowCount = 0>

        <cfif sheetCount LTE 0>
            <cfthrow
                type="Import.EmptySpreadsheet"
                message="The Excel file has no worksheets.">
        </cfif>

        <cfloop from="0" to="#sheetCount - 1#" index="sheetIndex">
            <cfif compareNoCase(arguments.poiBook.getSheetName(javacast("int", sheetIndex)), "data") EQ 0>
                <cfreturn sheetIndex>
            </cfif>
        </cfloop>

        <cfif sheetCount EQ 1>
            <cfreturn 0>
        </cfif>

        <cfloop from="0" to="#sheetCount - 1#" index="sheetIndex">
            <cfset headers = readHeaderLabels(arguments.poiBook.getSheetAt(javacast("int", sheetIndex)))>
            <cfif findNoCase("contact", arrayToList(headers, "|")) GT 0>
                <cfset rowCount = arguments.poiBook.getSheetAt(javacast("int", sheetIndex)).getLastRowNum()>
                <cfif rowCount GT bestRows>
                    <cfset bestIndex = sheetIndex>
                    <cfset bestRows = rowCount>
                </cfif>
            </cfif>
        </cfloop>

        <cfif bestIndex GTE 0>
            <cfreturn bestIndex>
        </cfif>

        <cfreturn 0>
    </cffunction>

    <!---Reads the header text in sheet order.--->
    <cffunction name="readHeaderLabels" access="private" returntype="array" output="false">
        <cfargument name="sheet" type="any" required="true">

        <cfset var headerRow = arguments.sheet.getRow(javacast("int", 0))>
        <cfset var labels = []>
        <cfset var lastColumn = 0>
        <cfset var columnIndex = 0>
        <cfset var rawCell = "">
        <cfset var label = "">

        <cfif isNull(headerRow)>
            <cfreturn labels>
        </cfif>

        <cfset lastColumn = headerRow.getLastCellNum()>
        <cfif NOT isNumeric(lastColumn) OR lastColumn LTE 0>
            <cfreturn labels>
        </cfif>

        <cfloop from="0" to="#lastColumn - 1#" index="columnIndex">
            <cfset rawCell = headerRow.getCell(javacast("int", columnIndex))>
            <cfif isNull(rawCell)>
                <cfset label = "">
            <cfelse>
                <cfset label = trim(readPoiCell(rawCell).v & "")>
            </cfif>
            <cfset arrayAppend(labels, label)>
        </cfloop>

        <cfloop condition="arrayLen(labels) GT 0 AND NOT len(trim(labels[arrayLen(labels)] & ''))">
            <cfset arrayDeleteAt(labels, arrayLen(labels))>
        </cfloop>

        <cfreturn labels>
    </cffunction>

    <!---Turns one Excel cell into a value that can be stored and written back.--->
    <cffunction name="readPoiCell" access="private" returntype="struct" output="false">
        <cfargument name="cell" type="any" required="true">

        <cfset var result = {t = "s", v = ""}>
        <cfset var typeName = "">
        <cfset var rawNumber = 0>

        <cfif isNull(arguments.cell)>
            <cfreturn result>
        </cfif>

        <cfset typeName = poiTypeName(arguments.cell.getCellType())>
        <cfif typeName EQ "FORMULA">
            <cfset typeName = poiTypeName(arguments.cell.getCachedFormulaResultType())>
        </cfif>

        <cfif typeName EQ "BLANK" OR typeName EQ "ERROR">
            <cfreturn result>
        </cfif>

        <cfif typeName EQ "BOOLEAN">
            <cfset result.v = arguments.cell.getBooleanCellValue() ? "TRUE" : "FALSE">
            <cfreturn result>
        </cfif>

        <cfif typeName EQ "NUMERIC">
            <cfset rawNumber = arguments.cell.getNumericCellValue()>
            <cftry>
                <cfif createObject("java", "org.apache.poi.ss.usermodel.DateUtil").isCellDateFormatted(arguments.cell)>
                    <cfset result.t = "d">
                    <cfset result.v = scaleNumber(rawNumber, 8)>
                    <cfreturn result>
                </cfif>
                <cfcatch type="any">
                </cfcatch>
            </cftry>
            <cfset result.t = "n">
            <cfset result.v = scaleNumber(rawNumber, 4)>
            <cfreturn result>
        </cfif>

        <cftry>
            <cfset result.v = arguments.cell.getStringCellValue() & "">
            <cfcatch type="any">
                <cfset result.v = createObject("java", "org.apache.poi.ss.usermodel.DataFormatter").init().formatCellValue(arguments.cell) & "">
            </cfcatch>
        </cftry>

        <cfreturn result>
    </cffunction>

    <cffunction name="poiTypeName" access="private" returntype="string" output="false">
        <cfargument name="cellType" type="any" required="true">

        <cfif isSimpleValue(arguments.cellType)>
            <cfif arguments.cellType EQ 0>
                <cfreturn "NUMERIC">
            <cfelseif arguments.cellType EQ 1>
                <cfreturn "STRING">
            <cfelseif arguments.cellType EQ 2>
                <cfreturn "FORMULA">
            <cfelseif arguments.cellType EQ 4>
                <cfreturn "BOOLEAN">
            </cfif>
            <cfreturn "BLANK">
        </cfif>

        <cfreturn uCase(arguments.cellType.toString())>
    </cffunction>

    <cffunction name="scaleNumber" access="private" returntype="numeric" output="false">
        <cfargument name="rawNumber" type="numeric" required="true">
        <cfargument name="scale" type="numeric" required="true">

        <cfset var rounding = createObject("java", "java.math.RoundingMode")>
        <cfset var bd = createObject("java", "java.math.BigDecimal").init(javacast("double", arguments.rawNumber))>

        <cfset bd = bd.setScale(javacast("int", arguments.scale), rounding.HALF_UP).stripTrailingZeros()>
        <cfif bd.scale() LTE 0>
            <cfreturn bd.longValue() + 0>
        </cfif>

        <cfreturn bd.doubleValue() + 0>
    </cffunction>

    <cffunction name="readCellFormat" access="private" returntype="string" output="false">
        <cfargument name="cell" type="any" required="true">

        <cfset var format = "">

        <cfif isNull(arguments.cell)>
            <cfreturn "">
        </cfif>

        <cftry>
            <cfset format = arguments.cell.getCellStyle().getDataFormatString() & "">
            <cfcatch type="any">
                <cfreturn "">
            </cfcatch>
        </cftry>

        <cfif NOT len(format) OR compareNoCase(format, "General") EQ 0 OR left(format, 9) EQ "reserved-">
            <cfreturn "">
        </cfif>

        <cfreturn format>
    </cffunction>

    <!---Finds a header by its role. Contact is the column the directorate is placed beside.--->
    <cffunction name="findHeaderIndex" access="private" returntype="numeric" output="false">
        <cfargument name="headers" type="array" required="true">
        <cfargument name="kind" type="string" required="true">

        <cfset var headerIndex = 0>
        <cfset var headerName = "">

        <cfloop from="1" to="#arrayLen(arguments.headers)#" index="headerIndex">
            <cfset headerName = arguments.headers[headerIndex] & "">
            <cfif arguments.kind EQ "contact">
                <cfif compareNoCase(headerName, "Contact_Name") EQ 0
                    OR compareNoCase(headerName, "ContactName") EQ 0
                    OR compareNoCase(headerName, "Contact Name") EQ 0
                    OR findNoCase("contact", headerName) GT 0>
                    <cfreturn headerIndex>
                </cfif>
            <cfelseif findNoCase("hour", headerName) GT 0 OR findNoCase("recorded", headerName) GT 0>
                <cfreturn headerIndex>
            </cfif>
        </cfloop>

        <cfif arguments.kind EQ "contact" AND arrayLen(arguments.headers) GTE 5>
            <cfreturn 5>
        </cfif>
        <cfif arguments.kind NEQ "contact" AND arrayLen(arguments.headers) GT 0>
            <cfreturn arrayLen(arguments.headers)>
        </cfif>

        <cfreturn 0>
    </cffunction>

    <!---Saves the original columns and rows for the all-data export.--->
    <cffunction name="saveSourceGrid" access="private" returntype="void" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="sourceGrid" type="struct" required="true">

        <cfset var headerJson = "">
        <cfset var pending = []>
        <cfset var row = {}>
        <cfset var rowJson = "">
        <cfset var startAt = 1>
        <cfset var endAt = 1>
        <cfset var chunkIndex = 1>
        <cfset var chunkSize = 40>

        <cfset ensureSourceStorage()>
        <cfset headerJson = serializeJSON({
            sheetName = arguments.sourceGrid.sheetName,
            columns = arguments.sourceGrid.columns,
            formats = arguments.sourceGrid.formats,
            contactIndex = arguments.sourceGrid.contactIndex
        })>

        <cfquery datasource="PMSD_SATS">
            UPDATE dbo.ImportBatch
            SET SourceHeaders = <cfqueryparam value="#headerJson#" cfsqltype="cf_sql_varchar">
            WHERE BatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
        </cfquery>

        <cfloop array="#arguments.sourceGrid.rows#" index="row">
            <cfset rowJson = serializeJSON(row.cells)>
            <cfif len(rowJson) GT 7000>
                <cfthrow
                    type="Import.RowTooLarge"
                    message="A spreadsheet row is too large to store.">
            </cfif>
            <cfset arrayAppend(pending, {
                rowNumber = row.rowNumber,
                json = rowJson
            })>
        </cfloop>

        <cfloop from="1" to="#arrayLen(pending)#" index="startAt" step="#chunkSize#">
            <cfset endAt = min(startAt + chunkSize - 1, arrayLen(pending))>
            <cfquery datasource="PMSD_SATS">
                INSERT INTO dbo.TimekeepingSourceRow (
                    ImportBatchID,
                    RowNumber,
                    SourceData
                )
                VALUES
                <cfloop from="#startAt#" to="#endAt#" index="chunkIndex">
                    <cfif chunkIndex GT startAt>,</cfif>
                    (
                        <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">,
                        <cfqueryparam value="#pending[chunkIndex].rowNumber#" cfsqltype="cf_sql_integer">,
                        <cfqueryparam value="#pending[chunkIndex].json#" cfsqltype="cf_sql_varchar">
                    )
                </cfloop>
            </cfquery>
        </cfloop>
    </cffunction>

    <cffunction name="storedCell" access="private" returntype="struct" output="false">
        <cfargument name="cell" type="any" required="true">

        <cfset var cellType = "s">
        <cfset var cellValue = "">

        <cfif isStruct(arguments.cell)>
            <cfif structKeyExists(arguments.cell, "t")>
                <cfset cellType = arguments.cell.t>
            <cfelseif structKeyExists(arguments.cell, "T")>
                <cfset cellType = arguments.cell.T>
            </cfif>
            <cfif structKeyExists(arguments.cell, "v")>
                <cfset cellValue = arguments.cell.v>
            <cfelseif structKeyExists(arguments.cell, "V")>
                <cfset cellValue = arguments.cell.V>
            </cfif>
        <cfelseif isNumeric(arguments.cell)>
            <cfset cellType = "n">
            <cfset cellValue = arguments.cell>
        <cfelse>
            <cfset cellValue = arguments.cell & "">
        </cfif>

        <cfreturn {t = lcase(cellType & ""), v = cellValue}>
    </cffunction>

    <cffunction name="cellText" access="private" returntype="string" output="false">
        <cfargument name="cell" type="any" required="true">
        <cfreturn trim(storedCell(arguments.cell).v & "")>
    </cffunction>

    <cffunction name="cellNumber" access="private" returntype="string" output="false">
        <cfargument name="cell" type="any" required="true">

        <cfset var stored = storedCell(arguments.cell)>

        <cfif stored.t EQ "n" OR (stored.t NEQ "d" AND isNumeric(stored.v))>
            <cfreturn stored.v & "">
        </cfif>

        <cfreturn "">
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

    <!---Imports contact and hours, and keeps every original row for export.--->
    <cffunction name="importStagingRows" access="private" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="sourceGrid" type="struct" required="true">

        <cfset var stats = {recordCount = 0, skippedCount = 0}>
        <cfset var row = {}>
        <cfset var clientContact = "">
        <cfset var hoursValue = "">
        <cfset var contactIndex = arguments.sourceGrid.contactIndex>
        <cfset var hoursIndex = arguments.sourceGrid.hoursIndex>

        <cfloop array="#arguments.sourceGrid.rows#" index="row">
            <cfset clientContact = "">
            <cfset hoursValue = "">

            <cfif arrayLen(row.cells) GTE contactIndex>
                <cfset clientContact = cellText(row.cells[contactIndex])>
            </cfif>
            <cfif arrayLen(row.cells) GTE hoursIndex>
                <cfset hoursValue = cellNumber(row.cells[hoursIndex])>
            </cfif>

            <cfif NOT len(clientContact) OR NOT isNumeric(hoursValue)>
                <cfset stats.skippedCount = stats.skippedCount + 1>
                <cfcontinue>
            </cfif>

            <cfset insertStagingRow(
                batchID = arguments.batchID,
                rowNumber = row.rowNumber,
                clientContact = clientContact,
                hours = val(hoursValue)
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

    <!---Loads the branch directory once so each spreadsheet row does not query it.--->
    <cffunction name="buildDirectoryNameIndex" access="private" returntype="struct" output="false">
        <cfset var qryUsers = queryNew("")>
        <cfset var index = {}>
        <cfset var hit = {}>
        <cfset var nameKey = "">

        <cfquery name="qryUsers" datasource="#application.branchDatasource#">
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
        </cfquery>

        <cfloop query="qryUsers">
            <cfset hit = directoryHit(qryUsers)>
            <cfset nameKey = compactName(hit.lastName) & "|" & compactName(hit.firstName)>

            <cfif NOT len(trim(hit.userID)) OR nameKey EQ "|">
                <cfcontinue>
            </cfif>

            <cfif NOT structKeyExists(index, nameKey)>
                <cfset index[nameKey] = {
                    ambiguous = false,
                    user = hit
                }>
            <cfelseif compareNoCase(index[nameKey].user.userID, hit.userID) NEQ 0>
                <cfset index[nameKey].ambiguous = true>
            </cfif>
        </cfloop>

        <cfreturn index>
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
        <cfargument name="nameIndex" type="struct" required="false">

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
        <cfset var activeIndex = {}>
        <cfset var nameKey = "">
        <cfset var indexedName = {}>

        <cfif arrayLen(parsedNames) EQ 0>
            <cfreturn client>
        </cfif>

        <cfset client.firstName = parsedNames[1].firstName>
        <cfset client.lastName = parsedNames[1].lastName>

        <cfif structKeyExists(arguments, "nameIndex")>
            <cfset activeIndex = arguments.nameIndex>
        <cfelse>
            <cfset activeIndex = buildDirectoryNameIndex()>
        </cfif>

        <cfset nameKey = compactName(parsedNames[1].lastName) & "|" & compactName(parsedNames[1].firstName)>

        <cfif structKeyExists(activeIndex, nameKey)>
            <cfset indexedName = activeIndex[nameKey]>

            <cfif indexedName.ambiguous>
                <cfset client.errorMessage = "More than one employee matches #parsedNames[1].lastName#, #parsedNames[1].firstName#">
                <cfreturn client>
            </cfif>

            <cfset applyDirectoryUser(client, indexedName.user)>
            <cfreturn client>
        </cfif>

        <cfset client.errorMessage = "No matching user found for name: #parsedNames[1].lastName#, #parsedNames[1].firstName#">
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
        <cfset var nameIndex = buildDirectoryNameIndex()>

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
                    clientContact = stagingRows.ClientContact[stagingRows.currentRow],
                    nameIndex = nameIndex
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

            <cfset ensureSourceStorage()>

            <cfquery name="existingBatch" datasource="PMSD_SATS">
                SELECT BatchID, SourceFile
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
                    DELETE FROM dbo.TimekeepingSourceRow
                    WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
                </cfquery>

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
            <cfif len(trim(existingBatch.SourceFile & "")) AND fileExists(existingBatch.SourceFile)>
                <cftry>
                    <cffile action="delete" file="#existingBatch.SourceFile#">
                    <cfcatch type="any">
                    </cfcatch>
                </cftry>
            </cfif>

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

    <!---Copies the uploaded workbook and inserts Directorate beside Contact Name.--->
    <cffunction name="writePatchedWorkbook" access="private" returntype="numeric" output="false">
        <cfargument name="sourcePath" type="string" required="true">
        <cfargument name="destPath" type="string" required="true">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="nameIndex" type="struct" required="true">

        <cfset var tempDir = getTempDirectory() & "tt-" & createUUID()>
        <cfset var workbookXml = "">
        <cfset var relsXml = "">
        <cfset var sharedXml = "">
        <cfset var sheetXml = "">
        <cfset var sheetInfo = {}>
        <cfset var strings = []>
        <cfset var patched = {}>
        <cfset var sheetFile = "">
        <cfset var rowCount = 0>

        <cftry>
            <cfdirectory action="create" directory="#tempDir#">
            <cfzip action="unzip" file="#arguments.sourcePath#" destination="#tempDir#" overwrite="yes">

            <cffile action="read" file="#tempDir#/xl/workbook.xml" variable="workbookXml" charset="utf-8">
            <cffile action="read" file="#tempDir#/xl/_rels/workbook.xml.rels" variable="relsXml" charset="utf-8">

            <cfset sheetInfo = findDataSheet(workbookXml, relsXml, tempDir)>
            <cffile action="read" file="#tempDir#/#sheetInfo.sharedStrings#" variable="sharedXml" charset="utf-8">
            <cfset strings = loadSharedStrings(sharedXml)>
            <cfset sheetFile = tempDir & "/" & sheetInfo.sheetPath>
            <cffile action="read" file="#sheetFile#" variable="sheetXml" charset="utf-8">
            <cfset patched = addDirectorateColumn(sheetXml, strings, arguments.batchID, arguments.nameIndex)>
            <cfset rowCount = patched.rowCount>
            <cfset writeUtf8File(sheetFile, patched.xml)>

            <cfif fileExists(arguments.destPath)>
                <cffile action="delete" file="#arguments.destPath#">
            </cfif>
            <cfzip action="zip" source="#tempDir#" file="#arguments.destPath#" overwrite="yes">

            <cfcatch type="any">
                <cfif fileExists(arguments.destPath)>
                    <cftry>
                        <cffile action="delete" file="#arguments.destPath#">
                        <cfcatch type="any">
                        </cfcatch>
                    </cftry>
                </cfif>
                <cfrethrow>
            </cfcatch>
            <cffinally>
                <cfif directoryExists(tempDir)>
                    <cftry>
                        <cfdirectory action="delete" directory="#tempDir#" recurse="yes">
                        <cfcatch type="any">
                        </cfcatch>
                    </cftry>
                </cfif>
            </cffinally>
        </cftry>

        <cfreturn rowCount>
    </cffunction>

    <cffunction name="writeUtf8File" access="private" returntype="void" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfargument name="contents" type="string" required="true">

        <cfscript>
            var output = createObject("java", "java.io.FileOutputStream").init(arguments.filePath);
            var writer = createObject("java", "java.io.OutputStreamWriter").init(output, "UTF-8");

            try {
                writer.write(arguments.contents);
            } finally {
                try {
                    writer.close();
                } catch (any ignoreWriter) {
                }
                try {
                    output.close();
                } catch (any ignoreOutput) {
                }
            }
        </cfscript>
    </cffunction>

    <cffunction name="writePatchedZip" access="private" returntype="string" output="false">
        <cfargument name="files" type="array" required="true">
        <cfargument name="xlsxPath" type="string" required="true">
        <cfargument name="nameIndex" type="struct" required="true">

        <cfscript>
            var zipPath = reReplaceNoCase(arguments.xlsxPath, "\.xlsx$", ".zip");
            var output = createObject("java", "java.io.FileOutputStream").init(zipPath);
            var zipOut = createObject("java", "java.util.zip.ZipOutputStream").init(output);
            var index = 0;
            var tempPath = "";
            var entryName = "";
            var bytes = "";
            var used = {};

            try {
                for (index = 1; index <= arrayLen(arguments.files); index++) {
                    tempPath = getTempDirectory() & "timetracker-batch-" & arguments.files[index].batchID & ".xlsx";
                    writePatchedWorkbook(
                        arguments.files[index].sourceFile,
                        tempPath,
                        arguments.files[index].batchID,
                        arguments.nameIndex
                    );
                    entryName = len(trim(arguments.files[index].fileName & "")) ? arguments.files[index].fileName : ("batch-" & arguments.files[index].batchID & ".xlsx");
                    if (structKeyExists(used, lCase(entryName))) {
                        entryName = arguments.files[index].batchID & "-" & entryName;
                    }
                    used[lCase(entryName)] = true;
                    bytes = createObject("java", "java.nio.file.Files").readAllBytes(
                        createObject("java", "java.nio.file.Paths").get(tempPath)
                    );
                    zipOut.putNextEntry(createObject("java", "java.util.zip.ZipEntry").init(entryName));
                    zipOut.write(bytes, 0, bytes.length);
                    zipOut.closeEntry();
                    try {
                        fileDelete(tempPath);
                    } catch (any ignoreTemp) {
                    }
                }
            } finally {
                try {
                    zipOut.close();
                } catch (any ignoreZip) {
                }
                try {
                    output.close();
                } catch (any ignoreOutput) {
                }
            }

            return getFileFromPath(zipPath);
        </cfscript>
    </cffunction>

    <cffunction name="findDataSheet" access="private" returntype="struct" output="false">
        <cfargument name="workbookXml" type="string" required="true">
        <cfargument name="relsXml" type="string" required="true">
        <cfargument name="baseDirectory" type="string" required="true">

        <cfscript>
            var relationships = relationshipTargets(arguments.relsXml);
            var sheetPattern = createObject("java", "java.util.regex.Pattern").compile("(?i)" & chr(60) & "sheet\b[^" & chr(62) & "]*" & chr(62));
            var matcher = sheetPattern.matcher(arguments.workbookXml);
            var sheets = [];
            var tag = "";
            var sheet = {};
            var index = 0;
            var sharedStrings = "xl/sharedStrings.xml";

            if (structKeyExists(relationships, "sharedstrings")) {
                sharedStrings = relationships.sharedstrings;
            }

            while (matcher.find()) {
                tag = matcher.group();
                sheet = {
                    name = attrValue(tag, "name"),
                    target = ""
                };
                sheet.target = relationshipTarget(relationships, attrValue(tag, "r:id"));
                if (len(sheet.target)) {
                    arrayAppend(sheets, sheet);
                }
            }

            for (index = 1; index <= arrayLen(sheets); index++) {
                if (compareNoCase(sheets[index].name, "data") == 0) {
                    return {sheetPath = sheets[index].target, sharedStrings = sharedStrings};
                }
            }

            for (index = 1; index <= arrayLen(sheets); index++) {
                if (sheetHasContactHeader(arguments.baseDirectory, sheets[index].target, sharedStrings)) {
                    return {sheetPath = sheets[index].target, sharedStrings = sharedStrings};
                }
            }

            if (arrayLen(sheets)) {
                return {sheetPath = sheets[1].target, sharedStrings = sharedStrings};
            }
        </cfscript>

        <cfthrow
            type="Export.DataSheetMissing"
            message="The uploaded workbook does not contain a worksheet.">
    </cffunction>

    <cffunction name="sheetHasContactHeader" access="private" returntype="boolean" output="false">
        <cfargument name="baseDirectory" type="string" required="true">
        <cfargument name="sheetPath" type="string" required="true">
        <cfargument name="sharedStrings" type="string" required="true">

        <cfset var sharedXml = "">
        <cfset var sheetXml = "">
        <cfset var strings = []>
        <cfset var info = {}>

        <cffile action="read" file="#arguments.baseDirectory#/#arguments.sharedStrings#" variable="sharedXml" charset="utf-8">
        <cffile action="read" file="#arguments.baseDirectory#/#arguments.sheetPath#" variable="sheetXml" charset="utf-8">
        <cfset strings = loadSharedStrings(sharedXml)>
        <cfset info = findContactHeader(sheetXml, strings)>
        <cfreturn len(info.letter) GT 0>
    </cffunction>

    <cffunction name="addDirectorateColumn" access="private" returntype="struct" output="false">
        <cfargument name="sheetXml" type="string" required="true">
        <cfargument name="strings" type="array" required="true">
        <cfargument name="batchID" type="numeric" required="true">
        <cfargument name="nameIndex" type="struct" required="true">

        <cfscript>
            var header = findContactHeader(arguments.sheetXml, arguments.strings);
            var insertAt = 0;
            var newLetter = "";
            var shifted = "";
            var matches = {};
            var rowPattern = createObject("java", "java.util.regex.Pattern").compile("(?s)" & chr(60) & "row\b[^" & chr(62) & "]*" & chr(62) & ".*?" & chr(60) & "/row" & chr(62));
            var matcher = "";
            var buffer = createObject("java", "java.lang.StringBuffer").init();
            var rowXml = "";
            var rowNumber = 0;
            var contact = "";
            var directorate = "";
            var rowCount = 0;

            if (NOT len(header.letter)) {
                throw(type = "Export.ContactColumnMissing", message = "The contact column was not found.");
            }

            insertAt = header.columnNumber + 1;
            newLetter = columnLetters(insertAt);
            shifted = shiftSheetXml(arguments.sheetXml, insertAt);
            matches = loadDirectorateMatches(arguments.batchID);
            matcher = rowPattern.matcher(shifted);

            while (matcher.find()) {
                rowXml = matcher.group();
                rowNumber = val(attrValue(rowXml, "r"));
                if (rowNumber EQ header.rowNumber) {
                    rowXml = insertCellAfter(rowXml, header.letter, rowNumber, directorateCell(newLetter, rowNumber, "Directorate"));
                } else if (rowNumber GT 0) {
                    contact = contactText(rowXml, header.letter, rowNumber, arguments.strings);
                    rowCount++;
                    if (len(contact)) {
                        directorate = directorateTextForContact(contact, matches, arguments.nameIndex);
                        if (len(directorate)) {
                            rowXml = insertCellAfter(rowXml, header.letter, rowNumber, directorateCell(newLetter, rowNumber, directorate));
                        }
                    }
                }
                matcher.appendReplacement(buffer, matcher.quoteReplacement(rowXml));
            }
            matcher.appendTail(buffer);

            return {xml = buffer.toString(), rowCount = rowCount};
        </cfscript>
    </cffunction>

    <cffunction name="findContactHeader" access="private" returntype="struct" output="false">
        <cfargument name="sheetXml" type="string" required="true">
        <cfargument name="strings" type="array" required="true">

        <cfscript>
            var rowPattern = createObject("java", "java.util.regex.Pattern").compile("(?s)" & chr(60) & "row\b[^" & chr(62) & "]*" & chr(62) & ".*?" & chr(60) & "/row" & chr(62));
            var matcher = rowPattern.matcher(arguments.sheetXml);
            var rowXml = "";
            var cells = [];
            var index = 0;
            var text = "";
            var empty = {letter = "", columnNumber = 0, rowNumber = 0};

            if (NOT matcher.find()) {
                return empty;
            }

            rowXml = matcher.group();
            cells = parseRowCells(rowXml, arguments.strings);
            for (index = 1; index <= arrayLen(cells); index++) {
                text = cells[index].text;
                if (compareNoCase(text, "Contact Name") EQ 0
                    OR compareNoCase(text, "Contact_Name") EQ 0
                    OR compareNoCase(text, "ContactName") EQ 0
                    OR (len(text) LTE 40 AND findNoCase("contact", text) AND NOT find("[", text))) {
                    return cells[index];
                }
            }

            return empty;
        </cfscript>
    </cffunction>

    <cffunction name="parseRowCells" access="private" returntype="array" output="false">
        <cfargument name="rowXml" type="string" required="true">
        <cfargument name="strings" type="array" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile("(?s)" & chr(60) & "c\b([^" & chr(62) & "]*?)(?:/" & chr(62) & "|" & chr(62) & "(.*?)" & chr(60) & "/c" & chr(62) & ")");
            var matcher = pattern.matcher(arguments.rowXml);
            var cells = [];
            var attributes = "";
            var reference = "";
            var letters = "";
            var inner = "";

            while (matcher.find()) {
                attributes = matcher.group(javacast("int", 1));
                inner = matcher.group(javacast("int", 2));
                if (isNull(inner)) {
                    inner = "";
                }
                reference = attrValue(attributes, "r");
                letters = reReplace(reference, "[^A-Za-z]", "", "all");
                arrayAppend(cells, {
                    letter = uCase(letters),
                    columnNumber = columnNumber(letters),
                    rowNumber = val(reReplace(reference, "[^0-9]", "", "all")),
                    text = cellDisplayText(attributes, inner & "", arguments.strings)
                });
            }

            return cells;
        </cfscript>
    </cffunction>

    <cffunction name="contactText" access="private" returntype="string" output="false">
        <cfargument name="rowXml" type="string" required="true">
        <cfargument name="letter" type="string" required="true">
        <cfargument name="rowNumber" type="numeric" required="true">
        <cfargument name="strings" type="array" required="true">

        <cfscript>
            var cells = parseRowCells(arguments.rowXml, arguments.strings);
            var index = 0;

            for (index = 1; index <= arrayLen(cells); index++) {
                if (compareNoCase(cells[index].letter, arguments.letter) EQ 0 AND cells[index].rowNumber EQ arguments.rowNumber) {
                    return cells[index].text;
                }
            }

            return "";
        </cfscript>
    </cffunction>

    <cffunction name="cellDisplayText" access="private" returntype="string" output="false">
        <cfargument name="attributes" type="string" required="true">
        <cfargument name="inner" type="any" required="false">
        <cfargument name="strings" type="array" required="true">

        <cfscript>
            var body = isNull(arguments.inner) ? "" : (arguments.inner & "");
            var pattern = "";
            var matcher = "";
            var index = 0;

            if (findNoCase('t="s"', arguments.attributes)) {
                pattern = createObject("java", "java.util.regex.Pattern").compile(chr(60) & "v" & chr(62) & "(\d+)" & chr(60) & "/v" & chr(62));
                matcher = pattern.matcher(body);
                if (matcher.find()) {
                    index = val(matcher.group(javacast("int", 1)));
                    if (index + 1 GTE 1 AND index + 1 LTE arrayLen(arguments.strings)) {
                        return arguments.strings[index + 1];
                    }
                }
                return "";
            }

            if (findNoCase("inlineStr", arguments.attributes) OR findNoCase('t="str"', arguments.attributes)) {
                return decodeXml(joinedTextNodes(body));
            }

            pattern = createObject("java", "java.util.regex.Pattern").compile(chr(60) & "v" & chr(62) & "([^" & chr(60) & "]*)" & chr(60) & "/v" & chr(62));
            matcher = pattern.matcher(body);
            if (matcher.find()) {
                return decodeXml(matcher.group(javacast("int", 1)));
            }

            return "";
        </cfscript>
    </cffunction>

    <cffunction name="loadSharedStrings" access="private" returntype="array" output="false">
        <cfargument name="xml" type="string" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile("(?s)" & chr(60) & "si\b[^" & chr(62) & "]*" & chr(62) & "(.*?)" & chr(60) & "/si" & chr(62));
            var matcher = pattern.matcher(arguments.xml);
            var strings = [];

            while (matcher.find()) {
                arrayAppend(strings, decodeXml(joinedTextNodes(matcher.group(javacast("int", 1)))));
            }

            return strings;
        </cfscript>
    </cffunction>

    <cffunction name="joinedTextNodes" access="private" returntype="string" output="false">
        <cfargument name="xml" type="string" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile("(?s)" & chr(60) & "t\b[^" & chr(62) & "]*" & chr(62) & "(.*?)" & chr(60) & "/t" & chr(62));
            var matcher = pattern.matcher(arguments.xml);
            var text = "";

            while (matcher.find()) {
                text &= matcher.group(javacast("int", 1));
            }

            return text;
        </cfscript>
    </cffunction>

    <cffunction name="shiftSheetXml" access="private" returntype="string" output="false">
        <cfargument name="sheetXml" type="string" required="true">
        <cfargument name="insertAt" type="numeric" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile('(?i)\b(r|ref|activeCell|sqref)="([^"]*)"');
            var matcher = pattern.matcher(arguments.sheetXml);
            var buffer = createObject("java", "java.lang.StringBuffer").init();
            var spans = createObject("java", "java.util.regex.Pattern").compile('spans="(\d+):(\d+)"');
            var spanMatcher = "";
            var spanBuffer = createObject("java", "java.lang.StringBuffer").init();
            var endColumn = 0;

            while (matcher.find()) {
                matcher.appendReplacement(
                    buffer,
                    matcher.quoteReplacement(
                        matcher.group(javacast("int", 1)) & '="' & shiftReferenceList(matcher.group(javacast("int", 2)), arguments.insertAt) & '"'
                    )
                );
            }
            matcher.appendTail(buffer);

            spanMatcher = spans.matcher(buffer.toString());
            while (spanMatcher.find()) {
                endColumn = val(spanMatcher.group(javacast("int", 2)));
                if (endColumn GTE arguments.insertAt) {
                    endColumn++;
                }
                spanMatcher.appendReplacement(
                    spanBuffer,
                    spanMatcher.quoteReplacement('spans="' & spanMatcher.group(javacast("int", 1)) & ":" & endColumn & '"')
                );
            }
            spanMatcher.appendTail(spanBuffer);
            return spanBuffer.toString();
        </cfscript>
    </cffunction>

    <cffunction name="shiftReferenceList" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="true">
        <cfargument name="insertAt" type="numeric" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile("[A-Z]{1,3}\d+");
            var matcher = pattern.matcher(uCase(arguments.value));
            var buffer = createObject("java", "java.lang.StringBuffer").init();
            var token = "";
            var letters = "";
            var rowNumber = "";
            var column = 0;

            while (matcher.find()) {
                token = matcher.group();
                letters = reReplace(token, "[^A-Z]", "", "all");
                rowNumber = reReplace(token, "[^0-9]", "", "all");
                column = columnNumber(letters);
                if (column GTE arguments.insertAt) {
                    token = columnLetters(column + 1) & rowNumber;
                }
                matcher.appendReplacement(buffer, matcher.quoteReplacement(token));
            }
            matcher.appendTail(buffer);
            return buffer.toString();
        </cfscript>
    </cffunction>

    <cffunction name="insertCellAfter" access="private" returntype="string" output="false">
        <cfargument name="rowXml" type="string" required="true">
        <cfargument name="letter" type="string" required="true">
        <cfargument name="rowNumber" type="numeric" required="true">
        <cfargument name="cellXml" type="string" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile("(?s)" & chr(60) & "c\b[^" & chr(62) & "]*\br=""" & arguments.letter & arguments.rowNumber & """[^" & chr(62) & "]*(?:/" & chr(62) & "|" & chr(62) & ".*?" & chr(60) & "/c" & chr(62) & ")");
            var matcher = pattern.matcher(arguments.rowXml);
            var buffer = createObject("java", "java.lang.StringBuffer").init();

            if (NOT matcher.find()) {
                return arguments.rowXml;
            }

            matcher.appendReplacement(buffer, matcher.quoteReplacement(matcher.group() & arguments.cellXml));
            matcher.appendTail(buffer);
            return buffer.toString();
        </cfscript>
    </cffunction>

    <cffunction name="directorateCell" access="private" returntype="string" output="false">
        <cfargument name="letter" type="string" required="true">
        <cfargument name="rowNumber" type="numeric" required="true">
        <cfargument name="text" type="string" required="true">

        <cfscript>
            var escaped = xmlEscape(arguments.text);
            var space = find(xmlNewline(), escaped) ? ' xml:space="preserve"' : "";
            return chr(60) & "c r=""" & arguments.letter & arguments.rowNumber & """ t=""inlineStr""" & chr(62) & chr(60) & "is" & chr(62) & chr(60) & "t" & space & chr(62) & escaped & chr(60) & "/t" & chr(62) & chr(60) & "/is" & chr(62) & chr(60) & "/c" & chr(62);
        </cfscript>
    </cffunction>

    <cffunction name="columnNumber" access="private" returntype="numeric" output="false">
        <cfargument name="letters" type="string" required="true">

        <cfscript>
            var value = uCase(arguments.letters);
            var number = 0;
            var index = 0;

            for (index = 1; index <= len(value); index++) {
                number = number * 26 + asc(mid(value, index, 1)) - 64;
            }

            return number;
        </cfscript>
    </cffunction>

    <cffunction name="columnLetters" access="private" returntype="string" output="false">
        <cfargument name="number" type="numeric" required="true">

        <cfscript>
            var value = arguments.number;
            var letters = "";
            var remainder = 0;

            while (value GT 0) {
                remainder = (value - 1) mod 26;
                letters = chr(65 + remainder) & letters;
                value = int((value - 1) / 26);
            }

            return letters;
        </cfscript>
    </cffunction>

    <cffunction name="xmlNewline" access="private" returntype="string" output="false">
        <cfreturn "&" & chr(35) & "10;">
    </cffunction>

    <cffunction name="xmlCarriageReturn" access="private" returntype="string" output="false">
        <cfreturn "&" & chr(35) & "13;">
    </cffunction>

    <cffunction name="xmlEscape" access="private" returntype="string" output="false">
        <cfargument name="text" type="string" required="true">

        <cfscript>
            var value = replace(arguments.text, "&", "&amp;", "all");
            value = replace(value, chr(60), "&lt;", "all");
            value = replace(value, chr(62), "&gt;", "all");
            value = reReplace(value, "\r\n|\r|\n", xmlNewline(), "all");
            return value;
        </cfscript>
    </cffunction>

    <cffunction name="decodeXml" access="private" returntype="string" output="false">
        <cfargument name="text" type="string" required="true">

        <cfscript>
            var value = reReplace(arguments.text, xmlNewline() & "|" & xmlCarriageReturn(), chr(10), "all");
            value = replace(value, "&lt;", chr(60), "all");
            value = replace(value, "&gt;", chr(62), "all");
            value = replace(value, "&quot;", '"', "all");
            value = replace(value, "&apos;", "'", "all");
            value = replace(value, "&amp;", "&", "all");
            return value;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeContactKey" access="private" returntype="string" output="false">
        <cfargument name="contact" type="string" required="true">
        <cfreturn lcase(trim(reReplace(arguments.contact, "\r\n|\r", chr(10), "all")))>
    </cffunction>

    <cffunction name="loadDirectorateMatches" access="private" returntype="struct" output="false">
        <cfargument name="batchID" type="numeric" required="true">

        <cfset var matches = {}>
        <cfset var qryMatches = queryNew("")>
        <cfset var matchKey = "">

        <cfquery name="qryMatches" datasource="PMSD_SATS">
            SELECT
                ClientContact,
                DirectorateNameE,
                ClientFirstName,
                ClientLastName
            FROM dbo.TimekeepingEnriched
            WHERE ImportBatchID = <cfqueryparam value="#arguments.batchID#" cfsqltype="cf_sql_integer">
            AND NULLIF(LTRIM(RTRIM(DirectorateNameE)), '') IS NOT NULL
        </cfquery>

        <cfloop query="qryMatches">
            <cfset matchKey = normalizeContactKey(qryMatches.ClientContact & "")>
            <cfif len(matchKey) AND NOT structKeyExists(matches, matchKey)>
                <cfset matches[matchKey] = {
                    directorate = trim(qryMatches.DirectorateNameE & ""),
                    firstName = qryMatches.ClientFirstName & "",
                    lastName = qryMatches.ClientLastName & ""
                }>
            </cfif>
        </cfloop>

        <cfreturn matches>
    </cffunction>

    <cffunction name="attrValue" access="private" returntype="string" output="false">
        <cfargument name="tag" type="string" required="true">
        <cfargument name="attributeName" type="string" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile('(?i)\b' & arguments.attributeName & '="([^"]*)"');
            var matcher = pattern.matcher(arguments.tag);

            if (matcher.find()) {
                return matcher.group(javacast("int", 1));
            }

            return "";
        </cfscript>
    </cffunction>

    <cffunction name="relationshipTargets" access="private" returntype="struct" output="false">
        <cfargument name="relsXml" type="string" required="true">

        <cfscript>
            var pattern = createObject("java", "java.util.regex.Pattern").compile("(?i)" & chr(60) & "Relationship\b[^" & chr(62) & "]*" & chr(62));
            var matcher = pattern.matcher(arguments.relsXml);
            var targets = {};
            var tag = "";
            var id = "";
            var target = "";
            var typeName = "";

            while (matcher.find()) {
                tag = matcher.group();
                id = attrValue(tag, "Id");
                target = normalizePackagePath(attrValue(tag, "Target"));
                typeName = attrValue(tag, "Type");
                if (len(id)) {
                    targets[id] = target;
                }
                if (findNoCase("/sharedStrings", typeName)) {
                    targets.sharedstrings = target;
                }
            }

            return targets;
        </cfscript>
    </cffunction>

    <cffunction name="relationshipTarget" access="private" returntype="string" output="false">
        <cfargument name="relationships" type="struct" required="true">
        <cfargument name="id" type="string" required="true">

        <cfif structKeyExists(arguments.relationships, arguments.id)>
            <cfreturn arguments.relationships[arguments.id]>
        </cfif>

        <cfreturn "">
    </cffunction>

    <cffunction name="normalizePackagePath" access="private" returntype="string" output="false">
        <cfargument name="target" type="string" required="true">

        <cfset var path = replace(arguments.target, "\", "/", "all")>

        <cfif left(path, 1) EQ "/">
            <cfset path = mid(path, 2, len(path))>
        </cfif>
        <cfif left(path, 3) EQ "../">
            <cfset path = mid(path, 4, len(path))>
        </cfif>
        <cfif len(path) AND left(path, 3) NEQ "xl/">
            <cfset path = "xl/" & path>
        </cfif>

        <cfreturn path>
    </cffunction>

    <cffunction name="readZipText" access="private" returntype="string" output="false">
        <cfargument name="sourceZip" type="any" required="true">
        <cfargument name="entryName" type="string" required="true">

        <cfscript>
            var bytes = readZipBytes(arguments.sourceZip, arguments.entryName);

            if (isSimpleValue(bytes)) {
                return "";
            }

            return createObject("java", "java.lang.String").init(bytes, "UTF-8");
        </cfscript>
    </cffunction>

    <cffunction name="readZipBytes" access="private" returntype="any" output="false">
        <cfargument name="sourceZip" type="any" required="true">
        <cfargument name="entryName" type="string" required="true">

        <cfscript>
            var entry = arguments.sourceZip.getEntry(arguments.entryName);
            var input = "";
            var output = createObject("java", "java.io.ByteArrayOutputStream").init();
            var buffer = createObject("java", "java.lang.reflect.Array").newInstance(createObject("java", "java.lang.Byte").TYPE, 16384);
            var read = 0;

            if (isNull(entry)) {
                return "";
            }

            input = createObject("java", "java.io.BufferedInputStream").init(arguments.sourceZip.getInputStream(entry));
            read = input.read(buffer);
            while (read GT 0) {
                output.write(buffer, 0, read);
                read = input.read(buffer);
            }
            input.close();
            return output.toByteArray();
        </cfscript>
    </cffunction>

    <cffunction name="writeZipReplacing" access="private" returntype="void" output="false">
        <cfargument name="sourceZip" type="any" required="true">
        <cfargument name="destPath" type="string" required="true">
        <cfargument name="replaceName" type="string" required="true">
        <cfargument name="xml" type="string" required="true">

        <cfscript>
            var output = createObject("java", "java.io.FileOutputStream").init(arguments.destPath);
            var zipOut = createObject("java", "java.util.zip.ZipOutputStream").init(output);
            var entries = arguments.sourceZip.entries();
            var entry = "";
            var name = "";
            var bytes = "";
            var replaced = false;

            try {
                while (entries.hasMoreElements()) {
                    entry = entries.nextElement();
                    if (entry.isDirectory()) {
                        continue;
                    }
                    name = entry.getName();
                    zipOut.putNextEntry(createObject("java", "java.util.zip.ZipEntry").init(name));
                    if (compare(replace(name, chr(92), "/", "all"), arguments.replaceName) EQ 0) {
                        bytes = createObject("java", "java.lang.String").init(arguments.xml).getBytes("UTF-8");
                        replaced = true;
                    } else {
                        bytes = readZipBytes(arguments.sourceZip, name);
                    }
                    if (NOT isSimpleValue(bytes)) {
                        zipOut.write(bytes, 0, bytes.length);
                    }
                    zipOut.closeEntry();
                }
                if (NOT replaced) {
                    throw(type = "Export.SheetMissing", message = "The data sheet was not found in the uploaded workbook.");
                }
            } finally {
                try {
                    zipOut.close();
                } catch (any ignoreZip) {
                }
                try {
                    output.close();
                } catch (any ignoreOutput) {
                }
            }
        </cfscript>
    </cffunction>

    <!---Writes the uploaded spreadsheet with Directorate beside Contact Name.--->
    <cffunction name="writeAllDataExport" access="public" returntype="struct" output="false">
        <cfargument name="batchFilter" type="numeric" required="true">
        <cfargument name="filePath" type="string" required="true">

        <cfsetting requesttimeout="600">

        <cfset var result = {recordCount = 0, note = "", fileName = getFileFromPath(arguments.filePath)}>
        <cfset var readyFiles = []>
        <cfset var readyFile = {}>
        <cfset var sourceBatches = queryNew("")>
        <cfset var legacyCount = queryNew("")>
        <cfset var workbook = "">
        <cfset var poiBook = "">
        <cfset var poiSheet = "">
        <cfset var spec = {}>
        <cfset var qrySourceRows = queryNew("")>
        <cfset var qryMatches = queryNew("")>
        <cfset var storedMatches = {}>
        <cfset var matchKey = "">
        <cfset var nameIndex = {}>
        <cfset var usedNames = {}>
        <cfset var sheetLabel = "">
        <cfset var sheetNumber = 0>
        <cfset var dataFormat = "">
        <cfset var styleCache = {}>
        <cfset var headerFont = "">
        <cfset var headerStyle = "">

        <cfset ensureSourceStorage()>

        <cfquery name="sourceBatches" datasource="PMSD_SATS">
            SELECT BatchID, FileName, SourceFile
            FROM dbo.ImportBatch
            WHERE SourceFile IS NOT NULL
            AND LTRIM(RTRIM(SourceFile)) <> ''
            <cfif arguments.batchFilter GT 0>
                AND BatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
            ORDER BY ImportDate, BatchID
        </cfquery>

        <cfloop query="sourceBatches">
            <cfif fileExists(sourceBatches.SourceFile) AND compareNoCase(listLast(sourceBatches.SourceFile, "."), "xlsx") EQ 0>
                <cfset arrayAppend(readyFiles, {
                    batchID = sourceBatches.BatchID,
                    fileName = sourceBatches.FileName,
                    sourceFile = sourceBatches.SourceFile
                })>
            </cfif>
        </cfloop>

        <cfif NOT arrayLen(readyFiles)>
            <cfset result.recordCount = writeLegacyExport(arguments.batchFilter, arguments.filePath)>
            <cfif result.recordCount GT 0>
                <cfset result.note = "This download is not the original workbook. That file was not kept for this import. Upload it again, then export, to get the same workbook with Directorate inserted beside Contact Name.">
            </cfif>
            <cfreturn result>
        </cfif>

        <cfset nameIndex = buildDirectoryNameIndex()>

        <cfif arrayLen(readyFiles) EQ 1>
            <cfset result.recordCount = writePatchedWorkbook(
                sourcePath = readyFiles[1].sourceFile,
                destPath = arguments.filePath,
                batchID = readyFiles[1].batchID,
                nameIndex = nameIndex
            )>
        <cfelse>
            <cfset result.fileName = writePatchedZip(readyFiles, arguments.filePath, nameIndex)>
            <cfset result.recordCount = arrayLen(readyFiles)>
        </cfif>

        <cfquery name="legacyCount" datasource="PMSD_SATS">
            SELECT COUNT(*) AS LegacyCount
            FROM dbo.ImportBatch
            WHERE (SourceFile IS NULL OR LTRIM(RTRIM(SourceFile)) = '')
            AND ProcessingStatus = 'Completed'
            AND (
                EXISTS (
                    SELECT 1
                    FROM dbo.TimekeepingEnriched AS enriched
                    WHERE enriched.ImportBatchID = dbo.ImportBatch.BatchID
                )
                OR EXISTS (
                    SELECT 1
                    FROM dbo.UnmatchedClients AS unmatched
                    WHERE unmatched.ImportBatchID = dbo.ImportBatch.BatchID
                    AND unmatched.Active = 1
                )
            )
            <cfif arguments.batchFilter GT 0>
                AND BatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>
        </cfquery>

        <cfif legacyCount.LegacyCount GT 0>
            <cfset result.note = "Older imports were not included because the original workbook was not kept. Upload those spreadsheets again to export the same file with Directorate beside Contact Name.">
        </cfif>

        <cfreturn result>
    </cffunction>

    <cffunction name="writeLegacyExport" access="private" returntype="numeric" output="false">
        <cfargument name="batchFilter" type="numeric" required="true">
        <cfargument name="filePath" type="string" required="true">

        <cfset var legacyQuery = allExport(arguments.batchFilter)>
        <cfset var columns = [
            "ClientFirstName",
            "ClientLastName",
            "ClientEmail",
            "ClientUserID",
            "ClientContact",
            "RecordedHours",
            "DirectorateNameE",
            "DirectorateAcronymE",
            "DivisionNameE",
            "DivisionAcronymE",
            "BranchNameE",
            "BranchAcronymE",
            "SectionNameE",
            "SectionAcronymE",
            "PositionLevel",
            "IsManager",
            "MatchStatus",
            "ErrorMessage"
        ]>
        <cfset var workbook = "">
        <cfset var poiBook = "">
        <cfset var poiSheet = "">
        <cfset var dataFormat = "">
        <cfset var styleCache = {}>
        <cfset var headerStyle = "">
        <cfset var headerFont = "">
        <cfset var headerRow = "">
        <cfset var headerCell = "">
        <cfset var poiRow = "">
        <cfset var columnIndex = 0>
        <cfset var columnName = "">
        <cfset var value = "">
        <cfset var cell = {}>
        <cfset var rowIndex = 0>

        <cfif legacyQuery.recordCount EQ 0>
            <cfreturn 0>
        </cfif>

        <cfset workbook = spreadsheetNew("Data", true)>
        <cfset poiBook = poiWorkbook(workbook)>
        <cfset poiSheet = poiBook.getSheetAt(javacast("int", 0))>
        <cfset dataFormat = poiBook.createDataFormat()>
        <cfset headerFont = poiBook.createFont()>
        <cftry>
            <cfset headerFont.setBold(true)>
            <cfcatch type="any">
            </cfcatch>
        </cftry>
        <cfset headerStyle = poiBook.createCellStyle()>
        <cfset headerStyle.setFont(headerFont)>
        <cfset headerRow = poiSheet.createRow(javacast("int", 0))>

        <cfloop from="1" to="#arrayLen(columns)#" index="columnIndex">
            <cfset headerCell = headerRow.createCell(javacast("int", columnIndex - 1))>
            <cfset headerCell.setCellValue(javacast("string", columns[columnIndex]))>
            <cfset headerCell.setCellStyle(headerStyle)>
        </cfloop>

        <cfloop from="1" to="#legacyQuery.recordCount#" index="rowIndex">
            <cfset poiRow = poiSheet.createRow(javacast("int", rowIndex))>
            <cfloop from="1" to="#arrayLen(columns)#" index="columnIndex">
                <cfset columnName = columns[columnIndex]>
                <cfset value = legacyQuery[columnName][rowIndex]>
                <cfif isNull(value)>
                    <cfset value = "">
                </cfif>
                <cfif columnName EQ "RecordedHours" AND isNumeric(value)>
                    <cfset cell = {t = "n", v = val(value)}>
                <cfelse>
                    <cfset cell = {t = "s", v = value & ""}>
                </cfif>
                <cfset writeExcelValue(
                    poiRow = poiRow,
                    poiColumn = columnIndex - 1,
                    cell = cell,
                    format = "General",
                    wrap = false,
                    poiBook = poiBook,
                    dataFormat = dataFormat,
                    styleCache = styleCache
                )>
            </cfloop>
        </cfloop>

        <cfset saveWorkbook(poiBook, arguments.filePath)>
        <cfreturn legacyQuery.recordCount>
    </cffunction>

    <cffunction name="writeBatchSheet" access="private" returntype="numeric" output="false">
        <cfargument name="poiSheet" type="any" required="true">
        <cfargument name="poiBook" type="any" required="true">
        <cfargument name="spec" type="struct" required="true">
        <cfargument name="sourceRows" type="query" required="true">
        <cfargument name="storedMatches" type="struct" required="true">
        <cfargument name="nameIndex" type="struct" required="true">
        <cfargument name="dataFormat" type="any" required="true">
        <cfargument name="styleCache" type="struct" required="true">
        <cfargument name="headerStyle" type="any" required="true">

        <cfset var outputHeaders = []>
        <cfset var headerIndex = 0>
        <cfset var headerRow = "">
        <cfset var headerCell = "">
        <cfset var cells = []>
        <cfset var contact = "">
        <cfset var directorate = "">
        <cfset var poiRow = "">
        <cfset var poiColumn = 0>
        <cfset var sourceCell = {}>
        <cfset var columnFormat = "General">
        <cfset var excelRow = 1>
        <cfset var lineTotal = 1>
        <cfset var chars = 12>
        <cfset var filterRange = "">

        <cfloop from="1" to="#arrayLen(arguments.spec.columns)#" index="headerIndex">
            <cfset arrayAppend(outputHeaders, arguments.spec.columns[headerIndex] & "")>
            <cfif headerIndex EQ arguments.spec.contactIndex>
                <cfset arrayAppend(outputHeaders, "Directorate")>
            </cfif>
        </cfloop>

        <cfset headerRow = arguments.poiSheet.createRow(javacast("int", 0))>
        <cfloop from="1" to="#arrayLen(outputHeaders)#" index="headerIndex">
            <cfset headerCell = headerRow.createCell(javacast("int", headerIndex - 1))>
            <cfset headerCell.setCellValue(javacast("string", outputHeaders[headerIndex] & ""))>
            <cfset headerCell.setCellStyle(arguments.headerStyle)>
            <cfset chars = max(12, len(outputHeaders[headerIndex] & "") + 2)>
            <cfif headerIndex EQ arguments.spec.contactIndex OR headerIndex EQ arguments.spec.contactIndex + 1>
                <cfset chars = 42>
            </cfif>
            <cfset arguments.poiSheet.setColumnWidth(
                javacast("int", headerIndex - 1),
                javacast("int", min(chars, 55) * 256)
            )>
        </cfloop>

        <cfloop from="1" to="#arguments.sourceRows.recordCount#" index="excelRow">
            <cfset cells = deserializeJSON(arguments.sourceRows.SourceData[excelRow])>
            <cfif NOT isArray(cells)>
                <cfthrow
                    type="Export.InvalidSourceRow"
                    message="A saved spreadsheet row could not be read.">
            </cfif>

            <cfset contact = "">
            <cfif arrayLen(cells) GTE arguments.spec.contactIndex>
                <cfset contact = cellText(cells[arguments.spec.contactIndex])>
            </cfif>
            <cfset directorate = directorateTextForContact(
                contact = contact,
                storedMatches = arguments.storedMatches,
                nameIndex = arguments.nameIndex
            )>
            <cfset poiRow = arguments.poiSheet.createRow(javacast("int", excelRow))>
            <cfset poiColumn = 0>

            <cfloop from="1" to="#arrayLen(arguments.spec.columns)#" index="headerIndex">
                <cfif arrayLen(cells) GTE headerIndex>
                    <cfset sourceCell = cells[headerIndex]>
                <cfelse>
                    <cfset sourceCell = {t = "s", v = ""}>
                </cfif>
                <cfset columnFormat = "General">
                <cfif arrayLen(arguments.spec.formats) GTE headerIndex AND len(trim(arguments.spec.formats[headerIndex] & ""))>
                    <cfset columnFormat = arguments.spec.formats[headerIndex] & "">
                </cfif>
                <cfset writeExcelValue(
                    poiRow = poiRow,
                    poiColumn = poiColumn,
                    cell = sourceCell,
                    format = columnFormat,
                    wrap = (headerIndex EQ arguments.spec.contactIndex),
                    poiBook = arguments.poiBook,
                    dataFormat = arguments.dataFormat,
                    styleCache = arguments.styleCache
                )>
                <cfset poiColumn = poiColumn + 1>
                <cfif headerIndex EQ arguments.spec.contactIndex>
                    <cfset writeExcelValue(
                        poiRow = poiRow,
                        poiColumn = poiColumn,
                        cell = {t = "s", v = directorate},
                        format = "General",
                        wrap = true,
                        poiBook = arguments.poiBook,
                        dataFormat = arguments.dataFormat,
                        styleCache = arguments.styleCache
                    )>
                    <cfset poiColumn = poiColumn + 1>
                </cfif>
            </cfloop>

            <cfset lineTotal = max(lineCount(contact), lineCount(directorate))>
            <cfif lineTotal GT 1>
                <cfset poiRow.setHeight(javacast("short", min(lineTotal * 290, 8000)))>
            </cfif>
        </cfloop>

        <cfif arguments.sourceRows.recordCount GT 0>
            <cfset filterRange = createObject("java", "org.apache.poi.ss.util.CellRangeAddress").init(
                javacast("int", 0),
                javacast("int", arguments.sourceRows.recordCount),
                javacast("int", 0),
                javacast("int", arrayLen(outputHeaders) - 1)
            )>
            <cfset arguments.poiSheet.setAutoFilter(filterRange)>
        </cfif>

        <cfreturn arguments.sourceRows.recordCount>
    </cffunction>

    <cffunction name="writeExcelValue" access="private" returntype="void" output="false">
        <cfargument name="poiRow" type="any" required="true">
        <cfargument name="poiColumn" type="numeric" required="true">
        <cfargument name="cell" type="any" required="true">
        <cfargument name="format" type="string" required="true">
        <cfargument name="wrap" type="boolean" required="true">
        <cfargument name="poiBook" type="any" required="true">
        <cfargument name="dataFormat" type="any" required="true">
        <cfargument name="styleCache" type="struct" required="true">

        <cfset var stored = storedCell(arguments.cell)>
        <cfset var cellFormat = arguments.format>
        <cfset var poiCell = "">
        <cfset var style = "">

        <cfif stored.t EQ "s" AND NOT len(trim(stored.v & ""))>
            <cfreturn>
        </cfif>

        <cfset poiCell = arguments.poiRow.createCell(javacast("int", arguments.poiColumn))>
        <cfif stored.t EQ "n" OR stored.t EQ "d">
            <cfset poiCell.setCellValue(javacast("double", val(stored.v)))>
            <cfif stored.t EQ "d" AND (NOT len(cellFormat) OR compareNoCase(cellFormat, "General") EQ 0)>
                <cfset cellFormat = "mm-dd-yy">
            </cfif>
        <cfelse>
            <cfset poiCell.setCellValue(javacast("string", stored.v & ""))>
        </cfif>

        <cfset style = workbookStyle(
            poiBook = arguments.poiBook,
            dataFormat = arguments.dataFormat,
            styleCache = arguments.styleCache,
            format = cellFormat,
            wrap = arguments.wrap
        )>
        <cfif NOT isSimpleValue(style)>
            <cfset poiCell.setCellStyle(style)>
        </cfif>
    </cffunction>

    <cffunction name="workbookStyle" access="private" returntype="any" output="false">
        <cfargument name="poiBook" type="any" required="true">
        <cfargument name="dataFormat" type="any" required="true">
        <cfargument name="styleCache" type="struct" required="true">
        <cfargument name="format" type="string" required="true">
        <cfargument name="wrap" type="boolean" required="true">

        <cfset var key = arguments.format & chr(1) & (arguments.wrap ? "1" : "0")>
        <cfset var style = "">

        <cfif compareNoCase(arguments.format, "General") EQ 0 AND NOT arguments.wrap>
            <cfreturn "">
        </cfif>

        <cfif structKeyExists(arguments.styleCache, key)>
            <cfreturn arguments.styleCache[key]>
        </cfif>

        <cfset style = arguments.poiBook.createCellStyle()>
        <cfif arguments.wrap>
            <cfset style.setWrapText(true)>
        </cfif>
        <cfif len(arguments.format) AND compareNoCase(arguments.format, "General") NEQ 0>
            <cftry>
                <cfset style.setDataFormat(arguments.dataFormat.getFormat(arguments.format))>
                <cfcatch type="any">
                </cfcatch>
            </cftry>
        </cfif>

        <cfset arguments.styleCache[key] = style>
        <cfreturn style>
    </cffunction>

    <cffunction name="headerSpec" access="private" returntype="struct" output="false">
        <cfargument name="headerJson" type="string" required="true">

        <cfset var parsed = deserializeJSON(arguments.headerJson)>
        <cfset var spec = {}>
        <cfset var headerIndex = 0>
        <cfset var format = "">

        <cfif NOT isStruct(parsed)>
            <cfthrow
                type="Export.InvalidSource"
                message="The saved spreadsheet columns could not be read.">
        </cfif>

        <cfset spec.columns = structValue(parsed, "columns", [])>
        <cfset spec.formats = structValue(parsed, "formats", [])>
        <cfset spec.sheetName = structValue(parsed, "sheetName", "data") & "">
        <cfset spec.contactIndex = val(structValue(parsed, "contactIndex", 0))>

        <cfif NOT isArray(spec.columns) OR NOT arrayLen(spec.columns)>
            <cfthrow
                type="Export.InvalidSource"
                message="The saved spreadsheet columns could not be read.">
        </cfif>
        <cfif NOT isArray(spec.formats)>
            <cfset spec.formats = []>
        </cfif>

        <cfloop from="1" to="#arrayLen(spec.columns)#" index="headerIndex">
            <cfif arrayLen(spec.formats) LT headerIndex>
                <cfset arrayAppend(spec.formats, "General")>
            <cfelse>
                <cfset format = spec.formats[headerIndex] & "">
                <cfif NOT len(trim(format))>
                    <cfset spec.formats[headerIndex] = "General">
                </cfif>
            </cfif>
        </cfloop>

        <cfif spec.contactIndex LT 1 OR spec.contactIndex GT arrayLen(spec.columns)>
            <cfset spec.contactIndex = findHeaderIndex(spec.columns, "contact")>
        </cfif>
        <cfif spec.contactIndex LT 1>
            <cfthrow
                type="Export.ContactColumnMissing"
                message="The contact column was not found in the saved spreadsheet.">
        </cfif>
        <cfif NOT len(trim(spec.sheetName))>
            <cfset spec.sheetName = "data">
        </cfif>

        <cfreturn spec>
    </cffunction>

    <cffunction name="structValue" access="private" returntype="any" output="false">
        <cfargument name="data" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="any" required="false">

        <cfset var found = "">

        <cfloop collection="#arguments.data#" item="found">
            <cfif compareNoCase(found, arguments.key) EQ 0>
                <cfreturn arguments.data[found]>
            </cfif>
        </cfloop>

        <cfif structKeyExists(arguments, "defaultValue")>
            <cfreturn arguments.defaultValue>
        </cfif>

        <cfreturn "">
    </cffunction>

    <cffunction name="directorateTextForContact" access="private" returntype="string" output="false">
        <cfargument name="contact" type="string" required="true">
        <cfargument name="storedMatches" type="struct" required="true">
        <cfargument name="nameIndex" type="struct" required="true">

        <cfset var names = parseContactNames(arguments.contact)>
        <cfset var storedKey = normalizeContactKey(arguments.contact)>
        <cfset var stored = {}>
        <cfset var storedDirectorate = "">
        <cfset var lines = []>
        <cfset var line = "">
        <cfset var name = {}>
        <cfset var personIndex = 0>
        <cfset var anyLine = false>

        <cfif structKeyExists(arguments.storedMatches, storedKey)>
            <cfset stored = arguments.storedMatches[storedKey]>
            <cfset storedDirectorate = trim(stored.directorate & "")>
        </cfif>

        <cfif NOT arrayLen(names)>
            <cfreturn storedDirectorate>
        </cfif>

        <cfloop from="1" to="#arrayLen(names)#" index="personIndex">
            <cfset name = names[personIndex]>
            <cfset line = "">

            <cfif personIndex EQ 1 AND len(storedDirectorate) AND (arrayLen(names) EQ 1 OR samePerson(stored, name))>
                <cfset line = storedDirectorate>
            </cfif>
            <cfif NOT len(line)>
                <cfset line = directoryDirectorate(name, arguments.nameIndex)>
            </cfif>
            <cfif NOT len(line) AND len(storedDirectorate) AND samePerson(stored, name)>
                <cfset line = storedDirectorate>
            </cfif>

            <cfif len(line)>
                <cfset anyLine = true>
            </cfif>
            <cfset arrayAppend(lines, line)>
        </cfloop>

        <cfif NOT anyLine>
            <cfif arrayLen(names) GT 1 AND len(storedDirectorate)>
                <cfreturn storedDirectorate>
            </cfif>
            <cfreturn "">
        </cfif>

        <cfreturn joinLines(lines)>
    </cffunction>

    <cffunction name="samePerson" access="private" returntype="boolean" output="false">
        <cfargument name="stored" type="struct" required="true">
        <cfargument name="name" type="struct" required="true">

        <cfif NOT structKeyExists(arguments.stored, "firstName") OR NOT len(trim(arguments.stored.firstName & ""))>
            <cfreturn false>
        </cfif>

        <cfreturn compare(compactName(arguments.stored.lastName & ""), compactName(arguments.name.lastName)) EQ 0
            AND compare(compactName(arguments.stored.firstName & ""), compactName(arguments.name.firstName)) EQ 0>
    </cffunction>

    <cffunction name="directoryDirectorate" access="private" returntype="string" output="false">
        <cfargument name="name" type="struct" required="true">
        <cfargument name="nameIndex" type="struct" required="true">

        <cfset var key = compactName(arguments.name.lastName) & "|" & compactName(arguments.name.firstName)>

        <cfif NOT structKeyExists(arguments.nameIndex, key) OR arguments.nameIndex[key].ambiguous>
            <cfreturn "">
        </cfif>

        <cfreturn trim(arguments.nameIndex[key].user.directorateNameE & "")>
    </cffunction>

    <cffunction name="joinLines" access="private" returntype="string" output="false">
        <cfargument name="lines" type="array" required="true">

        <cfset var text = "">
        <cfset var lineIndex = 0>

        <cfif NOT arrayLen(arguments.lines)>
            <cfreturn "">
        </cfif>

        <cfset text = arguments.lines[1] & "">
        <cfloop from="2" to="#arrayLen(arguments.lines)#" index="lineIndex">
            <cfset text &= chr(10) & (arguments.lines[lineIndex] & "")>
        </cfloop>

        <cfreturn text>
    </cffunction>

    <cffunction name="lineCount" access="private" returntype="numeric" output="false">
        <cfargument name="text" type="string" required="true">

        <cfset var normalized = reReplace(arguments.text, "\r\n|\r", chr(10), "all")>
        <cfset var count = 1>
        <cfset var charIndex = 0>

        <cfif NOT len(normalized)>
            <cfreturn 1>
        </cfif>

        <cfloop from="1" to="#len(normalized)#" index="charIndex">
            <cfif mid(normalized, charIndex, 1) EQ chr(10)>
                <cfset count = count + 1>
            </cfif>
        </cfloop>

        <cfreturn count>
    </cffunction>

    <cffunction name="closeWorkbook" access="private" returntype="void" output="false">
        <cfargument name="poiBook" type="any" required="true">

        <cfif isSimpleValue(arguments.poiBook)>
            <cfreturn>
        </cfif>

        <cftry>
            <cfset arguments.poiBook.close()>
            <cfcatch type="any">
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="poiWorkbook" access="private" returntype="any" output="false">
        <cfargument name="workbook" type="any" required="true">

        <cftry>
            <cfreturn arguments.workbook.getWorkBook()>
            <cfcatch type="any">
                <cfreturn arguments.workbook.getWorkbook()>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="sanitizeSheetName" access="private" returntype="string" output="false">
        <cfargument name="sheetName" type="string" required="true">

        <cfset var label = trim(reReplace(arguments.sheetName, "[:\\/?*\[\]]", " ", "all"))>

        <cfif NOT len(label)>
            <cfreturn "data">
        </cfif>

        <cfreturn left(label, 31)>
    </cffunction>

    <cffunction name="uniqueSheetName" access="private" returntype="string" output="false">
        <cfargument name="fileName" type="string" required="true">
        <cfargument name="usedNames" type="struct" required="true">

        <cfset var base = reReplace(arguments.fileName, "(?i)\.(xlsx|xls)$", "")>
        <cfset var label = sanitizeSheetName(base)>
        <cfset var suffix = "">
        <cfset var attempt = 2>

        <cfloop condition="structKeyExists(arguments.usedNames, lcase(label)) AND attempt LT 50">
            <cfset suffix = " #attempt#">
            <cfset label = left(sanitizeSheetName(base), 31 - len(suffix)) & suffix>
            <cfset attempt = attempt + 1>
        </cfloop>

        <cfset arguments.usedNames[lcase(label)] = true>
        <cfreturn label>
    </cffunction>

    <cffunction name="saveWorkbook" access="private" returntype="void" output="false">
        <cfargument name="poiBook" type="any" required="true">
        <cfargument name="filePath" type="string" required="true">

        <cfset var outStream = "">
        <cfset var failed = false>
        <cfset var thrown = {}>

        <cftry>
            <cfset outStream = createObject("java", "java.io.FileOutputStream").init(arguments.filePath)>
            <cfset arguments.poiBook.write(outStream)>
            <cfcatch type="any">
                <cfset failed = true>
                <cfset thrown = cfcatch>
            </cfcatch>
            <cffinally>
                <cfif NOT isSimpleValue(outStream)>
                    <cftry>
                        <cfset outStream.close()>
                        <cfcatch type="any">
                        </cfcatch>
                    </cftry>
                </cfif>
                <cftry>
                    <cfset arguments.poiBook.close()>
                    <cfcatch type="any">
                    </cfcatch>
                </cftry>
            </cffinally>
        </cftry>

        <cfif failed>
            <cfif fileExists(arguments.filePath)>
                <cftry>
                    <cffile action="delete" file="#arguments.filePath#">
                    <cfcatch type="any">
                    </cfcatch>
                </cftry>
            </cfif>
            <cfthrow
                type="Export.WriteFailed"
                message="#structKeyExists(thrown, 'message') ? thrown.message : 'The Excel file could not be written.'#"
                detail="#structKeyExists(thrown, 'detail') ? thrown.detail : ''#">
        </cfif>
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
                ClientContact,
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
                IsManager,
                MatchStatus,
                CAST(NULL AS NVARCHAR(MAX)) AS ErrorMessage
            FROM dbo.TimekeepingEnriched
            <cfif arguments.batchFilter GT 0>
                WHERE ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>

            UNION ALL

            SELECT
                ClientFirstName,
                ClientLastName,
                CASE
                    WHEN ClientEmail LIKE 'c:%' AND ClientEmail NOT LIKE '%@%' THEN NULL
                    ELSE ClientEmail
                END,
                CAST(NULL AS NVARCHAR(50)),
                ClientContact,
                RecordedHours,
                CAST(NULL AS NVARCHAR(255)),
                CAST(NULL AS NVARCHAR(50)),
                CAST(NULL AS NVARCHAR(255)),
                CAST(NULL AS NVARCHAR(50)),
                CAST(NULL AS NVARCHAR(255)),
                CAST(NULL AS NVARCHAR(50)),
                CAST(NULL AS NVARCHAR(255)),
                CAST(NULL AS NVARCHAR(50)),
                CAST(NULL AS NVARCHAR(50)),
                CAST(NULL AS BIT),
                'Unmatched',
                ErrorMessage
            FROM dbo.UnmatchedClients
            WHERE Active = 1
            <cfif arguments.batchFilter GT 0>
                AND ImportBatchID = <cfqueryparam value="#arguments.batchFilter#" cfsqltype="cf_sql_integer">
            </cfif>

            ORDER BY MatchStatus, DirectorateNameE, ClientLastName, ClientFirstName
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
