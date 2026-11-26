<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<cfparam name="url.batch" default="0">
<cfparam name="url.page" default="1">
<cfparam name="url.tab" default="Active">

<cfset batchFilter = max(val(url.batch), 0)>
<cfset currentPage = max(val(url.page), 1)>
<cfset pageSize = 20>

<cfif compareNoCase(url.tab, "Deleted") EQ 0>
    <cfset selectedTab = "Deleted">
<cfelse>
    <cfset selectedTab = "Active">
</cfif>

<cfset startRow = ((currentPage - 1) * pageSize) + 1>

<cfset argsUnmatched = {
    batchFilter = batchFilter,
    startRow = startRow,
    pageSize = pageSize,
    tab = selectedTab
}>

<cfinvoke
    component="#application.query#"
    method="unmatchedPages"
    returnvariable="unmatchedResult"
    argumentcollection="#argsUnmatched#">

<!--- If the requested page became invalid, reload the last valid page. --->
<cfset totalUnmatchedEmail = val(unmatchedResult.totalItems)>
<cfset totalPages = max(ceiling(totalUnmatchedEmail / pageSize), 1)>

<cfif currentPage GT totalPages>
    <cfset currentPage = totalPages>
    <cfset startRow = ((currentPage - 1) * pageSize) + 1>
    <cfset argsUnmatched.startRow = startRow>

    <cfinvoke
        component="#application.query#"
        method="unmatchedPages"
        returnvariable="unmatchedResult"
        argumentcollection="#argsUnmatched#">
</cfif>

<cfinclude template="_unmatchedList.cfm">
