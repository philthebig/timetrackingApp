# Deployment Guide

## Pre-Deployment Checklist

- [ ] ColdFusion 2018+ or Lucee 5.3+ installed
- [ ] SQL Server 2016+ accessible
- [ ] Access to BRANCH_Directory.dbo.vUserInfo view
- [ ] Web server configured (IIS, Apache, or CF built-in)
- [ ] Database backup completed
- [ ] Admin credentials available

## Step 1: Database Setup

### 1.1 Connect to SQL Server

```bash
# Using SQL Server Management Studio (SSMS)
1. Open SSMS
2. Connect to your SQL Server instance
3. Select the appropriate database

# OR using command line
sqlcmd -S your_server_name -U your_username -P your_password
```

### 1.2 Verify vUserInfo Access

```sql
-- Test access to the view
SELECT TOP 10 * FROM [BRANCH_Directory].[dbo].[vUserInfo]
GO

-- Verify key columns exist
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'vUserInfo'
  AND COLUMN_NAME IN ('userID', 'firstName', 'lastName', 'DirectorateNameE', 'DivisionNameE')
GO
```

### 1.3 Execute SQL Scripts

Run scripts in this exact order:

```bash
# Option 1: Command line
sqlcmd -S your_server -d your_database -i sql/01_create_tables.sql
sqlcmd -S your_server -d your_database -i sql/02_create_stored_procedure.sql
sqlcmd -S your_server -d your_database -i sql/03_create_views.sql

# Option 2: SSMS
# Open each file and execute with F5
```

### 1.4 Verify Database Objects

```sql
-- Check tables
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN ('TimekeepingStaging', 'TimekeepingEnriched', 'ImportBatch', 'UnmatchedClients')
GO

-- Check stored procedure
SELECT ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME = 'sp_EnrichTimekeepingData'
GO

-- Check views
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_NAME LIKE 'vw_%'
GO
```

## Step 2: Application Deployment

### 2.1 File Deployment

Copy application files to web server:

```bash
# Windows (PowerShell)
Copy-Item -Path "timekeeping_app\*" -Destination "C:\inetpub\wwwroot\timekeeping\" -Recurse

# Linux/Mac
cp -r timekeeping_app/* /var/www/html/timekeeping/

# Or use FTP client like FileZilla
```

### 2.2 Create Required Directories

```bash
# Windows (Command Prompt)
mkdir C:\inetpub\wwwroot\timekeeping\uploads
mkdir C:\inetpub\wwwroot\timekeeping\exports
mkdir C:\inetpub\wwwroot\timekeeping\logs

# Linux/Mac
mkdir -p /var/www/html/timekeeping/uploads
mkdir -p /var/www/html/timekeeping/exports
mkdir -p /var/www/html/timekeeping/logs
```

### 2.3 Set Permissions

```bash
# Windows (PowerShell - run as Administrator)
$acl = Get-Acl "C:\inetpub\wwwroot\timekeeping\uploads"
$permission = "IIS_IUSRS","FullControl","ContainerInherit,ObjectInherit","None","Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.SetAccessRule($accessRule)
Set-Acl "C:\inetpub\wwwroot\timekeeping\uploads" $acl
Set-Acl "C:\inetpub\wwwroot\timekeeping\exports" $acl
Set-Acl "C:\inetpub\wwwroot\timekeeping\logs" $acl

# Linux/Mac
chmod 755 /var/www/html/timekeeping/uploads
chmod 755 /var/www/html/timekeeping/exports
chmod 755 /var/www/html/timekeeping/logs
chown -R www-data:www-data /var/www/html/timekeeping
```

## Step 3: ColdFusion Configuration

### 3.1 Create Datasource

1. Open ColdFusion Administrator
   - URL: `http://your-server:8500/CFIDE/administrator/`
   - Or: `http://your-server/CFIDE/administrator/`

2. Navigate to: **Data & Services > Data Sources**

3. Click **Add New Data Source**

4. Enter details:
   - **Data Source Name**: `TimekeepingDB` (or your chosen name)
   - **Driver**: Microsoft SQL Server

5. Click **Add**

6. Configure connection:
   ```
   Server: your_sql_server_name
   Port: 1433
   Database: your_database_name
   Username: your_db_username
   Password: your_db_password
   ```

