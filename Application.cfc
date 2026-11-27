<cfcomponent output="false">
    <!--- Application settings --->
    <cfinclude template="/REFERENCES/CF_INITAPP/initapp.cfm">
    <cfset this.name = "TimekeepingImportTool">
    <cfset this.applicationTimeout = createTimeSpan(0, 2, 0, 0)>
    <cfset this.sessionManagement = true>
    <cfset this.sessionTimeout = createTimeSpan(0, 0, 30, 0)>
    <cfset this.setClientCookies = true>
    <cfset variables.env = getEnv()>
    <cfset This.sessionManagement = "Yes">
    <cfscript>
		this.serialization.preserveCaseForStructKey = true;
	</cfscript>
    
    <!--- Data sources - TWO DATABASES --->
    <cfset this.datasource = "PMSD_SATS">  <!--- Main application database --->
    
    <!--- File upload settings --->
    <cfset this.uploadDirectory = expandPath("./uploads")>
    <cfset this.exportDirectory = expandPath("./exports")>
    
    <cffunction name="onApplicationStart" returnType="boolean">
        <!--- Initialize application variables --->
        <cfset application.env = variables.env>
        <cfset application.version = "1.0.0">
        <cfset application.appName = "Timekeeping Import & Analytics">
        <cfset Application.Path = "http://#cgi.server_name#/PMSD/SATS/Timetracking/cfm/">
        
        <!--- Store datasource names --->
        <cfset application.mainDatasource = "PMSD_SATS">
        <cfset application.directoryDatasource = "PMSD_SATS">  <!--- Same server, different database --->
        <cfset application.branchDatasource = "BRANCH_Directory">
        <cfset application.query = new services.query()>
        
        <!--- Create required directories --->
        <cfif not directoryExists(this.uploadDirectory)>
            <cfdirectory action="create" directory="#this.uploadDirectory#">
        </cfif>
        
        <cfif not directoryExists(this.exportDirectory)>
            <cfdirectory action="create" directory="#this.exportDirectory#">
        </cfif>
        
        <!--- Set application started flag --->
        <cfset application.started = now()>
        
        <cfreturn true>
    </cffunction>
    
    <cffunction name="onRequestStart" returnType="boolean">
        <cfargument name="targetPage" type="string" required="true">

        <cfif IsDefined("url.Reset")>
            <cftry>
                <cfset onApplicationStart()>
                <cfset onSessionStart()>
                <cfset q = reReplaceNoCase(cgi.query_string, "Reset", "", "all")>
                <cflocation url="#cgi.SCRIPT_NAME#?#q#" addtoken="no">
                <cfcatch type="any">
                    <cfoutput>
                        <h2>The application could not restart</h2>
                        <p><strong>Message:</strong> #encodeForHTML(cfcatch.message)#</p>
                        <cfif structKeyExists(cfcatch, "detail") AND isSimpleValue(cfcatch.detail) AND len(cfcatch.detail)>
                            <p><strong>Detail:</strong> #encodeForHTML(cfcatch.detail)#</p>
                        </cfif>
                    </cfoutput>
                    <cfdump var="#cfcatch#">
                    <cfabort>
                </cfcatch>
            </cftry>
		</cfif>

        <cfif NOT structKeyExists(session, "pAccess")>
            <cfset session.pAccess = 0>
        </cfif>

        <cfif structKeyExists(session, "user_id") AND Len(Trim(session.user_id))>
            <cfquery datasource="#application.mainDatasource#" name="local.qryAccess">
                SELECT UserId
                FROM TimeKeepingAdminUser
                WHERE LOWER(UserId) = LOWER(<cfqueryparam value="#Trim(session.user_id)#" cfsqltype="cf_sql_varchar">)
            </cfquery>
            <cfset session.pAccess = (local.qryAccess.recordCount GT 0)>
        </cfif>

        <cfset local.isAccessDeniedPage = structKeyExists(url, "page") AND CompareNoCase(url.page, "AccessDenied") EQ 0>
        
        <cfif NOT session.pAccess AND NOT local.isAccessDeniedPage>
            <cflocation url="index.cfm?page=AccessDenied" addtoken="no">
        </cfif>

        <cfif IsDefined("url.loginas")>
			<cfset onSessionStart()>
        </cfif>
        <cfif NOT StructKeyExists(session, "user_id")>
            <cfset onSessionStart()>
        </cfif>
        
        <!--- Security headers --->
        <cfheader name="X-Frame-Options" value="SAMEORIGIN">
        <cfheader name="X-Content-Type-Options" value="nosniff">
        <cfheader name="X-XSS-Protection" value="1; mode=block">
        
        <cfreturn true>
    </cffunction>

    <cffunction name="onRequestEnd" returntype="void">
		<cfargument name="targetPage" type="string" required="yes">
		<!--- * Insert Code Here * --->
		
	</cffunction>
    
    <cffunction name="onError" returnType="void" output="true">
        <cfargument name="exception" required="true">
        <cfargument name="eventName" type="string" required="true">
        
        <!--- Log error --->
        <cflog file="timekeeping_errors" 
               type="error" 
               text="Error in #arguments.eventName#: #arguments.exception.message#">
        
        <!--- Display friendly error message --->
        <cfoutput>
            <div style="background: ##f8d7da; border: 1px solid ##f5c6cb; padding: 20px; border-radius: 5px;">
                <h2>An Error Occurred</h2>
                <p><strong>Type:</strong> #arguments.exception.type#</p>
                <p><strong>Message:</strong> #arguments.exception.message#</p>
                <cfif structKeyExists(arguments.exception, "detail") AND arguments.exception.detail NEQ "">
                    <div style="background: white; padding: 10px; margin-top: 10px; font-family: monospace; font-size: 12px; white-space: pre-wrap;">
                        <strong>Detail:</strong>
                        #arguments.exception.detail#
                    </div>
                </cfif>
                <cfif structKeyExists(arguments.exception, "sql") AND arguments.exception.sql NEQ "">
                    <div style="background: white; padding: 10px; margin-top: 10px; font-family: monospace; font-size: 12px; white-space: pre-wrap;">
                        <strong>SQL:</strong>
                        #arguments.exception.sql#
                    </div>
                </cfif>
                <cfif structKeyExists(arguments.exception, "queryError") AND arguments.exception.queryError NEQ "">
                    <div style="background: white; padding: 10px; margin-top: 10px; font-family: monospace; font-size: 12px; white-space: pre-wrap;">
                        <strong>Query Error:</strong>
                        #arguments.exception.queryError#
                    </div>
                </cfif>
                <p style="margin-top: 20px;">
                    <a href="index.cfm">Back to Home</a>
                </p>
            </div>
        </cfoutput>
    </cffunction>

    <cffunction name="onSessionStart" returntype="void">
        <cfif NOT structKeyExists(session, "pAccess")>
            <cfset session.pAccess = 0>
        </cfif>

        <cfif IsDefined("url.loginas") AND listfindnocase('vxb608,jxb928,pxa055,dxr134,cxc786', ListLast(cgi.REMOTE_USER, "\"))>
                <cfset session.user_id = url.loginas>
            <cfelse>
                <cfset session.user_id = ListLast(cgi.REMOTE_USER, "\")>
        </cfif>

        <cfif structKeyExists(session, "user_id") AND Len(Trim(session.user_id))>
            <cfquery datasource="#application.mainDatasource#" name="local.qryAccess">
                SELECT UserId
                FROM TimeKeepingAdminUser
                WHERE LOWER(UserId) = LOWER(<cfqueryparam value="#Trim(session.user_id)#" cfsqltype="cf_sql_varchar">)
            </cfquery>
            <cfset session.pAccess = (local.qryAccess.recordCount GT 0)>
        </cfif>
    </cffunction>
</cfcomponent>