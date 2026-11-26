<cfset unmatched = unmatchedResult.items>
<cfset totalUnmatchedEmail = val(unmatchedResult.totalItems)>
<cfset totalUnmatchedRows = val(unmatchedResult.totalRows)>
<cfset totalPages = max(ceiling(totalUnmatchedEmail / pageSize), 1)>
<cfset currentPage = min(max(currentPage, 1), totalPages)>
<cfset startRow = ((currentPage - 1) * pageSize) + 1>

<div id="unmatchedResultContent"
     data-tab="<cfoutput>#encodeForHTMLAttribute(selectedTab)#</cfoutput>"
     data-page="<cfoutput>#currentPage#</cfoutput>">

    <cfif totalUnmatchedEmail GT 0>
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header bg-warning text-dark d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">
                            <i class="fas fa-exclamation-triangle"></i>
                            <cfif selectedTab EQ "Active">
                                Active Unmatched Clients
                            <cfelse>
                                Deleted Unmatched Clients
                            </cfif>
                        </h5>
                        <span class="badge bg-dark">
                            <cfoutput>#totalUnmatchedRows# records,#numberFormat(totalUnmatchedEmail)# clients</cfoutput>
                        </span>
                    </div>

                    <div class="card-body">
                        <div class="alert alert-info">
                            <i class="fas fa-info-circle"></i>
                            <cfif selectedTab EQ "Active">
                                These active clients could not be matched with the directory.
                            <cfelse>
                                These clients are currently marked as deleted.
                            </cfif>
                        </div>

                        <cfif selectedTab EQ "Active">
                            <div class="text-center mb-3">
                                <cfoutput>
                                    <a href="export.cfm?type=unmatched&batch=#batchFilter#&tab=#encodeForURL(selectedTab)#"
                                    class="btn btn-warning btn-lg">
                                        <i class="fas fa-download"></i>
                                        Export Unmatched (#totalUnmatchedRows#)
                                    </a>
                                </cfoutput>
                            </div>
                        </cfif> 
                        
                        <div class="table-responsive">
                            <table class="table table-striped align-middle">
                                <thead>
                                    <tr>
                                        <th>Email</th>
                                        <th>Full Contact Info</th>
                                        <th>Hours</th>
                                        <th>Error Message</th>
                                        <cfif batchFilter GT 0>
                                            <th>Actions</th>
                                        </cfif>
                                    </tr>
                                </thead>
                                <tbody>
                                    <cfloop collection="#unmatched#" item="email">
                                        <cfset client = unmatched[email]>
                                        <cfoutput>
                                            <tr>
                                                <td>
                                                    #encodeForHTML(email)#
                                                    (#val(client.occurrences)#)
                                                </td>
                                                <td>
                                                    <small>#encodeForHTML(client.clientContact)#</small>
                                                </td>
                                                <td>#numberFormat(client.hours, "999.99")#</td>
                                                <td>#encodeForHTML(client.errorMessage)#</td>

                                                <cfif batchFilter GT 0>
                                                    <td>
                                                        <cfif selectedTab EQ "Active">
                                                            <div class="d-flex flex-row gap-1">
                                                                <button
                                                                    type="button"
                                                                    class="btn btn-sm btn-outline-primary"
                                                                    title="Edit email"
                                                                    data-bs-toggle="modal"
                                                                    data-bs-target="##editModal"
                                                                    data-email="#encodeForHTMLAttribute(email)#">
                                                                    <i class="fas fa-pen-to-square"></i>
                                                                </button>

                                                                <button
                                                                    type="button"
                                                                    class="btn btn-sm btn-outline-warning"
                                                                    title="Forced addition"
                                                                    data-bs-toggle="modal"
                                                                    data-bs-target="##forceAddModal"
                                                                    data-email="#encodeForHTMLAttribute(email)#">
                                                                    <i class="fas fa-plus"></i>
                                                                </button>

                                                                <button
                                                                    type="button"
                                                                    class="btn btn-sm btn-outline-danger"
                                                                    title="Delete"
                                                                    data-bs-toggle="modal"
                                                                    data-bs-target="##deleteModal"
                                                                    data-email="#encodeForHTMLAttribute(email)#">
                                                                    <i class="fas fa-trash"></i>
                                                                </button>
                                                            </div>
                                                        <cfelse>
                                                            <button
                                                                type="button"
                                                                class="btn btn-sm btn-outline-success"
                                                                title="Client recovery"
                                                                data-bs-toggle="modal"
                                                                data-bs-target="##recoveryModal"
                                                                data-email="#encodeForHTMLAttribute(email)#">
                                                                <i class="fas fa-rotate-left"></i>
                                                            </button>
                                                        </cfif>
                                                    </td>
                                                </cfif>
                                            </tr>
                                        </cfoutput>
                                    </cfloop>
                                </tbody>
                            </table>
                        </div>

                        <cfif totalPages GT 1>
                            <nav aria-label="Unmatched clients pagination">
                                <ul class="pagination justify-content-center">
                                    <li class="page-item<cfif currentPage EQ 1> disabled</cfif>">
                                        <button
                                            type="button"
                                            class="page-link js-unmatched-page"
                                            data-page="<cfoutput>#max(currentPage - 1, 1)#</cfoutput>"
                                            <cfif currentPage EQ 1>disabled</cfif>>
                                            <i class="fas fa-chevron-left"></i> Previous
                                        </button>
                                    </li>

                                    <cfloop from="1" to="#totalPages#" index="p">
                                        <cfif p EQ currentPage>
                                            <li class="page-item active">
                                                <span class="page-link"><cfoutput>#p#</cfoutput></span>
                                            </li>
                                        <cfelseif abs(p - currentPage) LT 3 OR p EQ 1 OR p EQ totalPages>
                                            <li class="page-item">
                                                <button
                                                    type="button"
                                                    class="page-link js-unmatched-page"
                                                    data-page="<cfoutput>#p#</cfoutput>">
                                                    <cfoutput>#p#</cfoutput>
                                                </button>
                                            </li>
                                        <cfelseif abs(p - currentPage) EQ 3>
                                            <li class="page-item disabled">
                                                <span class="page-link">...</span>
                                            </li>
                                        </cfif>
                                    </cfloop>

                                    <li class="page-item<cfif currentPage EQ totalPages> disabled</cfif>">
                                        <button
                                            type="button"
                                            class="page-link js-unmatched-page"
                                            data-page="<cfoutput>#min(currentPage + 1, totalPages)#</cfoutput>"
                                            <cfif currentPage EQ totalPages>disabled</cfif>>
                                            Next <i class="fas fa-chevron-right"></i>
                                        </button>
                                    </li>
                                </ul>
                            </nav>
                        </cfif>

                        <cfoutput>
                            <cfoutput>
                                <p class="text-center text-muted mb-0">
                                    Showing grouped clients
                                    #startRow# -
                                    #min(
                                        startRow + pageSize - 1,
                                        totalUnmatchedEmail
                                    )#
                                    of #numberFormat(totalUnmatchedEmail)#
                                    <span class="ms-1">
                                        (#numberFormat(totalUnmatchedRows)#
                                        individual records)
                                    </span>
                                    <br>
                                    Page #currentPage# of #totalPages#
                                </p>
                            </cfoutput>
                        </cfoutput>
                    </div>
                </div>
            </div>
        </div>
    <cfelse>
        <div class="alert alert-info">
            <i class="fas fa-info-circle"></i>
            <cfif selectedTab EQ "Active">
                No active unmatched clients were found.
            <cfelse>
                No deleted unmatched clients were found.
            </cfif>
        </div>
    </cfif>
</div>