7. Advanced Settings (recommended):
   - Enable **Use Unicode for data**
   - Set **Login Timeout**: 30 seconds
   - Set **Connection Timeout**: 60 seconds
   - Enable **Validate connection**

8. Click **Submit**

9. Test the connection using **Verify** button

### 3.2 Update Application Files

Edit `Application.cfc`:
```coldfusion
<!--- Line ~7 - Update datasource name --->
<cfset this.datasource = "TimekeepingDB">
```

Edit all `.cfm` files - Find and replace:
```coldfusion
datasource="yourDatasource"
↓
datasource="TimekeepingDB"
```

Files to update:
- `cfm/index.cfm`
- `cfm/dashboard.cfm`
- `cfm/export.cfm`
- `cfm/api.cfm`

### 3.3 Configure Application Settings

Copy and edit configuration:
```bash
cp config.template.cfm config.cfm
```

Edit `config.cfm` with your settings.

## Step 4: Web Server Configuration

### 4.1 IIS Configuration

1. Open IIS Manager
2. Add new application:
   - Right-click on Default Web Site
   - Add Application
   - Alias: `timekeeping`
   - Physical path: `C:\inetpub\wwwroot\timekeeping\cfm`

3. Set default document:
   - Select your application
   - Open Default Document
   - Add: `index.cfm`

4. Configure application pool:
   - Select Application Pools
   - Create new pool: `TimekeepingAppPool`
   - .NET CLR version: No Managed Code
   - Assign pool to your application

### 4.2 Apache Configuration

Add to httpd.conf or create virtual host:

```apache
<VirtualHost *:80>
    ServerName timekeeping.yourdomain.com
    DocumentRoot "/var/www/html/timekeeping/cfm"
    
    <Directory "/var/www/html/timekeeping/cfm">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    DirectoryIndex index.cfm
    
    # ColdFusion connector
    JkMount /*.cfm cfusion
    JkMount /*.cfc cfusion
</VirtualHost>
```

Restart Apache:
```bash
sudo systemctl restart apache2
# OR
sudo service httpd restart
```

## Step 5: Testing

### 5.1 Basic Connectivity Test

1. Navigate to: `http://your-server/timekeeping/`
2. Verify page loads without errors
3. Check browser console for JavaScript errors

### 5.2 Database Connection Test

Create test file `cfm/dbtest.cfm`:

```coldfusion
<cftry>
    <cfquery name="test" datasource="TimekeepingDB">
        SELECT TOP 5 * FROM [BRANCH_Directory].[dbo].[vUserInfo]
    </cfquery>
    
    <cfoutput>
        <h3>Database Connection: SUCCESS</h3>
        <p>Records found: #test.recordCount#</p>
    </cfoutput>
    
    <cfcatch type="any">
        <cfoutput>
            <h3>Database Connection: FAILED</h3>
            <p>Error: #cfcatch.message#</p>
            <p>Detail: #cfcatch.detail#</p>
        </cfoutput>
    </cfcatch>
</cftry>
```

Access: `http://your-server/timekeeping/dbtest.cfm`

### 5.3 Upload Test

1. Prepare small test Excel file
2. Navigate to upload page
3. Select file and upload
4. Verify processing completes
5. Check batch record in database:

```sql
SELECT * FROM dbo.ImportBatch ORDER BY ImportDate DESC
```

### 5.4 Dashboard Test

1. Navigate to dashboard
2. Verify all statistics display
3. Check that charts render
4. Test export buttons

### 5.5 API Endpoint Test

Test API: `http://your-server/timekeeping/api.cfm?action=getDashboardStats`

Should return JSON response.

## Step 6: Security Hardening

### 6.1 Restrict CF Admin Access

```xml
<!-- Add to web.config (IIS) or .htaccess (Apache) -->
<location path="CFIDE/administrator">
    <system.webServer>
        <security>
            <ipSecurity allowUnlisted="false">
                <add ipAddress="127.0.0.1" allowed="true"/>
                <add ipAddress="your_admin_ip" allowed="true"/>
            </ipSecurity>
        </security>
    </system.webServer>
</location>
```

### 6.2 Enable HTTPS

