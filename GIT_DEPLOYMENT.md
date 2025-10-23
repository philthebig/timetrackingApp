# Git Deployment Guide

Complete guide for deploying the Timekeeping App via Git/GitHub.

## 🎯 Overview

This guide covers three deployment scenarios:
1. **GitHub Repository** - Standard Git workflow
2. **Self-Hosted Git** - GitLab, Bitbucket, or local Git server
3. **Direct Git Deployment** - Deploy directly from Git to server

---

## 📦 Option 1: GitHub Deployment (Recommended)

### Step 1: Create GitHub Repository

1. **Create new repository on GitHub:**
   - Go to https://github.com/new
   - Repository name: `timekeeping-app`
   - Description: "Timekeeping Import & Analytics Tool"
   - Visibility: Private (recommended for internal tools)
   - Don't initialize with README (we have one)

2. **Note your repository URL:**
   ```
   https://github.com/your-org/timekeeping-app.git
   ```

### Step 2: Initialize Local Repository

```bash
# Navigate to the application directory
cd timekeeping_app

# Initialize Git repository
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: Timekeeping Import & Analytics Tool v1.0"

# Add remote
git remote add origin https://github.com/your-org/timekeeping-app.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Configure GitHub Repository

1. **Add repository description** (on GitHub)
2. **Add topics:** `coldfusion`, `sql-server`, `analytics`, `dashboard`
3. **Create branches:**
   ```bash
   git checkout -b development
   git push origin development
   
   git checkout -b staging
   git push origin staging
   
   git checkout -b production
   git push origin production
   ```

### Step 4: Set Up Branch Protection

In GitHub repository settings:
1. Go to Settings > Branches
2. Add rule for `main` branch:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass
   - ✅ Include administrators
3. Add rule for `production` branch:
   - ✅ Require pull request reviews
   - ✅ Require approvals: 2

### Step 5: Deploy from GitHub

#### Method A: Manual Clone to Server

```bash
# On your web server
cd /var/www/html

# Clone repository
git clone https://github.com/your-org/timekeeping-app.git timekeeping

# Create required directories
cd timekeeping
mkdir uploads exports logs
chmod 755 uploads exports logs

# Copy and configure
cp config.template.cfm config.cfm
nano config.cfm  # Edit configuration

# Run database scripts
sqlcmd -S your_server -d your_database -i sql/01_create_tables.sql
sqlcmd -S your_server -d your_database -i sql/02_create_stored_procedure.sql
sqlcmd -S your_server -d your_database -i sql/03_create_views.sql
```

#### Method B: GitHub Actions (Automated)

1. **Configure GitHub Secrets:**
   - Go to Settings > Secrets and variables > Actions
   - Add secrets:
     - `DEPLOY_USER`: SSH username
     - `DEPLOY_HOST`: Server hostname/IP
     - `DEPLOY_PATH`: Deployment path
     - `DEPLOY_KEY`: SSH private key

2. **Push to production branch:**
   ```bash
   git checkout production
   git merge main
   git push origin production
   ```

3. **Monitor deployment:**
   - Go to Actions tab in GitHub
   - Watch deployment progress

#### Method C: Git Webhooks

1. **On your server, create webhook receiver:**

```bash
# Create webhook.cfm on your server
cat > /var/www/html/timekeeping/webhook.cfm << 'EOF'
<cfif structKeyExists(form, "payload") OR structKeyExists(url, "deploy")>
    <cfset logFile = expandPath("./logs/deploy.log")>
    
    <cftry>
        <!--- Pull latest changes --->
        <cfexecute name="git"
                   arguments="pull origin main"
                   timeout="60"
                   variable="gitOutput"
                   errorvariable="gitError">
        </cfexecute>
        
        <!--- Log the deployment --->
        <cffile action="append"
                file="#logFile#"
                output="#now()# - Deployment successful: #gitOutput#">
        
        <cfoutput>{"status":"success","message":"Deployed successfully"}</cfoutput>
        
        <cfcatch>
            <cffile action="append"
                    file="#logFile#"
                    output="#now()# - Deployment failed: #cfcatch.message#">
            
            <cfoutput>{"status":"error","message":"#cfcatch.message#"}</cfoutput>
        </cfcatch>
    </cftry>
