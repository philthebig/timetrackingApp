<cfparam name="url.batch" default="0">
<cfparam name="url.page" default="1">
<cfparam name="url.tab" default="Active">
<cfparam name="url.compare" default="">

<cfset compareRedirect = "">
<cfif isNumeric(url.compare)>
    <cfset compareRedirect = "&compare=#int(val(url.compare))#">
</cfif>

<cfset batchFilter = val(url.batch)>
<cfset currentPage = max(val(url.page), 1)>
<cfset pageSize = 20>

<cfset requestedTab = url.tab>

<cfif structKeyExists(form, "submittedTab")>
    <cfset requestedTab = form.submittedTab>
</cfif>

<cfif compareNoCase(requestedTab, "Deleted") EQ 0>
    <cfset selectedTab = "Deleted">
<cfelse>
    <cfset selectedTab = "Active">
</cfif>

<cfif structKeyExists(form, "saveEmailButton")>

    <cfset editResult = {
        success = false,
        errorMessage = ""
    }>

    <cfif batchFilter LTE 0>
        <cfset editResult.errorMessage = "Please select a specific batch before editing an email.">
    <cfelse>
        <cfinvoke
            component="#application.query#"
            method="editEmail"
            returnvariable="editResult">
            <cfinvokeargument
                name="batchID"
                value="#batchFilter#">
            <cfinvokeargument
                name="oldEmail"
                value="#structKeyExists(form, 'oldEmail')
                    ? trim(form.oldEmail)
                    : ''#">
            <cfinvokeargument
                name="newEmail"
                value="#structKeyExists(form, 'newEmail')
                    ? trim(form.newEmail)
                    : ''#">
        </cfinvoke>
    </cfif>

    <cfif editResult.success>
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=#encodeForURL(selectedTab)#&emailUpdated=1#compareRedirect#" addtoken="false">
    </cfif>
<cfelseif structKeyExists(form,"deleteButton")>
    <cfset deleteResult = {
        success = false,
        errorMessage = ""
    }>

    <cfif batchFilter LTE 0>
        <cfset deleteResult.errorMessage = "Please select a specific batch before deleting a client.">
    <cfelse>
        <cfinvoke
            component="#application.query#"
            method="deleteClient"
            returnvariable="deleteResult">
            <cfinvokeargument
                name="batchID"
                value="#batchFilter#">
            <cfinvokeargument
                name="email"
                value="#structKeyExists(form, 'email')
                    ? trim(form.email)
                    : ''#">
        </cfinvoke>
    </cfif>

    <cfif deleteResult.success>
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=Deleted&deleted=1#compareRedirect#" addtoken="false">
    </cfif>
<cfelseif structKeyExists(form,"forceButton")>
    <cfset forceResult = {
        success = false,
        errorMessage = ""
    }>

    <cfif batchFilter LTE 0>
        <cfset forceResult.errorMessage = "Please select a specific batch before adding a client.">
    <cfelse>
        <cfinvoke
            component="#application.query#"
            method="forceAdd"
            returnvariable="forceResult">
            <cfinvokeargument
                name="batchID"
                value="#batchFilter#">
            <cfinvokeargument
                name="directorateID"
                value="#structKeyExists(form, 'directorateID')
                    ? trim(form.directorateID)
                    : ''#">
            <cfinvokeargument
                name="email"
                value="#structKeyExists(form, 'emailForce')
                    ? trim(form.emailForce)
                    : ''#">
        </cfinvoke>
    </cfif>

    <cfif forceResult.success>
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=Active&added=1#compareRedirect#" addtoken="false">
    </cfif>
<cfelseif structKeyExists(form,"recoveryButton")>
    <cfset recoveryResult = {
        success = false,
        errorMessage = ""
    }>

    <cfif batchFilter LTE 0>
        <cfset recoveryResult.errorMessage = "Please select a specific batch before recovering a client.">
    <cfelse>
        <cfinvoke
            component="#application.query#"
            method="recoverClient"
            returnvariable="recoveryResult">
            <cfinvokeargument
                name="batchID"
                value="#batchFilter#">
            <cfinvokeargument
                name="email"
                value="#structKeyExists(form, 'emailRecoveryInput')
                    ? trim(form.emailRecoveryInput)
                    : ''#">
        </cfinvoke>
    </cfif>

    <cfif recoveryResult.success>
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=Active&recovered=1#compareRedirect#" addtoken="false">
    </cfif>
<cfelseif structKeyExists(form, "deleteBatchButton")>
    <cfset deleteBatchResult = {
        success = false,
        errorMessage = ""
    }>

    <cfif batchFilter LTE 0>
        <cfset deleteBatchResult.errorMessage = "Please select a specific batch before deleting.">
    <cfelse>
        <cfinvoke
            component="#application.query#"
            method="deleteBatch"
            returnvariable="deleteBatchResult">
            <cfinvokeargument
                name="batchID"
                value="#batchFilter#">
        </cfinvoke>
    </cfif>

    <cfif deleteBatchResult.success>
        <cflocation url="index.cfm?batchDeleted=1" addtoken="false">
    </cfif>