1. Obtain SSL certificate
2. Configure in IIS or Apache
3. Update Application.cfc:
```coldfusion
<cfset config.enforceHTTPS = true>
```

### 6.3 Database Security

```sql
-- Create dedicated database user
CREATE LOGIN timekeeping_app WITH PASSWORD = 'strong_password_here';
GO

USE your_database;
GO

CREATE USER timekeeping_app FOR LOGIN timekeeping_app;
GO

-- Grant minimum required permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.TimekeepingStaging TO timekeeping_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.TimekeepingEnriched TO timekeeping_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.ImportBatch TO timekeeping_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.UnmatchedClients TO timekeeping_app;
GRANT SELECT ON [BRANCH_Directory].[dbo].[vUserInfo] TO timekeeping_app;
GRANT EXECUTE ON dbo.sp_EnrichTimekeepingData TO timekeeping_app;
GO
```

Update datasource to use this dedicated user.

## Step 7: Monitoring & Maintenance

### 7.1 Setup Log Rotation

Windows (Task Scheduler):
```powershell
# Create cleanup script: cleanup_logs.ps1
Get-ChildItem -Path "C:\inetpub\wwwroot\timekeeping\logs" -Recurse -File |
    Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-90)} |
    Remove-Item -Force
```

Linux (cron):
```bash
# Add to crontab
0 2 * * 0 find /var/www/html/timekeeping/logs -type f -mtime +90 -delete
0 2 * * 0 find /var/www/html/timekeeping/uploads -type f -mtime +7 -delete
```

### 7.2 Database Maintenance

```sql
-- Create maintenance job (SQL Server Agent)
-- Run weekly to update statistics and rebuild indexes

USE your_database;
GO

-- Update statistics
UPDATE STATISTICS dbo.TimekeepingEnriched;
UPDATE STATISTICS dbo.ImportBatch;
GO

-- Rebuild indexes if fragmented
ALTER INDEX ALL ON dbo.TimekeepingEnriched REBUILD;
GO
```

### 7.3 Backup Strategy

```sql
-- Daily backup script
BACKUP DATABASE your_database
TO DISK = 'D:\Backups\timekeeping_' + CONVERT(VARCHAR, GETDATE(), 112) + '.bak'
WITH COMPRESSION, INIT;
GO
```

## Troubleshooting

### Issue: "Datasource not found"
**Solution**: 
1. Verify datasource name in CF Admin matches code
2. Restart ColdFusion service
3. Check CF Admin logs

### Issue: "Access denied" on upload
**Solution**:
1. Verify folder permissions
2. Check IIS/Apache user has write access
3. Test with full path in Application.cfc

### Issue: Charts not displaying
**Solution**:
1. Check browser console for errors
2. Verify Chart.js CDN accessible
3. Test with simple static chart

### Issue: Slow processing
**Solution**:
1. Increase CF request timeout
2. Add database indexes
3. Check SQL Server performance
4. Consider batch size reduction

## Rollback Procedure

If deployment fails:

1. **Database Rollback**:
```sql
DROP TABLE IF EXISTS dbo.TimekeepingStaging;
DROP TABLE IF EXISTS dbo.TimekeepingEnriched;
DROP TABLE IF EXISTS dbo.UnmatchedClients;
DROP TABLE IF EXISTS dbo.ImportBatch;
DROP PROCEDURE IF EXISTS dbo.sp_EnrichTimekeepingData;
-- Restore from backup if needed
```

2. **Application Rollback**:
```bash
# Remove application files
rm -rf /path/to/timekeeping/
# Restore previous version from backup
```

3. **ColdFusion Rollback**:
- Remove datasource from CF Admin
- Clear template cache
- Restart ColdFusion

## Post-Deployment

- [ ] Document actual server URLs
- [ ] Train users on interface
- [ ] Create admin guide
- [ ] Setup monitoring alerts
- [ ] Schedule first backup
- [ ] Review security logs
- [ ] Test disaster recovery

## Support Contacts

- **Database Admin**: [email]
- **System Admin**: [email]
- **Developer**: [email]
- **End User Support**: [email]

---

**Deployment Date**: __________
**Deployed By**: __________
**Verified By**: __________