</cfif>
EOF
```

2. **Configure GitHub webhook:**
   - Repository Settings > Webhooks > Add webhook
   - Payload URL: `https://your-server.com/timekeeping/webhook.cfm`
   - Content type: `application/json`
   - Events: Just the push event
   - Active: ✅

---

## 🔧 Option 2: Self-Hosted Git (GitLab/Bitbucket)

### GitLab Setup

```bash
# Create project on GitLab
# Note your project URL

# Initialize and push
git init
git remote add origin https://gitlab.com/your-org/timekeeping-app.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

### GitLab CI/CD Pipeline

Create `.gitlab-ci.yml`:

```yaml
stages:
  - validate
  - deploy

validate:
  stage: validate
  script:
    - echo "Validating SQL scripts..."
    - test -f sql/01_create_tables.sql
    - test -f sql/02_create_stored_procedure.sql
    - test -f sql/03_create_views.sql
    - echo "Validation complete"

deploy_production:
  stage: deploy
  only:
    - production
  script:
    - echo "Deploying to production..."
    - rsync -avz --delete ./ $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH
  when: manual
```

---

## 🚀 Option 3: Direct Git Deployment

### Setup Git on Web Server

```bash
# On your web server
cd /var/www/html

# Initialize bare repository
mkdir timekeeping.git
cd timekeeping.git
git init --bare

# Create post-receive hook
cat > hooks/post-receive << 'EOF'
#!/bin/bash
TARGET="/var/www/html/timekeeping"
GIT_DIR="/var/www/html/timekeeping.git"
BRANCH="main"

while read oldrev newrev ref
do
    # Check if main branch
    if [[ $ref = refs/heads/$BRANCH ]]; then
        echo "Deploying $BRANCH branch..."
        
        # Checkout latest code
        git --work-tree=$TARGET --git-dir=$GIT_DIR checkout -f $BRANCH
        
        # Set permissions
        chmod 755 $TARGET/uploads
        chmod 755 $TARGET/exports
        chmod 755 $TARGET/logs
        
        echo "Deployment complete!"
    fi
done
EOF

chmod +x hooks/post-receive
```

### Push from Development Machine

```bash
# Add server as remote
git remote add production ssh://user@your-server/var/www/html/timekeeping.git

# Push to deploy
git push production main
```

---

## 📋 Deployment Checklist

After any Git deployment:

- [ ] Verify files copied correctly
- [ ] Check folder permissions (uploads, exports, logs)
- [ ] Copy config.template.cfm to config.cfm
- [ ] Update config.cfm with server-specific settings
- [ ] Update datasource names in .cfm files
- [ ] Run SQL scripts (first deployment only)
- [ ] Create ColdFusion datasource
- [ ] Test application access
- [ ] Check error logs
- [ ] Verify dashboard loads
- [ ] Test file upload
- [ ] Confirm database connectivity

---

## 🔄 Common Git Workflows

### Development Workflow

```bash
# Create feature branch
git checkout -b feature/new-export-format

# Make changes
# ... edit files ...

# Commit changes
git add .
git commit -m "feat: add CSV export format"

# Push to remote
git push origin feature/new-export-format

# Create pull request (on GitHub/GitLab)
# After approval, merge to main
```

### Hotfix Workflow

```bash
# Create hotfix branch from production
git checkout production
git checkout -b hotfix/fix-upload-bug

# Fix the issue
# ... edit files ...

# Commit and push
git add .
git commit -m "fix: resolve upload timeout issue"
git push origin hotfix/fix-upload-bug

# Merge to production and main
git checkout production
git merge hotfix/fix-upload-bug
git push origin production