</cfif>

<cfinclude template="navbar.cfm">
    <div class="container-fluid mt-perso">

        <cfset args = {
            batchFilter = batchFilter
        }>
        
        <cfinvoke component="#application.query#" method="allBatches" returnvariable="batches">

        <!--- Get batch info if specified --->
        <cfif batchFilter GT 0>
            <cfinvoke component="#application.query#" method="batchInfo" returnvariable="info" argumentcollection="#args#">
        </cfif>

        <cfset previousBatchID = 0>
        <cfset previousFileName = "">
        <cfset previousImportDate = "">
        <cfset compareBatchID = 0>
        <cfset compareFileName = "">
        <cfset compareImportDate = "">
        <cfset compareIsPrevious = false>
        <cfset compareVersus = "">

        <cfif batchFilter GT 0 AND isDefined("info") AND info.recordCount GT 0>
            <cfloop query="batches">
                <cfif batches.BatchID EQ batchFilter OR NOT isDate(batches.ImportDate) OR NOT isDate(info.ImportDate)>
                    <cfcontinue>
                </cfif>

                <cfset dateCmp = dateCompare(batches.ImportDate, info.ImportDate)>
                <cfset isOlderBatch = dateCmp LT 0 OR (dateCmp EQ 0 AND batches.BatchID LT batchFilter)>

                <cfif isOlderBatch>
                    <cfif previousBatchID EQ 0>
                        <cfset previousBatchID = batches.BatchID>
                        <cfset previousFileName = batches.FileName>
                        <cfset previousImportDate = batches.ImportDate>
                    <cfelse>
                        <cfset prevCmp = dateCompare(batches.ImportDate, previousImportDate)>
                        <cfif prevCmp GT 0 OR (prevCmp EQ 0 AND batches.BatchID GT previousBatchID)>
                            <cfset previousBatchID = batches.BatchID>
                            <cfset previousFileName = batches.FileName>
                            <cfset previousImportDate = batches.ImportDate>
                        </cfif>
                    </cfif>
                </cfif>
            </cfloop>

            <cfset requestedCompare = -1>
            <cfif isNumeric(url.compare)>
                <cfset requestedCompare = int(val(url.compare))>
            </cfif>

            <cfif requestedCompare EQ 0>
                <cfset compareBatchID = 0>
            <cfelseif requestedCompare GT 0 AND requestedCompare NEQ batchFilter>
                <cfloop query="batches">
                    <cfif batches.BatchID EQ requestedCompare>
                        <cfset compareBatchID = requestedCompare>
                        <cfset compareFileName = batches.FileName>
                        <cfset compareImportDate = batches.ImportDate>
                        <cfbreak>
                    </cfif>
                </cfloop>

                <cfif compareBatchID EQ 0>
                    <cfset compareBatchID = previousBatchID>
                </cfif>
            <cfelse>
                <cfset compareBatchID = previousBatchID>
            </cfif>

            <cfif compareBatchID GT 0 AND compareBatchID EQ previousBatchID>
                <cfset compareFileName = previousFileName>
                <cfset compareImportDate = previousImportDate>
            </cfif>

            <cfset compareIsPrevious = compareBatchID GT 0 AND compareBatchID EQ previousBatchID>

            <cfif compareBatchID GT 0>
                <cfset compareVersus = "Batch ##" & compareBatchID>
                <cfif isDate(compareImportDate)>
                    <cfset compareVersus = compareVersus & " (" & dateFormat(compareImportDate, "mmm d, yyyy") & ")">
                </cfif>
            </cfif>
        </cfif>
        
        <!--- Statistics Query --->
        <cfinvoke component="#application.query#" method="stats" returnvariable="statistics" argumentcollection="#args#">
        
        <!--- Directorate breakdown --->
        <cfinvoke component="#application.query#" method="directorateStats" returnvariable="directorate" argumentcollection="#args#">
        <cfinvoke component="#application.query#" method="getDirectorates" returnvariable="directorates">

        <cfif compareBatchID GT 0>
            <cfset compareArgs = { batchFilter = compareBatchID }>
            <cfinvoke component="#application.query#" method="stats" returnvariable="compareStats" argumentcollection="#compareArgs#">
            <cfinvoke component="#application.query#" method="directorateStats" returnvariable="compareDirectorate" argumentcollection="#compareArgs#">
        </cfif>

        <cfset startRow = ((currentPage - 1) * pageSize) + 1>

        <cfset argsUnmatched = {
            batchFilter = batchFilter,
            startRow = startRow,
            pageSize = pageSize,
            tab = selectedTab
        }>

        <cfinvoke component="#application.query#" method="unmatchedPages" returnvariable="unmatchedResult" argumentcollection="#argsUnmatched#">

        <cfset totalUnmatchedEmail = val(unmatchedResult.totalItems)>
        <cfset totalPages = max(ceiling(totalUnmatchedEmail / pageSize), 1)>
        <cfif currentPage GT totalPages>
            <cfset currentPage = totalPages>
            <cfset startRow = ((currentPage - 1) * pageSize) + 1>
            <cfset argsUnmatched.startRow = startRow>
            <cfinvoke component="#application.query#" method="unmatchedPages" returnvariable="unmatchedResult" argumentcollection="#argsUnmatched#">
            <cfset totalUnmatchedEmail = val(unmatchedResult.totalItems)>
        </cfif>

        <cfset unmatched = unmatchedResult.items>

        <!--- Build chart data as CF arrays (for safe JSON serialization) --->
        <cfset chartLabels = []>
        <cfset chartData = []>
        <cfset chartCompareData = []>
        <cfset chartRows = []>
        <cfset seenDirectorates = {}>

        <cfloop query="directorate">
            <cfset arrayAppend(chartRows, {
                name = directorate.Directorate,
                current = val(directorate.TotalHours),
                compare = 0,
                currentCount = val(directorate.RecordCount),
                compareCount = 0
            })>
            <cfset seenDirectorates[directorate.Directorate] = arrayLen(chartRows)>
        </cfloop>

        <cfif compareBatchID GT 0 AND isDefined("compareDirectorate")>
            <cfloop query="compareDirectorate">
                <cfif structKeyExists(seenDirectorates, compareDirectorate.Directorate)>
                    <cfset rowIndex = seenDirectorates[compareDirectorate.Directorate]>
                    <cfset matchedDirectorate = chartRows[rowIndex]>
                    <cfset matchedDirectorate.compare = val(compareDirectorate.TotalHours)>
                    <cfset matchedDirectorate.compareCount = val(compareDirectorate.RecordCount)>
                    <cfset chartRows[rowIndex] = matchedDirectorate>
                <cfelse>
                    <cfset arrayAppend(chartRows, {
                        name = compareDirectorate.Directorate,
                        current = 0,
                        compare = val(compareDirectorate.TotalHours),
                        currentCount = 0,
                        compareCount = val(compareDirectorate.RecordCount)
                    })>
                    <cfset seenDirectorates[compareDirectorate.Directorate] = arrayLen(chartRows)>
                </cfif>
            </cfloop>
        </cfif>

        <cfset chartCurrentLabel = "This batch">
        <cfset chartCompareLabel = "Comparison">
        <cfif batchFilter GT 0 AND isDefined("info") AND info.recordCount GT 0>
            <cfset chartCurrentLabel = "Batch ##" & batchFilter & " (" & dateFormat(info.ImportDate, "mm/dd/yyyy") & ")">
        </cfif>
        <cfif compareBatchID GT 0 AND isDate(compareImportDate)>
            <cfset chartCompareLabel = "Batch ##" & compareBatchID & " (" & dateFormat(compareImportDate, "mm/dd/yyyy") & ")">
        <cfelseif compareBatchID GT 0>
            <cfset chartCompareLabel = "Batch ##" & compareBatchID>
        </cfif>

        <cfloop array="#chartRows#" index="chartRow">
            <cfset arrayAppend(chartLabels, chartRow.name)>
            <cfset arrayAppend(chartData, val(numberFormat(chartRow.current, "9999999999.99")))>
            <cfif compareBatchID GT 0>
                <cfset arrayAppend(chartCompareData, val(numberFormat(chartRow.compare, "9999999999.99")))>
            </cfif>
        </cfloop>

        <cfif arrayLen(chartRows) GT 0>
            <script>
                const chartLabels = <cfoutput>#serializeJSON(chartLabels)#</cfoutput>;
                const chartValues = <cfoutput>#serializeJSON(chartData)#</cfoutput>;
                const chartCompareValues = <cfoutput>#serializeJSON(chartCompareData)#</cfoutput>;
                const chartCurrentLabel = <cfoutput>#serializeJSON(chartCurrentLabel)#</cfoutput>;
                const chartCompareLabel = <cfoutput>#serializeJSON(chartCompareLabel)#</cfoutput>;
            </script>
        </cfif>

        <!--- Header with batch info --->
        <div class="row mb-4">
            <div class="col-md-8">
                <cfif batchFilter GT 0 AND isDefined("info") AND info.recordCount GT 0>
                    <cfoutput>
                    <h2 class="align-items-center d-flex gap-3 flex-wrap"><div><i class="fas fa-filter"></i> Batch Details</div>
                        <span class="badge bg-<cfif info.ProcessingStatus EQ 'Completed'>success<cfelseif info.ProcessingStatus EQ 'Processing'>warning<cfelse>danger</cfif>">
                            #info.ProcessingStatus#
                        </span>
                    </h2>
                    <p class="text-muted mb-2">
                    Viewing: <strong>#info.FileName#</strong> 
                    (Imported: #dateFormat(info.ImportDate, "mmm d, yyyy")#)
                    </p>
                    <form action="dashboard.cfm?batch=#batchFilter##compareRedirect#" method="post" class="d-inline" onsubmit="return confirm('Delete batch ###batchFilter# (#jsStringFormat(info.FileName)#) and all of its imported data? This cannot be undone.');">
                        <button type="submit" name="deleteBatchButton" value="1" class="btn btn-outline-danger btn-sm">
                            <i class="fas fa-trash"></i> Delete Batch
                        </button>
                    </form>
                    </cfoutput>
                <cfelse>
                    <h2><i class="fas fa-chart-line"></i> All Batches Overview</h2>
                    <p class="text-muted mb-0">Aggregate view of all imported timekeeping data</p>
                    <p class="text-muted small mb-0">Select a batch to compare it with the previous import.</p>
                </cfif>
            </div>
            
            <div class="col-md-4">
                <form action="dashboard.cfm" method="get">
                    <cfoutput>
                        <input type="hidden" name="tab" value="#encodeForHTMLAttribute(selectedTab)#">
                    </cfoutput>

                    <label for="batchSelect" class="form-label small text-muted mb-1">
                        Switch View:
                    </label>

                    <div class="input-group">
                        <span class="input-group-text bg-white border-end-0">
                            <i class="fas fa-calendar-alt text-primary"></i>
                        </span>

                        <select name="batch" id="batchSelect" class="form-select border-start-0" onchange="this.form.submit()">
                            <option value="0" <cfif batchFilter EQ 0>selected</cfif>>
                                Show All Batches
                            </option>

                            <cfoutput query="batches">
                                <option
                                    value="#BatchID#"
                                    <cfif batchFilter EQ BatchID>selected</cfif>>
                                    ###BatchID# -
                                    #dateFormat(ImportDate, "mm/dd/yyyy")#
                                    (#encodeForHTML(FileName)#)
                                </option>
                            </cfoutput>
                        </select>
                    </div>
                </form>
            </div>
        </div>

        <cfif structKeyExists(url, "emailUpdated") AND val(url.emailUpdated) EQ 1>
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                <i class="fas fa-check-circle"></i>
                The email was updated and the affected records were reprocessed.

                <button id="closeBtn" type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <cfelseif structKeyExists(url, "deleted") AND val(url.deleted) EQ 1>
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                <i class="fas fa-check-circle"></i>
                The client was deleted with success.

                <button id="closeBtn" type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <cfelseif structKeyExists(url, "added") AND val(url.added) EQ 1>
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                <i class="fas fa-check-circle"></i>
                The client was added with success.

                <button id="closeBtn" type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <cfelseif structKeyExists(url, "recovered") AND val(url.recovered) EQ 1>
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                <i class="fas fa-check-circle"></i>
                The client was recovered with success.

                <button id="closeBtn" type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        </cfif>

        <cfif isDefined("editResult")
            AND NOT editResult.success
            AND len(editResult.errorMessage)>

            <div class="alert alert-danger text-wrap" role="alert">
                <i class="fas fa-exclamation-circle"></i>
                <cfoutput>
                    #encodeForHTML(editResult.errorMessage)#
                </cfoutput>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <cfelseif isDefined("deleteResult")
            AND NOT deleteResult.success
            AND len(deleteResult.errorMessage)>

            <div class="alert alert-danger text-wrap" role="alert">
                <i class="fas fa-exclamation-circle"></i>
                <cfoutput>
                    #encodeForHTML(deleteResult.errorMessage)#
                </cfoutput>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <cfelseif isDefined("forceResult")
            AND NOT forceResult.success
            AND len(forceResult.errorMessage)>

            <div class="alert alert-danger text-wrap" role="alert">
                <i class="fas fa-exclamation-circle"></i>
                <cfoutput>
                    #encodeForHTML(forceResult.errorMessage)#
                </cfoutput>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <cfelseif isDefined("recoveryResult")
            AND NOT recoveryResult.success
            AND len(recoveryResult.errorMessage)>

            <div class="alert alert-danger text-wrap" role="alert">
                <i class="fas fa-exclamation-circle"></i>
                <cfoutput>
                    #encodeForHTML(recoveryResult.errorMessage)#
                </cfoutput>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <cfelseif isDefined("deleteBatchResult")
            AND NOT deleteBatchResult.success
            AND len(deleteBatchResult.errorMessage)>

            <div class="alert alert-danger text-wrap" role="alert">
                <i class="fas fa-exclamation-circle"></i>
                <cfoutput>
                    #encodeForHTML(deleteBatchResult.errorMessage)#
                </cfoutput>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        </cfif>

        <cfscript>
            function comparisonDelta(currentValue, baselineValue, kind, polarity) {
                var currentNumber = val(arguments.currentValue);
                var baselineNumber = val(arguments.baselineValue);
                var delta = currentNumber - baselineNumber;
                var direction = "flat";
                var tone = "neutral";
                var icon = "minus";
                var amount = "";
                var detail = "";
                var text = "";
                var percent = 0;

                if (delta > 0) {
                    direction = "up";
                    icon = "arrow-up";
                } else if (delta < 0) {
                    direction = "down";
                    icon = "arrow-down";
                }

                if (arguments.polarity == "higher" || arguments.polarity == "lower") {
                    if (delta != 0) {
                        if ((arguments.polarity == "higher" && delta > 0) || (arguments.polarity == "lower" && delta < 0)) {
                            tone = "better";
                        } else {
                            tone = "worse";
                        }
                    }
                }

                if (delta == 0) {
                    text = "No change";
                } else {
                    if (arguments.kind == "hours") {
                        amount = numberFormat(abs(delta), "999,999.99");
                    } else if (arguments.kind == "rate") {
                        amount = numberFormat(abs(delta), "99.9");
                    } else {
                        amount = numberFormat(abs(delta));
                    }

                    if (delta > 0) {
                        amount = "+" & amount;
                    } else {
                        amount = "-" & amount;
                    }

                    if (arguments.kind == "rate") {
                        detail = " pts";
                    } else if (baselineNumber != 0) {
                        percent = abs(delta / baselineNumber) * 100;
                        if (delta > 0) {
                            detail = " (+" & numberFormat(percent, "99.9") & "%)";
                        } else {
                            detail = " (-" & numberFormat(percent, "99.9") & "%)";
                        }
                    } else {
                        detail = " (new)";
                    }

                    text = amount & detail;
                }

                return {
                    "text": text,
                    "direction": direction,
                    "tone": tone,
                    "icon": icon
                };
            }

            baselineRecords = 0;
            baselineMatched = 0;
            baselineUnmatched = 0;
            baselineSkipped = 0;
            baselineRate = 0;
            baselineHours = 0;

            if (compareBatchID > 0) {
                baselineRecords = val(compareStats.dashTotalRecords);
                baselineMatched = val(compareStats.dashMatchedRecords);
                baselineUnmatched = val(compareStats.dashUnmatchedRecords);
                baselineSkipped = val(compareStats.dashSkippedRecords);
                baselineRate = val(compareStats.matchRate);
                baselineHours = val(compareStats.dashTotalHours);
            }

            statCards = [
                {
                    title: "Total Records",
                    icon: "fa-database",
                    tone: "bg-primary",
                    display: numberFormat(statistics.dashTotalRecords),
                    current: val(statistics.dashTotalRecords),
                    baseline: baselineRecords,
                    kind: "count",
                    polarity: "neutral"
                },
                {
                    title: "Matched",
                    icon: "fa-check",
                    tone: "bg-success",
                    display: numberFormat(statistics.dashMatchedRecords),
                    current: val(statistics.dashMatchedRecords),
                    baseline: baselineMatched,
                    kind: "count",
                    polarity: "higher"
                },
                {
                    title: "Unmatched",
                    icon: "fa-exclamation-triangle",
                    tone: "bg-warning",
                    display: numberFormat(statistics.dashUnmatchedRecords),
                    current: val(statistics.dashUnmatchedRecords),
                    baseline: baselineUnmatched,
                    kind: "count",
                    polarity: "lower"
                },
                {
                    title: "Skipped",
                    icon: "fa-forward",
                    tone: "bg-skipped",
                    display: numberFormat(statistics.dashSkippedRecords),
                    current: val(statistics.dashSkippedRecords),
                    baseline: baselineSkipped,
                    kind: "count",
                    polarity: "lower"
                },
                {
                    title: "Rate",
                    icon: "fa-percent",
                    tone: "bg-info",
                    display: numberFormat(statistics.matchRate, "99.9") & "%",
                    current: val(statistics.matchRate),
                    baseline: baselineRate,
                    kind: "rate",
                    polarity: "higher"
                },
                {
                    title: "Total Hours",
                    icon: "fa-clock",
                    tone: "bg-hours",
                    display: numberFormat(statistics.dashTotalHours, "999,999.99"),
                    current: val(statistics.dashTotalHours),
                    baseline: baselineHours,
                    kind: "hours",
                    polarity: "neutral"
                }
            ];
        </cfscript>

        <cfif batchFilter GT 0 AND isDefined("info") AND info.recordCount GT 0>
            <div class="card compare-panel">
                <div class="card-body">
                    <div class="row align-items-center g-3">
                        <div class="col-lg-7">
                            <div class="d-flex align-items-start gap-3">
                                <span class="compare-mark" aria-hidden="true">
                                    <i class="fas fa-code-compare"></i>
                                </span>
                                <div>
                                    <cfif batches.recordCount LTE 1>
                                        <div class="fw-semibold">Nothing to compare yet</div>
                                        <p class="text-muted small mb-0">
                                            This is the only imported batch. A comparison with the previous import appears once another batch is available.
                                        </p>
                                    <cfelseif compareBatchID GT 0>
                                        <cfoutput>
                                            <div class="fw-semibold d-flex align-items-center flex-wrap gap-2">
                                                Compared with batch ###compareBatchID#
                                                <cfif compareIsPrevious>
                                                    <span class="badge rounded-pill compare-badge">Previous batch</span>
                                                </cfif>
                                            </div>
                                            <p class="text-muted small mb-2">
                                                #encodeForHTML(compareFileName)#
                                                <cfif isDate(compareImportDate)>
                                                    · imported #dateFormat(compareImportDate, "mmm d, yyyy")#
                                                </cfif>
                                            </p>
                                            <div class="d-flex flex-wrap gap-3 small text-muted">
                                                <span><span class="compare-swatch compare-swatch-current"></span>This batch</span>
                                                <span><span class="compare-swatch compare-swatch-other"></span>#encodeForHTML(compareVersus)#</span>
                                            </div>
                                        </cfoutput>
                                    <cfelseif previousBatchID EQ 0>
                                        <div class="fw-semibold">No previous batch</div>
                                        <p class="text-muted small mb-0">
                                            This is the earliest import, so there is no previous batch. Choose a later batch if you still want a comparison.
                                        </p>
                                    <cfelse>
                                        <div class="fw-semibold">Comparison is off</div>
                                        <p class="text-muted small mb-0">
                                            Pick the previous batch, or any other import, to see what changed.
                                        </p>
                                    </cfif>
                                </div>
                            </div>
                        </div>

                        <cfif batches.recordCount GT 1>
                            <div class="col-lg-5">
                                <form action="dashboard.cfm" method="get">
                                    <cfoutput>
                                        <input type="hidden" name="batch" value="#batchFilter#">
                                        <input type="hidden" name="tab" value="#encodeForHTMLAttribute(selectedTab)#">
                                        <input type="hidden" name="page" value="#currentPage#">
                                    </cfoutput>
                                    <label for="compareSelect" class="form-label small text-muted mb-1">
                                        Compare with
                                    </label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-white border-end-0">
                                            <i class="fas fa-code-compare text-primary"></i>
                                        </span>
                                        <select name="compare" id="compareSelect" class="form-select border-start-0" onchange="this.form.submit()">
                                            <cfif previousBatchID GT 0>
                                                <cfoutput>
                                                    <option value="#previousBatchID#" <cfif compareBatchID EQ previousBatchID>selected</cfif>>
                                                        Previous batch · ###previousBatchID# - #dateFormat(previousImportDate, "mm/dd/yyyy")# (#encodeForHTML(previousFileName)#)
                                                    </option>
                                                </cfoutput>
                                            </cfif>
                                            <option value="0" <cfif compareBatchID EQ 0>selected</cfif>>
                                                No comparison
                                            </option>
                                            <cfset hasOtherCompareBatches = false>
                                            <cfloop query="batches">
                                                <cfif batches.BatchID NEQ batchFilter AND batches.BatchID NEQ previousBatchID>
                                                    <cfset hasOtherCompareBatches = true>
                                                    <cfbreak>
                                                </cfif>
                                            </cfloop>
                                            <cfif hasOtherCompareBatches>
                                                <optgroup label="Other batches">
                                                    <cfoutput query="batches">
                                                        <cfif BatchID NEQ batchFilter AND BatchID NEQ previousBatchID>
                                                            <option value="#BatchID#" <cfif compareBatchID EQ BatchID>selected</cfif>>
                                                                ###BatchID# - #dateFormat(ImportDate, "mm/dd/yyyy")# (#encodeForHTML(FileName)#)
                                                            </option>
                                                        </cfif>
                                                    </cfoutput>
                                                </optgroup>
                                            </cfif>
                                        </select>
                                    </div>
                                </form>
                            </div>
                        </cfif>
                    </div>
                </div>
            </div>
        </cfif>

        <!--- Statistics Cards --->
        <cfoutput>
            <div class="row mb-4 justify-content-between<cfif compareBatchID GT 0> stats-comparing</cfif>">
                <cfloop array="#statCards#" index="statCard">
                    <div class="<cfif compareBatchID GT 0>col-6 col-lg-4 col-xxl-2<cfelse>col-md-2</cfif>">
                        <div class="card text-white #statCard.tone# stat-card">
                            <div class="card-body">
                                <h5 class="card-title">
                                    <i class="fas #statCard.icon#"></i>
                                    #encodeForHTML(statCard.title)#
                                </h5>
                                <h2<cfif compareBatchID GT 0> class="mb-0"</cfif>>#statCard.display#</h2>
                                <cfif compareBatchID GT 0>
                                    <cfset statDelta = comparisonDelta(statCard.current, statCard.baseline, statCard.kind, statCard.polarity)>
                                    <div class="stat-delta stat-delta-#statDelta.tone#" title="Change versus #encodeForHTMLAttribute(compareVersus)#">
                                        <i class="fas fa-#statDelta.icon#" aria-hidden="true"></i>
                                        <span>#encodeForHTML(statDelta.text)#</span>
                                    </div>
                                </cfif>
                            </div>
                        </div>
                    </div>
                </cfloop>
            </div>
        </cfoutput>
        
        <!--- Charts Row --->
        <cfif arrayLen(chartRows) GT 0>
            <div class="row mb-4">
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header bg-primary text-white">
                            <h5 class="mb-0"><i class="fas fa-chart-bar"></i> Hours by Directorate</h5>
                        </div>
                        <div class="card-body">
                            <canvas id="directorateChart" height="300"></canvas>
                        </div>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header bg-primary text-white">
                            <h5 class="mb-0">
                                <i class="fas fa-chart-pie"></i> Distribution
                                <cfif compareBatchID GT 0>
                                    <span class="fw-normal small">(this batch)</span>
                                </cfif>
                            </h5>
                        </div>
                        <div class="card-body">
                            <canvas id="distributionChart" height="300"></canvas>
                        </div>
                    </div>
                </div>
            </div>

            <cfif compareBatchID GT 0>
                <div class="row mb-4">
                    <div class="col-12">
                        <div class="card">
                            <div class="card-header bg-primary text-white d-flex justify-content-between align-items-center flex-wrap gap-2">
                                <h5 class="mb-0"><i class="fas fa-right-left"></i> Directorate change</h5>
                                <cfoutput>
                                    <span class="badge bg-light text-dark">vs #encodeForHTML(compareVersus)#</span>
                                </cfoutput>
                            </div>
                            <div class="table-responsive">
                                <table class="table table-striped align-middle mb-0">
                                    <thead>
                                        <tr>
                                            <th>Directorate</th>
                                            <th class="text-end">
                                                <span class="compare-swatch compare-swatch-current"></span>This batch
                                            </th>
                                            <th class="text-end">
                                                <span class="compare-swatch compare-swatch-other"></span>Compared batch
                                            </th>
                                            <th class="text-end">Change</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <cfoutput>
                                            <cfloop array="#chartRows#" index="hoursRow">
                                                <cfset hoursDelta = comparisonDelta(hoursRow.current, hoursRow.compare, "hours", "neutral")>
                                                <tr>
                                                    <td>#encodeForHTML(hoursRow.name)#</td>
                                                    <td class="text-end">
                                                        <div>#numberFormat(hoursRow.current, "999,999.99")#</div>
                                                        <small class="text-muted">#numberFormat(hoursRow.currentCount)# records</small>
                                                    </td>
                                                    <td class="text-end">
                                                        <div>#numberFormat(hoursRow.compare, "999,999.99")#</div>
                                                        <small class="text-muted">#numberFormat(hoursRow.compareCount)# records</small>
                                                    </td>
                                                    <td class="text-end">
                                                        <span class="delta-pill delta-#hoursDelta.direction#">
                                                            <i class="fas fa-#hoursDelta.icon#" aria-hidden="true"></i>
                                                            #encodeForHTML(hoursDelta.text)#
                                                        </span>
                                                    </td>
                                                </tr>
                                            </cfloop>
                                        </cfoutput>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </cfif>
        </cfif>
        
        <div class="w-100 d-flex justify-content-center gap-5 mb-3 mt-5" role="tablist" aria-label="Unmatched client status">
            <button
                id="activeBtn"
                type="button"
                class="tab-btn<cfif selectedTab EQ 'Active'> active</cfif>"
                role="tab"
                aria-controls="unmatchedListContainer"
                aria-selected="<cfif selectedTab EQ 'Active'>true<cfelse>false</cfif>">
                Active
            </button>

            <button
                id="inactiveBtn"
                type="button"
                class="tab-btn<cfif selectedTab EQ 'Deleted'> active</cfif>"
                role="tab"
                aria-controls="unmatchedListContainer"
                aria-selected="<cfif selectedTab EQ 'Deleted'>true<cfelse>false</cfif>">
                Deleted
            </button>
        </div>

        <div id="unmatchedListContainer" aria-live="polite" aria-busy="false">
            <cfinclude template="_unmatchedList.cfm">
        </div>
        
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

    <!--- Edit email modal --->
    <div id="editModal" class="modal fade mt-perso" tabindex="-1" aria-labelledby="editModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">

                <div class="modal-header">
                    <h5 class="modal-title" id="editModalLabel">
                        Edit email
                    </h5>

                    <button
                        type="button"
                        class="btn-close"
                        data-bs-dismiss="modal"
                        aria-label="Close">
                    </button>
                </div>
                <cfoutput>
                <form action="dashboard.cfm?batch=#batchFilter##compareRedirect#" method="post">
                    <input type="hidden" name="submittedTab" class="js-current-tab" value="#encodeForHTMLAttribute(selectedTab)#">
                    <div class="modal-body">
                        <div class="mb-3">
                            <label for="oldEmail" class="form-label">
                                Old email
                            </label>

                            <input
                                type="email"
                                class="form-control"
                                id="oldEmail"
                                name="oldEmail"
                                readonly
                                required>
                        </div>

                        <div class="mb-3">
                            <label for="editEmail" class="form-label">
                                New email
                            </label>

                            <input
                                type="email"
                                class="form-control"
                                id="editEmail"
                                name="newEmail"
                                required>
                        </div>
                    </div>

                    <div class="modal-footer">
                        <button
                            type="button"
                            class="btn btn-secondary"
                            data-bs-dismiss="modal">
                            Close
                        </button>

                        <button
                            type="submit"
                            class="btn btn-primary"
                            id="saveEmailButton"
                            name="saveEmailButton">
                            Save changes
                        </button>
                    </div>
                </form>
                </cfoutput>
            </div>
        </div>
    </div>

    <!--- Force add modal --->
    <div id="forceAddModal" class="modal fade mt-perso" tabindex="-1" aria-labelledby="forceAddModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">

                <div class="modal-header">
                    <h5 class="modal-title" id="forceAddModalLabel">
                        Add a client
                    </h5>

                    <button
                        type="button"
                        class="btn-close"
                        data-bs-dismiss="modal"
                        aria-label="Close">
                    </button>
                </div>
                <cfoutput>
                <form action="dashboard.cfm?batch=#batchFilter##compareRedirect#" method="post">
                    <input type="hidden" name="submittedTab" class="js-current-tab" value="#encodeForHTMLAttribute(selectedTab)#">
                    <div class="modal-body">
                        <p>The client (<span id="clientDirectorate" class="fs-8"></span>) will be added to the following directory</p>

                        <div class="mb-3">
                            <label for="directorate" class="form-label">
                                Directorate
                            </label>
                            <select id="directorateSelect" name="directorateID" class="form-select">
                                <cfloop query="directorates">
                                    <option value="#ID#">#NameE#</option>
                                </cfloop>
                            </select>
                        </div>
                        <input type="text" id="emailForce" name="emailForce" hidden readonly>
                    </div>

                    <div class="modal-footer">
                        <button
                            type="button"
                            class="btn btn-secondary"
                            data-bs-dismiss="modal">
                            Close
                        </button>

                        <button
                            type="submit"
                            class="btn btn-warning"
                            id="forceButton"
                            name="forceButton">
                            Forced Addition
                        </button>
                    </div>
                </form>
                </cfoutput>
            </div>
        </div>
    </div>

    <!--- Delete modal --->
    <div id="deleteModal" class="modal fade mt-perso" tabindex="-1" aria-labelledby="deleteModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">

                <div class="modal-header">
                    <h5 class="modal-title" id="deleteModalLabel">
                        Delete
                    </h5>

                    <button
                        type="button"
                        class="btn-close"
                        data-bs-dismiss="modal"
                        aria-label="Close">
                    </button>
                </div>
                <cfoutput>
                <form action="dashboard.cfm?batch=#batchFilter##compareRedirect#" method="post">
                    <input type="hidden" name="submittedTab" class="js-current-tab" value="#encodeForHTMLAttribute(selectedTab)#">
                    <div class="modal-body">
                        <div class="mb-3">
                            <p class="m-0">Are you sure you want to delete this client?</p>
                            <span id="emailDelete" class="fw-bold"></span>
                        </div>
                        <input type="text" id="email" name="email" hidden readonly>
                    </div>

                    <div class="modal-footer">
                        <button
                            type="button"
                            class="btn btn-secondary"
                            data-bs-dismiss="modal">
                            Close
                        </button>

                        <button
                            type="submit"
                            class="btn btn-danger"
                            id="deleteButton"
                            name="deleteButton">
                            Delete
                        </button>
                    </div>
                </form>
                </cfoutput>
            </div>
        </div>
    </div>

    <!--- Recovery modal --->
    <div id="recoveryModal" class="modal fade mt-perso" tabindex="-1" aria-labelledby="recoveryModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">

                <div class="modal-header">
                    <h5 class="modal-title" id="recoveryModalLabel">
                        Recovery
                    </h5>

                    <button
                        type="button"
                        class="btn-close"
                        data-bs-dismiss="modal"
                        aria-label="Close">
                    </button>
                </div>
                <cfoutput>
                <form action="dashboard.cfm?batch=#batchFilter##compareRedirect#" method="post">
                    <input type="hidden" name="submittedTab" class="js-current-tab" value="#encodeForHTMLAttribute(selectedTab)#">
                    <div class="modal-body">
                        <div class="mb-3">
                            <p class="m-0">Are you sure you want to recover this client?</p>
                            <span id="emailRecovery" class="fw-bold"></span>
                        </div>
                        <input type="text" id="emailRecoveryInput" name="emailRecoveryInput" hidden readonly>
                    </div>

                    <div class="modal-footer">
                        <button
                            type="button"
                            class="btn btn-secondary"
                            data-bs-dismiss="modal">
                            Close
                        </button>

                        <button
                            type="submit"
                            class="btn btn-success"
                            id="recoveryButton"
                            name="recoveryButton">
                            Recover
                        </button>
                    </div>
                </form>
                </cfoutput>
            </div>
        </div>
    </div>

    <script src="/PMSD/SATS/Timetracking/resources/bootstrap/bootstrap/js/bootstrap.bundle.min.js"></script>
    <script src="/PMSD/SATS/Timetracking/resources/js/dashboard.js"></script>
    
    <!--- Only load charts if there's data --->
    <cfif arrayLen(chartRows) GT 0>
        <script src="/PMSD/SATS/Timetracking/resources/js/charts.js"></script>
    </cfif>
</body>
</html>