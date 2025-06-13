# Git Workflow Guide - Remote Mouse Controller

## 🌳 Branch Strategy

### Main Branches
- **`main`**: Production-ready, stable releases
- **`develop`**: Integration branch for features, pre-release testing

### Supporting Branches
- **`feature/*`**: New feature development
- **`bugfix/*`**: Bug fixes
- **`hotfix/*`**: Critical production fixes
- **`release/*`**: Release preparation

## 🔄 Workflow Process

### 1. Feature Development
```bash
# Start new feature
git checkout develop
git pull origin develop
git checkout -b feature/feature-name

# Work on feature...
git add .
git commit -m "feat: add new feature description"

# Push feature branch
git push -u origin feature/feature-name

# Create Pull Request to develop
```

### 2. Bug Fixes
```bash
# Create bugfix branch
git checkout develop
git checkout -b bugfix/issue-description

# Fix the bug...
git add .
git commit -m "fix: resolve issue description"

# Push and create PR
git push -u origin bugfix/issue-description
```

### 3. Hotfixes (Critical Production Issues)
```bash
# Create hotfix from main
git checkout main
git checkout -b hotfix/critical-issue

# Fix the issue...
git add .
git commit -m "hotfix: resolve critical issue"

# Merge to both main and develop
git checkout main
git merge hotfix/critical-issue
git checkout develop
git merge hotfix/critical-issue
```

### 4. Release Process
```bash
# Create release branch
git checkout develop
git checkout -b release/v1.1.0

# Prepare release (version bumps, changelog, etc.)
git add .
git commit -m "chore: prepare release v1.1.0"

# Merge to main and tag
git checkout main
git merge release/v1.1.0
git tag -a v1.1.0 -m "Release version 1.1.0"

# Merge back to develop
git checkout develop
git merge release/v1.1.0
```

## 📝 Commit Message Convention

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks
- **perf**: Performance improvements
- **ci**: CI/CD changes

### Examples
```bash
feat(mobile): add sensitivity settings for mouse control
fix(server): resolve Windows mDNS compatibility issue
docs: update API documentation for new features
refactor(mobile): extract connection service logic
test(server): add unit tests for mouse controller
chore: update dependencies to latest versions
```

## 🏷️ Tagging Strategy

### Version Format: `v<major>.<minor>.<patch>`
- **Major**: Breaking changes
- **Minor**: New features (backward compatible)
- **Patch**: Bug fixes

### Tag Examples
```bash
v1.0.0    # Initial release
v1.1.0    # Added computer name display feature
v1.2.0    # Added connection control and settings
v1.2.1    # Bug fix for connection issues
```

## 🔧 Git Hooks & Automation

### Pre-commit Hook (Optional)
```bash
#!/bin/sh
# Run code analysis before commit
cd pc_server && dart analyze
cd ../mobile_client && flutter analyze
```

### Pre-push Hook (Optional)
```bash
#!/bin/sh
# Run tests before push
cd pc_server && dart test
cd ../mobile_client && flutter test
```

## 🚀 Advanced Git Concepts

### 1. Interactive Rebase
```bash
# Clean up commit history before merging
git rebase -i HEAD~3
```

### 2. Cherry-picking
```bash
# Apply specific commit to another branch
git cherry-pick <commit-hash>
```

### 3. Stashing
```bash
# Save work in progress
git stash save "work in progress on feature X"
git stash list
git stash apply stash@{0}
```

### 4. Squashing Commits
```bash
# Combine multiple commits into one
git rebase -i HEAD~3
# Change 'pick' to 'squash' for commits to combine
```

### 5. Git Aliases (Productivity)
```bash
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.visual '!gitk'
```

## 📊 Current Branch Status

### Active Branches
- `main`: Stable release (v1.0.0)
- `develop`: Integration branch
- `feature/connection-control-and-settings`: Current feature development

### Planned Features
1. **v1.1.0**: Connection control and settings
   - Mobile app disconnect functionality
   - Mouse sensitivity controls
   - Scroll speed adjustment

2. **v1.2.0**: Enhanced user experience
   - Connection history
   - Multiple server support
   - Dark/light theme

3. **v2.0.0**: Advanced features
   - Keyboard support
   - File transfer
   - Screen mirroring

## 🛠️ Repository Setup Commands

```bash
# Clone repository
git clone <repository-url>
cd remote_mouse_controller

# Set up local development
git checkout develop
git checkout -b feature/my-feature

# Configure Git (first time)
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

---

**Current Branch**: `feature/connection-control-and-settings`  
**Next Release**: `v1.1.0`  
**Status**: 🚧 In Development
