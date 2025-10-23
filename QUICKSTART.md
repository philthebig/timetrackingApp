# Quick Start Guide

Get up and running in 15 minutes!

## Prerequisites ✓
- [ ] ColdFusion 2018+ installed
- [ ] SQL Server with BRANCH_Directory.dbo.vUserInfo access
- [ ] Database backup completed

## 5-Minute Database Setup

1. **Run SQL scripts** (in order):
```bash
sqlcmd -S your_server -d your_database -i sql/01_create_tables.sql
sqlcmd -S your_server -d your_database -i sql/02_create_stored_procedure.sql
sqlcmd -S your_server -d your_database -i sql/03_create_views.sql
```

2. **Verify**:
```sql
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE 'Timekeeping%'
```

## 5-Minute Application Setup

1. **Copy files** to web root:
```bash
cp -r timekeeping_app/* /your/web/root/timekeeping/
```

2. **Create directories**:
```bash
mkdir /your/web/root/timekeeping/uploads
mkdir /your/web/root/timekeeping/exports
```

3. **Set permissions** (Windows):
```powershell
icacls "C:\inetpub\wwwroot\timekeeping\uploads" /grant "IIS_IUSRS:(OI)(CI)F"
icacls "C:\inetpub\wwwroot\timekeeping\exports" /grant "IIS_IUSRS:(OI)(CI)F"
```

## 5-Minute ColdFusion Config

1. **Open CF Admin**: http://localhost:8500/CFIDE/administrator/

2. **Add Datasource**:
   - Name: `TimekeepingDB`
   - Driver: Microsoft SQL Server
   - Server: your_server
   - Database: your_database
   - Click Submit & Verify

3. **Update code** - Find/Replace in all .cfm files:
```
yourDatasource → TimekeepingDB
```

## Test (2 minutes)

1. **Navigate**: http://localhost/timekeeping/
2. **Upload**: Sample Excel file
3. **Verify**: Dashboard displays data

## Done! 🎉

**Next Steps:**
- Read full [README.md](README.md) for details
- Review [USER_GUIDE.md](USER_GUIDE.md) for end users
- Check [DEPLOYMENT.md](DEPLOYMENT.md) for production

## Troubleshooting

**Problem**: "Datasource not found"
→ Restart ColdFusion service

**Problem**: Upload fails
→ Check folder permissions

**Problem**: No data in dashboard
→ Verify stored procedure ran successfully

## File Structure
```
timekeeping/
├── cfm/           → Application files
├── css/           → Styles
├── js/            → Scripts
├── sql/           → Database scripts
├── uploads/       → Temp files
└── exports/       → Generated files
```

## Key Files to Edit

1. `cfm/Application.cfc` → Line 7: datasource name
2. `cfm/*.cfm` → All datasource references
3. `config.cfm` → Application settings (optional)

## Critical Settings

```coldfusion
// Application.cfc
this.datasource = "TimekeepingDB";
this.uploadDirectory = expandPath("./uploads");
this.exportDirectory = expandPath("./exports");
```

## Sample Test Query

```sql
-- Test if everything works
SELECT TOP 5 
    t.Category,
    t.ClientEmail,
    t.DirectorateNameE,
    t.RecordedHours
FROM TimekeepingEnriched t
ORDER BY t.ImportDate DESC
```

## Support Checklist

Before asking for help, verify:
- [ ] All SQL scripts executed successfully
- [ ] Datasource connects (test in CF Admin)
- [ ] Folders exist with proper permissions
- [ ] Files updated with correct datasource name
- [ ] Browser console shows no errors

## Production Deployment

For production environments, also:
1. Enable HTTPS
2. Restrict CF Admin access
3. Create dedicated DB user
4. Setup backup schedule
5. Configure log rotation

See [DEPLOYMENT.md](DEPLOYMENT.md) for full production checklist.

---

**Installation Time**: ~15 minutes
**Skill Level**: Intermediate
**Support**: Check README.md for detailed help
