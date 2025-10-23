/* ================================================
   CONFIGURATION TEMPLATE
   Copy this to config.cfm and update with your settings
   ================================================ */

<!--- Database Configuration --->
<cfset config.datasourceName = "yourDatasource">
<cfset config.databaseServer = "your_sql_server">
<cfset config.databaseName = "your_database">
<cfset config.databaseSchema = "BRANCH_Directory">

<!--- Directory Configuration --->
<cfset config.uploadDirectory = expandPath("./uploads")>
<cfset config.exportDirectory = expandPath("./exports")>
<cfset config.maxFileSize = 10485760> <!--- 10MB in bytes --->

<!--- Application Settings --->
<cfset config.allowedFileExtensions = "xlsx,xls">
<cfset config.sessionTimeout = 30> <!--- minutes --->
<cfset config.requestTimeout = 300> <!--- seconds --->
<cfset config.enableDebugMode = false>

<!--- Email Notification Settings (Optional) --->
<cfset config.enableEmailNotifications = false>
<cfset config.adminEmail = "admin@example.com">
<cfset config.emailFrom = "timekeeping@example.com">
<cfset config.emailServer = "mail.example.com">

<!--- Processing Settings --->
<cfset config.batchProcessingSize = 1000>
<cfset config.retainUploadedFileDays = 7>
<cfset config.retainExportFileDays = 30>

<!--- UI Settings --->
<cfset config.appTitle = "Timekeeping Import & Analytics">
<cfset config.defaultLanguage = "en"> <!--- en or fr --->
<cfset config.dateFormat = "yyyy-mm-dd">
<cfset config.timeFormat = "HH:mm">

<!--- Chart Settings --->
<cfset config.chartColors = [
    "rgba(54, 162, 235, 0.7)",
    "rgba(255, 99, 132, 0.7)",
    "rgba(255, 206, 86, 0.7)",
    "rgba(75, 192, 192, 0.7)",
    "rgba(153, 102, 255, 0.7)",
    "rgba(255, 159, 64, 0.7)",
    "rgba(199, 199, 199, 0.7)",
    "rgba(83, 102, 255, 0.7)",
    "rgba(255, 99, 255, 0.7)",
    "rgba(99, 255, 132, 0.7)"
]>

<!--- Dashboard Settings --->
<cfset config.topClientsLimit = 10>
<cfset config.topDirectoratesLimit = 10>
<cfset config.topCategoriesLimit = 10>

<!--- Export Settings --->
<cfset config.exportSheetName = "Timekeeping Data">
<cfset config.exportHeaderColor = "light_blue">
<cfset config.exportColumnWidth = 20>

<!--- Security Settings --->
<cfset config.enableCSRFProtection = true>
<cfset config.enforceHTTPS = false>
<cfset config.allowedIpAddresses = ""> <!--- Comma-separated list, empty for all --->

<!--- Logging Settings --->
<cfset config.enableAccessLog = true>
<cfset config.enableErrorLog = true>
<cfset config.logDirectory = expandPath("./logs")>
<cfset config.logRetentionDays = 90>

<!--- Feature Flags --->
<cfset config.features.enableEmailMatching = true>
<cfset config.features.enableNameMatching = true>
<cfset config.features.enableAutoRefresh = false>
<cfset config.features.enableDataExport = true>
<cfset config.features.enableBatchComparison = true>

<!--- Validation Rules --->
<cfset config.validation.requireImportedByField = false>
<cfset config.validation.requireNotesField = false>
<cfset config.validation.validateEmailFormat = true>
<cfset config.validation.validateHoursFormat = true>

<!--- Performance Settings --->
<cfset config.performance.enableCaching = true>
<cfset config.performance.cacheTimeout = 30> <!--- minutes --->
<cfset config.performance.maxConcurrentUploads = 5>
<cfset config.performance.enableQueryOptimization = true>

/* ================================================
   NOTES:
   
   1. Copy this file to config.cfm before use
   2. Update all "your_" placeholder values
   3. Keep config.cfm out of version control
   4. Restart ColdFusion after configuration changes
   5. Test database connectivity after setup
   
   ================================================ */
