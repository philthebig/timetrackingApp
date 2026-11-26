<cfparam name="url.batch" default="0">
<cfparam name="url.page" default="1">
<cfparam name="url.tab" default="Active">

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
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=#encodeForURL(selectedTab)#&emailUpdated=1" addtoken="false">
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
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=Deleted&deleted=1" addtoken="false">
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
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=Active&added=1" addtoken="false">
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
        <cflocation url="dashboard.cfm?batch=#batchFilter#&tab=Active&recovered=1" addtoken="false">
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
        
        <!--- Statistics Query --->
        <cfinvoke component="#application.query#" method="stats" returnvariable="statistics" argumentcollection="#args#">
        
        <!--- Directorate breakdown --->
        <cfinvoke component="#application.query#" method="directorateStats" returnvariable="directorate" argumentcollection="#args#">
        <cfinvoke component="#application.query#" method="getDirectorates" returnvariable="directorates">

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
        <cfloop query="directorate">
            <cfset arrayAppend(chartLabels, Directorate)>
            <cfset arrayAppend(chartData, TotalHours)>
        </cfloop>
        <script>
            const chartLabels = <cfoutput>#serializeJSON(chartLabels)#</cfoutput>;
            const chartValues = <cfoutput>#serializeJSON(chartData)#</cfoutput>;
        </script>

        <!--- Header with batch info --->
        <div class="row mb-4">
            <div class="col-md-8">
                <cfif batchFilter GT 0 AND isDefined("info") AND info.recordCount GT 0>
                    <cfoutput>
                    <h2 class="align-items-center d-flex gap-3"><div><i class="fas fa-filter"></i> Batch Details</div>
                        <span class="badge bg-<cfif info.ProcessingStatus EQ 'Completed'>success<cfelseif info.ProcessingStatus EQ 'Processing'>warning<cfelse>danger</cfif>">
                            #info.ProcessingStatus#
                        </span>
                    </h2>
                    <p class="text-muted mb-0">
                    Viewing: <strong>#info.FileName#</strong> 
                    (Imported: #dateFormat(info.ImportDate, "mmm d, yyyy")#)
                    </p>
                    </cfoutput>
                <cfelse>
                    <h2><i class="fas fa-chart-line"></i> All Batches Overview</h2>
                    <p class="text-muted mb-0">Aggregate view of all imported timekeeping data</p>
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
        </cfif>

        <!--- Statistics Cards --->
        <div class="row mb-4 justify-content-between">
            <div class="col-md-2">
                <div class="card text-white bg-primary">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-database"></i> Total Records</h5>
                        <cfoutput><h2>#numberFormat(statistics.dashTotalRecords)#</h2></cfoutput>
                    </div>
                </div>
            </div>
            <div class="col-md-2">
                <div class="card text-white bg-success" >
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-check"></i> Matched </h5>
                        <cfoutput><h2>#numberFormat(statistics.dashMatchedRecords)#</h2></cfoutput>
                    </div>
                </div>
            </div>
            <div class="col-md-2">
                <div class="card text-white bg-warning">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-exclamation-triangle"></i> Unmatched</h5>
                        <cfoutput><h2>#numberFormat(statistics.dashUnmatchedRecords)#</h2></cfoutput>
                    </div>
                </div>
            </div>
            <div class="col-md-2">
                <div class="card text-white bg-skipped">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-forward"></i> Skipped</h5>
                        <cfoutput><h2>#numberFormat(statistics.dashSkippedRecords)#</h2></cfoutput>
                    </div>
                </div>
            </div>
            <div class="col-md-2">
                <div class="card text-white bg-info">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-percent"></i> Rate</h5>
                        <cfoutput><h2>#numberFormat(statistics.matchRate, "99.9")#%</h2></cfoutput>
                    </div>
                </div>
            </div>
            <div class="col-md-2">
                <div class="card text-white bg-hours">
                    <div class="card-body">
                        <h5 class="card-title"><i class="fas fa-clock"></i> Total Hours</h5>
                        <cfoutput><h2>#numberFormat(statistics.dashTotalHours, "999,999.99")#</h2></cfoutput>
                    </div>
                </div>
            </div>
        </div>
        
        <!--- Charts Row --->
        <cfif directorate.recordCount GT 0>
            <div class="row mb-4">
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header bg-primary text-white">
                            <h5><i class="fas fa-chart-bar"></i> Hours by Directorate</h5>
                        </div>
                        <div class="card-body">
                            <canvas id="directorateChart" height="300"></canvas>
                        </div>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="card">
                        <div class="card-header bg-primary text-white">
                            <h5><i class="fas fa-chart-pie"></i> Distribution</h5>
                        </div>
                        <div class="card-body">
                            <canvas id="distributionChart" height="300"></canvas>
                        </div>
                    </div>
                </div>
            </div>
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
                <form action="dashboard.cfm?batch=#batchFilter#" method="post">
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
                <form action="dashboard.cfm?batch=#batchFilter#" method="post">
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
                <form action="dashboard.cfm?batch=#batchFilter#" method="post">
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
                <form action="dashboard.cfm?batch=#batchFilter#" method="post">
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
    <cfif directorate.recordCount GT 0>
        <script src="/PMSD/SATS/Timetracking/resources/js/charts.js"></script>
    </cfif>
</body>
</html>