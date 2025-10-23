#!/bin/bash

# Timekeeping App - Git Repository Initialization Script
# This script helps you quickly set up your Git repository

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║   Timekeeping App - Git Repository Setup                         ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Error: Git is not installed."
    echo "   Please install Git first: https://git-scm.com/downloads"
    exit 1
fi

echo "✅ Git is installed"
echo ""

# Check if already initialized
if [ -d ".git" ]; then
    echo "⚠️  Git repository already initialized"
    read -p "Do you want to reinitialize? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    rm -rf .git
fi

# Initialize repository
echo "📦 Initializing Git repository..."
git init
echo ""

# Configure Git (optional)
read -p "Configure Git user? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter your name: " git_name
    read -p "Enter your email: " git_email
    git config user.name "$git_name"
    git config user.email "$git_email"
    echo "✅ Git user configured"
    echo ""
fi

# Add remote
read -p "Add remote repository? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter remote URL (e.g., https://github.com/user/repo.git): " remote_url
    git remote add origin "$remote_url"
    echo "✅ Remote added: $remote_url"
    echo ""
fi

# Create required directories if they don't exist
echo "📁 Creating required directories..."
mkdir -p uploads exports logs
touch uploads/.gitkeep exports/.gitkeep logs/.gitkeep
echo "✅ Directories created"
echo ""

# Initial commit
echo "💾 Creating initial commit..."
git add .
git commit -m "Initial commit: Timekeeping Import & Analytics Tool v1.0"
echo "✅ Initial commit created"
echo ""

# Create branches
read -p "Create standard branches (development, staging, production)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git branch -M main
    git branch development
    git branch staging
    git branch production
    echo "✅ Branches created: main, development, staging, production"
    echo ""
fi

# Push to remote
if git remote | grep -q origin; then
    read -p "Push to remote repository? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Pushing to remote..."
        git push -u origin main
        
        read -p "Push all branches? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin development
            git push origin staging
            git push origin production
            echo "✅ All branches pushed"
        fi
        echo ""
    fi
fi

# Summary
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║   Setup Complete!                                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Review the .gitignore file"
echo "2. Configure branch protection rules (if using GitHub/GitLab)"
echo "3. Copy config.template.cfm to config.cfm and configure"
echo "4. Follow DEPLOYMENT.md for server deployment"
echo ""
echo "📚 Documentation:"
echo "   - GIT_DEPLOYMENT.md : Complete Git deployment guide"
echo "   - QUICKSTART.md     : Quick setup guide"
echo "   - DEPLOYMENT.md     : Production deployment"
echo ""
echo "🎉 Repository ready for development!"
echo ""

# Display current status
echo "Current repository status:"
git status -sb
echo ""

echo "Done! 🚀"
