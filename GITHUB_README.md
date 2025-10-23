# Timekeeping Import & Analytics Tool

[![License](https://img.shields.io/badge/license-Internal-blue.svg)]()
[![ColdFusion](https://img.shields.io/badge/ColdFusion-2018%2B-orange.svg)]()
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2016%2B-red.svg)]()

Professional web application for importing Excel timekeeping data and automatically enriching it with organizational directorate information.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/your-org/timekeeping-app.git
cd timekeeping-app

# Follow the quick start guide
cat QUICKSTART.md
```

**Setup time:** 15 minutes | **Difficulty:** Intermediate

## ✨ Features

- 📊 **Excel Import** - Automatic parsing of timekeeping reports
- 🔍 **Smart Matching** - Client matching by email and name
- 🏢 **Auto-Enrichment** - Adds directorate/division/branch info
- 📈 **Interactive Dashboard** - Real-time statistics with charts
- 📥 **Multiple Exports** - Export by directorate, category, or client
- 📦 **Batch Tracking** - Complete import history
- ⚠️ **Unmatched Reporting** - Identify data quality issues

## 📋 Requirements

- **ColdFusion**: 2018+ or Lucee 5.3+
- **Database**: SQL Server 2016+ with vUserInfo view access
- **Web Server**: IIS, Apache, or ColdFusion built-in
- **Browser**: Modern browser (Chrome, Firefox, Edge, Safari)

## 🔧 Installation

### Option 1: Quick Start (15 minutes)
```bash
# 1. Run SQL scripts
sqlcmd -S your_server -d your_database -i sql/01_create_tables.sql
sqlcmd -S your_server -d your_database -i sql/02_create_stored_procedure.sql
sqlcmd -S your_server -d your_database -i sql/03_create_views.sql

# 2. Deploy files
cp -r . /your/web/root/timekeeping/

# 3. Create directories
mkdir uploads exports logs
chmod 755 uploads exports logs

# 4. Configure (see QUICKSTART.md for details)
```

See [QUICKSTART.md](QUICKSTART.md) for complete instructions.

### Option 2: Full Production Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md) for comprehensive production setup including security hardening.

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [START_HERE.txt](START_HERE.txt) | Welcome guide - read this first |
| [QUICKSTART.md](QUICKSTART.md) | 15-minute setup guide |
| [README.md](README.md) | Complete technical documentation |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Production deployment guide |
| [USER_GUIDE.md](USER_GUIDE.md) | End-user instructions |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Project overview |

## 🏗️ Project Structure

```
timekeeping-app/
├── cfm/                      # ColdFusion application files
│   ├── Application.cfc       # App configuration
│   ├── index.cfm            # Upload interface
│   ├── dashboard.cfm        # Analytics dashboard
│   ├── export.cfm           # Data export
│   └── api.cfm              # REST API endpoints
├── sql/                      # Database setup scripts
│   ├── 01_create_tables.sql
│   ├── 02_create_stored_procedure.sql
│   └── 03_create_views.sql
├── css/                      # Stylesheets
├── js/                       # JavaScript
├── uploads/                  # Temporary uploads (gitignored)
├── exports/                  # Generated exports (gitignored)
├── logs/                     # Application logs (gitignored)
└── config.template.cfm       # Configuration template
```

## ⚙️ Configuration

1. Copy the configuration template:
```bash
cp config.template.cfm config.cfm
```

2. Edit `config.cfm` with your settings

3. Update datasource in all `.cfm` files:
```coldfusion
datasource="yourDatasource" → datasource="TimekeepingDB"
```

4. Create ColdFusion datasource in CF Admin

## 🔐 Security

- ✅ SQL injection protection (cfqueryparam)
- ✅ XSS prevention (security headers)
- ✅ File upload validation
- ✅ Session management
- ✅ HTTPS ready
- ✅ Configurable IP restrictions

**Important:** Never commit `config.cfm` or files in `uploads/`, `exports/`, or `logs/` directories.

## 🚢 Deployment Options

### Manual Deployment
```bash
# Create deployment package
zip -r deploy.zip cfm/ css/ js/ sql/ config.template.cfm *.md

# Upload to server
scp deploy.zip user@server:/path/to/deploy/
```

### Automated Deployment (GitHub Actions)
This repository includes a GitHub Actions workflow (`.github/workflows/deploy.yml`) for automated deployment.

**Setup:**
1. Add secrets to your repository:
   - `DEPLOY_USER` - SSH user
   - `DEPLOY_HOST` - Server hostname
   - `DEPLOY_PATH` - Deployment path

2. Push to `production` branch to trigger deployment

### Docker Deployment (Optional)
```dockerfile
# Example Dockerfile (customize as needed)
FROM ortussolutions/commandbox:lucee5

COPY . /app
WORKDIR /app

EXPOSE 8080
CMD ["box", "server", "start"]
```

## 🧪 Testing

```bash
# Test database connection
sqlcmd -S your_server -d your_database -Q "SELECT TOP 5 * FROM vUserInfo"

# Test ColdFusion (create test file)
echo "<cfoutput>ColdFusion is working! Date: #now()#</cfoutput>" > test.cfm
```

Visit: `http://your-server/timekeeping/test.cfm`

## 📊 Usage

### For End Users
1. Navigate to the application URL
2. Upload Excel timekeeping file
3. Review import summary
4. View dashboard analytics
5. Export enriched data

See [USER_GUIDE.md](USER_GUIDE.md) for detailed instructions.

### For Administrators
- Monitor imports in `ImportBatch` table
- Review unmatched clients
- Export data for reporting
- Track usage via logs

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Datasource not found" | Verify datasource name in CF Admin |
| Upload fails | Check folder permissions on `uploads/` |
| No data in dashboard | Verify stored procedure executed |
| Charts not displaying | Check browser console for errors |

See [README.md](README.md) for comprehensive troubleshooting.

## 🤝 Contributing

### Development Workflow
```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes and test
# ...

# Commit with descriptive message
git commit -m "feat: add new feature"

# Push and create pull request
git push origin feature/your-feature
```

### Commit Convention
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Formatting changes
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance tasks

## 📝 License

Internal use only. All rights reserved.

## 👥 Support

- **Documentation**: Check the `/docs` folder
- **Issues**: Create a GitHub issue
- **Email**: your-support@email.com

## 🗺️ Roadmap

### Current Version (1.0)
- ✅ Excel import
- ✅ Automatic enrichment
- ✅ Dashboard analytics
- ✅ Multiple exports

### Future Enhancements
- [ ] Scheduled imports
- [ ] Email notifications
- [ ] Advanced filtering
- [ ] Custom report builder
- [ ] Mobile app
- [ ] API rate limiting
- [ ] Multi-language UI

## 📈 Performance

- **Small files** (<100 records): 5-10 seconds
- **Medium files** (100-500 records): 15-30 seconds
- **Large files** (500-1000 records): 30-60 seconds

## 🔗 Related Projects

- [Excel Parser Library](#)
- [ColdFusion Utilities](#)
- [Dashboard Templates](#)

## 📞 Contact

- **Project Lead**: [Name]
- **Technical Lead**: [Name]
- **Support Team**: [Email]

---

**Made with ❤️ using ColdFusion**

**Last Updated**: 2024
**Version**: 1.0.0
