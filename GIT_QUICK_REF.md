# Git Deployment - Quick Reference Card

## 🚀 Quick Deploy to GitHub (5 Minutes)

```bash
# 1. Extract the ZIP file
unzip timekeeping_app.zip
cd timekeeping_app

# 2. Run the init script (easiest way)
./init-git.sh

# OR do it manually:
git init
git add .
git commit -m "Initial commit: Timekeeping App v1.0"
git branch -M main
git remote add origin https://github.com/YOUR-ORG/timekeeping-app.git
git push -u origin main
```

## 📋 Three-Step GitHub Setup

### Step 1: Create Repository on GitHub
1. Go to https://github.com/new
2. Name: `timekeeping-app`
3. Private repository
4. Don't initialize with README
5. Click "Create repository"

### Step 2: Push Your Code
```bash
cd timekeeping_app
git init
git add .
git commit -m "Initial commit"
git remote add origin YOUR_GITHUB_URL
git push -u origin main
```

### Step 3: Deploy to Server
```bash
# On your web server:
cd /var/www/html
git clone YOUR_GITHUB_URL timekeeping
cd timekeeping
mkdir uploads exports logs
chmod 755 uploads exports logs
cp config.template.cfm config.cfm
# Edit config.cfm with your settings
```

## 🔄 Common Commands

### Update Production Server
```bash
# On server:
cd /var/www/html/timekeeping
git pull origin main
```

### Create Feature Branch
```bash
git checkout -b feature/my-feature
# Make changes
git add .
git commit -m "feat: add new feature"
git push origin feature/my-feature
```

### Deploy New Version
```bash
# Local machine:
git tag v1.1.0
git push origin v1.1.0

# On server:
git fetch --tags
git checkout v1.1.0
```

## 📁 What's Included

```
✅ .gitignore           - Protects sensitive files
✅ .github/workflows/   - Automated deployment
✅ init-git.sh          - Auto-setup script
✅ GIT_DEPLOYMENT.md    - Complete guide
✅ GITHUB_README.md     - Repository README
```

## ⚠️ Important Notes

### Never Commit These Files:
- `config.cfm` (use config.template.cfm)
- `uploads/*` (user data)
- `exports/*` (generated files)
- `logs/*` (log files)

### Always Configure On Server:
1. Copy `config.template.cfm` to `config.cfm`
2. Update datasource names in all .cfm files
3. Run SQL scripts (first time only)
4. Create ColdFusion datasource

## 🔐 Security Checklist

- [ ] Use private repository for internal tools
- [ ] Add deploy keys (read-only) for production
- [ ] Enable branch protection on main/production
- [ ] Never commit passwords or API keys
- [ ] Use environment variables for secrets
- [ ] Enable 2FA on Git accounts

## 🆘 Quick Troubleshooting

**"Permission denied"**
```bash
# Check SSH key:
ssh -T git@github.com

# Or use HTTPS with token
git remote set-url origin https://TOKEN@github.com/org/repo.git
```

**"Already initialized"**
```bash
# Remove and reinit:
rm -rf .git
./init-git.sh
```

**"Failed to push"**
```bash
# Pull first:
git pull origin main --rebase
git push origin main
```

## 📚 Full Documentation

- **Complete Git Guide**: GIT_DEPLOYMENT.md
- **Quick Setup**: QUICKSTART.md
- **Production Deploy**: DEPLOYMENT.md
- **User Guide**: USER_GUIDE.md

## 🎯 Deployment Options

| Method | Time | Complexity | Best For |
|--------|------|------------|----------|
| Manual Clone | 10 min | Easy | Testing |
| GitHub Actions | 15 min | Medium | Automation |
| Git Webhooks | 20 min | Medium | Auto-deploy |
| Direct Git Push | 30 min | Advanced | Custom setup |

## ✅ Post-Deploy Checklist

After deploying via Git:

```bash
# On server:
cd /var/www/html/timekeeping

# 1. Check files
ls -la

# 2. Create config
cp config.template.cfm config.cfm
nano config.cfm

# 3. Set permissions
chmod 755 uploads exports logs

# 4. Test access
curl http://localhost/timekeeping/

# 5. Check logs
tail -f logs/application.log
```

## 🚀 Ready to Deploy?

1. **Start here**: Run `./init-git.sh`
2. **Need help?**: Read GIT_DEPLOYMENT.md
3. **Questions?**: Check DEPLOYMENT.md troubleshooting

---

**Pro Tip**: Bookmark this file for quick reference! 📌
