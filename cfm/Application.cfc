<cfcomponent output="false">
    <!--- Application settings --->
    <cfset this.name = "TimekeepingImportTool">
    <cfset this.applicationTimeout = createTimeSpan(0, 2, 0, 0)>
    <cfset this.sessionManagement = true>
    <cfset this.sessionTimeout = createTimeSpan(0, 0, 30, 0)>
    <cfset this.setClientCookies = true>
    
    <!--- Data source --->
    <cfset this.datasource = "yourDatasource">
    
    <!--- Character encoding --->
    <cfset this.charset.web = "utf-8">
    <cfset this.charset.resource = "utf-8">
    
    <!--- Error handling --->
    <cfset this.errorTemplate = "error.cfm">
    
    <!--- Application mappings --->
    <cfset this.mappings["/timekeeping"] = getDirectoryFromPath(getCurrentTemplatePath())>
    
    <!--- File upload settings --->
    <cfset this.uploadDirectory = expandPath("./uploads")>
    <cfset this.exportDirectory = expandPath("./exports")>
    
    <cffunction name="onApplicationStart" returnType="boolean" output="false">
        <!--- Initialize application variables --->
        <cfset application.version = "1.0.0">
        <cfset application.appName = "Timekeeping Import & Analytics">
        
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
    
    <cffunction name="onSessionStart" returnType="void" output="false">
        <!--- Initialize session variables --->
        <cfset session.started = now()>
        <cfset session.lastActivity = now()>
    </cffunction>
    
    <cffunction name="onRequestStart" returnType="boolean" output="false">
        <cfargument name="targetPage" type="string" required="true">
        
        <!--- Check if application needs to be reinitialized --->
        <cfif structKeyExists(url, "reinit") and url.reinit eq "true">
            <cfset onApplicationStart()>
        </cfif>
        
        <!--- Update last activity --->
        <cfif structKeyExists(session, "lastActivity")>
            <cfset session.lastActivity = now()>
        </cfif>
        
        <!--- Security headers --->
        <cfheader name="X-Frame-Options" value="SAMEORIGIN">
        <cfheader name="X-Content-Type-Options" value="nosniff">
        <cfheader name="X-XSS-Protection" value="1; mode=block">
        
        <!--- Set content type --->
        <cfcontent type="text/html; charset=UTF-8">
        
        <cfreturn true>
    </cffunction>
    
    <cffunction name="onRequest" returnType="void" output="true">
        <cfargument name="targetPage" type="string" required="true">
        
        <!--- Include the requested page --->
        <cfinclude template="#arguments.targetPage#">
    </cffunction>
    
    <cffunction name="onError" returnType="void" output="true">
        <cfargument name="exception" required="true">
        <cfargument name="eventName" type="string" required="true">
        
        <!--- Log error --->
        <cflog file="timekeeping_errors" 
               type="error" 
               text="Error in #arguments.eventName#: #arguments.exception.message# - #arguments.exception.detail#">
        
        <!--- Display friendly error message --->
        <cfoutput>
            <div class="alert alert-danger">
                <h4>An Error Occurred</h4>
                <p><strong>Type:</strong> #arguments.exception.type#</p>
                <p><strong>Message:</strong> #arguments.exception.message#</p>
                <cfif structKeyExists(arguments.exception, "detail")>
                    <p><strong>Detail:</strong> #arguments.exception.detail#</p>
                </cfif>
                <p>Please contact the system administrator if this problem persists.</p>
            </div>
        </cfoutput>
    </cffunction>
    
    <cffunction name="onSessionEnd" returnType="void" output="false">
        <cfargument name="sessionScope" type="struct" required="true">
        <cfargument name="applicationScope" type="struct" required="false">
        
        <!--- Cleanup session-specific resources if needed --->
    </cffunction>
    
    <cffunction name="onApplicationEnd" returnType="void" output="false">
        <cfargument name="applicationScope" type="struct" required="true">
        
        <!--- Cleanup application resources --->
        <!--- Clean up old uploaded files --->
        <cftry>
            <cfdirectory action="list" 
                        directory="#this.uploadDirectory#" 
                        name="oldFiles" 
                        filter="*.xlsx|*.xls">
            
            <cfloop query="oldFiles">
                <!--- Delete files older than 7 days --->
                <cfif dateDiff("d", oldFiles.dateLastModified, now()) GT 7>
                    <cffile action="delete" 
                           file="#this.uploadDirectory#/#oldFiles.name#">
                </cfif>
            </cfloop>
            
            <cfcatch type="any">
                <!--- Log cleanup error but don't throw --->
                <cflog file="timekeeping_cleanup" 
                       type="warning" 
                       text="Error cleaning up old files: #cfcatch.message#">
            </cfcatch>
        </cftry>
    </cffunction>
</cfcomponent>