git checkout main
git merge hotfix/fix-upload-bug
git push origin main
```

### Update Production

```bash
# Update from main branch
git checkout main
git pull origin main

# Merge to production
git checkout production
git merge main

# Test before pushing
# ... test locally ...

# Push to production
git push origin production  # Triggers deployment
```

---

## 🛠️ Deployment Automation Script

Create `deploy.sh` for easy deployment:

```bash
#!/bin/bash

# Timekeeping App Deployment Script
# Usage: ./deploy.sh [environment]
# Example: ./deploy.sh production

ENVIRONMENT=${1:-staging}
DEPLOY_USER="your_user"
DEPLOY_HOST="your_server.com"

case $ENVIRONMENT in
    production)
        DEPLOY_PATH="/var/www/html/timekeeping"
        BRANCH="production"
        ;;
    staging)
        DEPLOY_PATH="/var/www/html/timekeeping-staging"
        BRANCH="staging"
        ;;
    development)
        DEPLOY_PATH="/var/www/html/timekeeping-dev"
        BRANCH="development"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

echo "Deploying to $ENVIRONMENT..."
echo "Branch: $BRANCH"
echo "Path: $DEPLOY_PATH"

# Pull latest changes locally
git checkout $BRANCH
git pull origin $BRANCH

# Deploy to server
rsync -avz --delete \
    --exclude '.git' \
    --exclude 'config.cfm' \
    --exclude 'uploads/*' \
    --exclude 'exports/*' \
    --exclude 'logs/*' \
    --exclude '.DS_Store' \
    ./ $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH

echo "Deployment complete!"
echo "Don't forget to:"
echo "  1. Check config.cfm on server"
echo "  2. Verify folder permissions"
echo "  3. Test the application"
```

Make it executable:
```bash
chmod +x deploy.sh
```

---

## 🔐 Security Best Practices

1. **Never commit sensitive data:**
   - Database passwords
   - API keys
   - config.cfm (use config.template.cfm)
   - User uploads or exports

2. **Use environment variables:**
   ```coldfusion
   <cfset datasourcePassword = server.system.environment.DB_PASSWORD>
   ```

3. **Restrict repository access:**
   - Private repository for internal tools
   - Use team access controls
   - Enable 2FA for all developers

4. **Use deploy keys:**
   ```bash
   # Generate deploy key (read-only)
   ssh-keygen -t ed25519 -C "deploy@your-server"
   
   # Add to GitHub Deploy Keys (Settings > Deploy keys)
   ```

---

## 📊 Monitoring Deployments

### Log Deployments

```sql
-- Create deployment log table
CREATE TABLE DeploymentLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    DeployDate DATETIME DEFAULT GETDATE(),
    Branch NVARCHAR(50),
    CommitHash NVARCHAR(100),
    DeployedBy NVARCHAR(100),
    Status NVARCHAR(50)
);
```

### Track in ColdFusion

```coldfusion
<!--- In Application.cfc --->
<cfset application.version = "1.0.0">
<cfset application.commitHash = "abc123">
<cfset application.deployDate = "2024-10-23">
```

---

## 🆘 Rollback Procedure

If deployment fails:

```bash
# Quick rollback to previous commit
git checkout production
git reset --hard HEAD~1
git push --force origin production

# Or rollback to specific commit
git reset --hard abc123
git push --force origin production
```

---

## ✅ Post-Deployment Testing

```bash
# Test application
curl https://your-server.com/timekeeping/

# Test API
curl https://your-server.com/timekeeping/api.cfm?action=getDashboardStats

# Check logs
tail -f /var/www/html/timekeeping/logs/application.log
```

---

## 📚 Additional Resources

- [GitHub Docs - Actions](https://docs.github.com/en/actions)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [Git Workflows](https://www.atlassian.com/git/tutorials/comparing-workflows)
- [ColdFusion Deployment](https://helpx.adobe.com/coldfusion/deployment.html)

---

**Questions?** Check the troubleshooting section in [DEPLOYMENT.md](DEPLOYMENT.md)
