<cfcomponent output="false">
    <!--- Application settings --->
    <cfset this.name = "TimekeepingImportTool">
    <cfset this.applicationTimeout = createTimeSpan(0, 2, 0, 0)>
    <cfset this.sessionManagement = true>
    <cfset this.sessionTimeout = createTimeSpan(0, 0, 30, 0)>
    <cfset this.setClientCookies = true>
    
    <!--- Data sources - TWO DATABASES --->
    <cfset this.datasource = "PMSD_SATS">  <!--- Main application database --->
    
    <!--- File upload settings --->
    <cfset this.uploadDirectory = expandPath("./uploads")>
    <cfset this.exportDirectory = expandPath("./exports")>
    
    <cffunction name="onApplicationStart" returnType="boolean" output="false">
        <!--- Initialize application variables --->
        <cfset application.version = "1.0.0">
        <cfset application.appName = "Timekeeping Import & Analytics">
        
        <!--- Store datasource names --->
        <cfset application.mainDatasource = "PMSD_SATS">
        <cfset application.directoryDatasource = "PMSD_SATS">  <!--- Same server, different database --->
        
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
    
    <cffunction name="onRequestStart" returnType="boolean" output="false">
        <cfargument name="targetPage" type="string" required="true">
        
        <!--- Check if application needs to be reinitialized --->
        <cfif structKeyExists(url, "reinit") and url.reinit eq "true">
            <cfset onApplicationStart()>
        </cfif>
        
        <!--- Security headers --->
        <cfheader name="X-Frame-Options" value="SAMEORIGIN">
        <cfheader name="X-Content-Type-Options" value="nosniff">
        <cfheader name="X-XSS-Protection" value="1; mode=block">
        
        <cfreturn true>
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
            <!DOCTYPE html>
            <html>
            <head>
                <title>Error</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; }
                    .error-box { background: ##f8d7da; border: 1px solid ##f5c6cb; padding: 20px; border-radius: 5px; }
                    .error-box h2 { color: ##721c24; margin-top: 0; }
                    .error-detail { background: white; padding: 10px; margin-top: 10px; font-family: monospace; font-size: 12px; white-space: pre-wrap; }
                </style>
            </head>
            <body>
                <div class="error-box">
                    <h2>An Error Occurred</h2>
                    <p><strong>Type:</strong> #arguments.exception.type#</p>
                    <p><strong>Message:</strong> #arguments.exception.message#</p>
                    <cfif structKeyExists(arguments.exception, "detail") AND arguments.exception.detail NEQ "">
                        <div class="error-detail">
                            <strong>Detail:</strong>
                            #arguments.exception.detail#
                        </div>
                    </cfif>
                    <cfif structKeyExists(arguments.exception, "sql") AND arguments.exception.sql NEQ "">
                        <div class="error-detail">
                            <strong>SQL:</strong>
                            #arguments.exception.sql#
                        </div>
                    </cfif>
                    <cfif structKeyExists(arguments.exception, "queryError") AND arguments.exception.queryError NEQ "">
                        <div class="error-detail">
                            <strong>Query Error:</strong>
                            #arguments.exception.queryError#
                        </div>
                    </cfif>
                    <p style="margin-top: 20px;">
                        <a href="index.cfm">← Back to Home</a>
                    </p>
                </div>
            </body>
            </html>
        </cfoutput>
    </cffunction>
</cfcomponent>
