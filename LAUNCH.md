# 🚀 Cursor Agent Launch Guide

## Quick Start

This guide will help you launch the Cursor Agent to automatically execute the entire Claude Code AWS Bedrock Integration project.

---

## ✅ Prerequisites

Before launching, ensure you have:

1. **Linear API Key**
   ```bash
   export LINEAR_API_KEY="lin_pat_xxxxxxxxxxxxx"
   ```
   Get it from: https://linear.app/settings/api

2. **GitHub Token** (optional but recommended)
   ```bash
   export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxx"
   ```
   Get it from: https://github.com/settings/tokens

3. **Cursor Agent installed**
   - Should be available in your Cursor installation
   - Or install via: `npm install -g @cursor/agent`

---

## 🎯 Step-by-Step Launch Process

### Step 1: Run Setup Script (5 minutes)

```bash
# Navigate to project root
cd /Users/laptop/dev/claude-clode-cloud

# Make script executable
chmod +x .cursor-agent/setup-and-launch.sh

# Run setup
export LINEAR_API_KEY="YOUR_API_KEY_HERE"
export GITHUB_TOKEN="YOUR_GITHUB_TOKEN_HERE"
./.cursor-agent/setup-and-launch.sh
```

**What this does:**
- ✅ Verifies Linear API access
- ✅ Verifies GitHub access
- ✅ Initializes project structure
- ✅ Validates Linear project configuration
- ✅ Saves configuration to `.cursor-agent/env.local`

### Step 2: Start Work in Linear (2 minutes)

1. Go to Linear: https://linear.app/workdev
2. Open issue **WOR-7** (main task)
3. Open sub-issue **WOR-8** (AWS Infrastructure Setup)
4. Click **"Start work"** or move to **"In Progress"**

**What happens automatically:**
- Linear creates a webhook event
- Cursor Agent receives notification
- Cursor Agent creates GitHub branch: `eagurin/wor-8-aws-infrastructure-setup`
- Cursor Agent starts analyzing requirements

### Step 3: Monitor Cursor Agent Work

**In Linear Dashboard:**
- Go to: https://linear.app/workdev
- Watch progress bars update in real-time
- Read comments from Cursor Agent

**In GitHub:**
- Go to: https://github.com/evgenygurin/claude-clode-cloud
- Watch for new commits and PRs
- See CI/CD pipeline run automatically

### Step 4: Review and Merge PRs

When Cursor Agent completes a phase:

1. A GitHub PR is created automatically
2. CI/CD tests run automatically
3. You review the code
4. You merge the PR
5. Linear issue closes automatically
6. Cursor Agent starts next phase automatically

---

## 🔍 Monitoring the Execution

### Linear Dashboard

```text
Linear → Workdev → Issues

Watch:
- Progress percentage per task
- Comments from Cursor Agent
- Status changes (Backlog → In Progress → In Review → Done)
- Linked GitHub PRs
```

### GitHub Activity

```bash
GitHub → evgenygurin/claude-clode-cloud

Watch:
- New branches created for each phase
- Pull requests with code changes
- CI/CD pipeline results
- Commits with WOR-X references
```

### Terminal Output

```bash
# Watch Cursor Agent logs
tail -f .cursor-agent/execution.log

# Or follow with timestamps
tail -f .cursor-agent/execution.log | while IFS= read -r line; do echo "[$(date '+%H:%M:%S')] $line"; done
```

### Metrics

```bash
# View current metrics
cat .cursor-agent/metrics.json | jq .

# View execution log
cat .cursor-agent/execution.log
```

---

## 📋 Phase Execution Order

Phases execute sequentially (each depends on previous):

```text
WOR-8  → AWS Infrastructure Setup (8h estimated)
   ↓
WOR-9  → Claude Code Configuration (6h estimated)
   ↓
WOR-10 → Authentication Methods (5h estimated)
   ↓
WOR-11 → Cursor Integration (12h estimated) ⚠️ CRITICAL
   ↓
WOR-12 → Docker Containerization (8h estimated)
   ↓
WOR-13 → CI/CD Pipeline (10h estimated)
   ↓
WOR-14 → Documentation (8h estimated)
   ↓
WOR-15 → Monitoring & Cost Optimization (6h estimated)
   ↓
WOR-16 → Linear + Cursor Agent Config (4h estimated)
   ↓
🎉 PROJECT COMPLETE
```

**Total Estimated Time: ~57 hours of Cursor Agent work**

---

## ⚠️ Handling Blockers

If Cursor Agent gets stuck or encounters an error:

### Check Linear Comments
- Cursor Agent posts detailed comments
- Look for "❌" or "⚠️" emojis
- Read the error description

### Review GitHub PR
- Check the PR description for issues
- Read CI/CD logs for failures
- Fix the issue or post comment

### Manual Intervention Options

1. **Add comment in Linear**
   ```text
   @Cursor Agent: Please retry this task.
   The issue was: [describe the problem]
   ```

2. **Check logs**
   ```bash
   cat .cursor-agent/execution.log | grep ERROR
   ```

3. **Contact support** (if needed)
   - Check GitHub Issues: https://github.com/evgenygurin/claude-clode-cloud/issues
   - Check Linear Chat

---

## 🔐 Security Notes

### API Keys
- Linear API Key: Stored in `.cursor-agent/env.local` (in `.gitignore`)
- GitHub Token: Stored in `.cursor-agent/env.local` (in `.gitignore`)
- **Never commit these files!**

### AWS Credentials (used in WOR-8)
- Will be entered during Phase 1
- Stored securely in AWS profiles
- Not committed to repository

### Secret Scanning
- Cursor Agent has secret scanning enabled
- Will not push secrets to GitHub
- Will warn before committing sensitive data

---

## 🎮 Manual Controls

### Pause Execution
```bash
# Stop Cursor Agent
curl -X POST http://localhost:3000/control/pause \
  -H "Authorization: Bearer $LINEAR_API_KEY"
```

### Resume Execution
```bash
# Resume from where it stopped
curl -X POST http://localhost:3000/control/resume \
  -H "Authorization: Bearer $LINEAR_API_KEY"
```

### Restart Specific Phase
```bash
# Go to Linear and move task back to "Backlog"
# Then move to "In Progress" again
# Cursor Agent will restart automatically
```

### Abort Project
```bash
# Close the current phase in Linear
# Cursor Agent will stop processing
# You can review what was done
```

---

## 📊 Success Criteria

Project is successfully completed when:

✅ All 9 phases completed (WOR-8 through WOR-16)
✅ All Linear issues marked as "Done"
✅ All GitHub PRs merged to main branch
✅ All CI/CD tests passing
✅ Docker images built successfully
✅ Documentation complete
✅ Monitoring system operational
✅ Cursor Agent fully configured

---

## 🎊 Post-Completion

After all phases are complete:

1. **Review the Repository**
   ```bash
   git log --oneline | head -20
   ```

2. **Check Documentation**
   ```bash
   ls -la docs/
   cat README.md
   ```

3. **Verify Docker Images**
   ```bash
   docker images | grep claude-code
   ```

4. **Check Terraform**
   ```bash
   terraform plan
   ```

5. **Review AWS Resources**
   - Go to: https://console.aws.amazon.com/bedrock
   - Verify all resources created

6. **Test Integration**
   ```bash
   ./scripts/test-bedrock-integration.sh
   ```

---

## 📞 Troubleshooting

### Issue: "Linear API Key is not set"
```bash
# Check if key is set
echo $LINEAR_API_KEY

# If empty, set it
export LINEAR_API_KEY="lin_pat_xxxxxxxxxxxxx"
```

### Issue: "Cannot access GitHub"
```bash
# Check GitHub token
echo $GITHUB_TOKEN

# Test GitHub access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

### Issue: "Cursor Agent not responding"
```bash
# Check if it's running
ps aux | grep cursor-agent

# Check logs for errors
tail -100 .cursor-agent/execution.log

# Restart
.cursor-agent/setup-and-launch.sh
```

### Issue: "CI/CD Pipeline Failed"
- Check GitHub Actions: https://github.com/evgenygurin/claude-clode-cloud/actions
- Read the failure logs
- Post comment in Linear with the error
- Cursor Agent will retry

---

## 🚀 Quick Reference Commands

```bash
# Setup
chmod +x .cursor-agent/setup-and-launch.sh
export LINEAR_API_KEY="YOUR_KEY"
export GITHUB_TOKEN="YOUR_TOKEN"
./.cursor-agent/setup-and-launch.sh

# Monitor
tail -f .cursor-agent/execution.log
cat .cursor-agent/metrics.json | jq .

# Check status
curl -H "Authorization: Bearer $LINEAR_API_KEY" \
  https://api.linear.app/graphql \
  -d '{"query":"query { viewer { name } }"}'

# View configuration
cat .cursor-agent/config.yaml
```

---

## 📚 Additional Resources

- **Linear Project**: https://linear.app/workdev
- **GitHub Repository**: https://github.com/evgenygurin/claude-clode-cloud
- **Claude Code Docs**: https://code.claude.com/docs/
- **AWS Bedrock Docs**: https://aws.amazon.com/bedrock/
- **Linear API Docs**: https://developers.linear.app/docs/

---

## ✨ You're Ready!

Everything is set up and ready to go.

**Next step**: Go to Linear and move WOR-8 to "In Progress" 🎯

---

**Generated**: 2025-11-18
**Cursor Agent Version**: 1.0
**Project**: Claude Code AWS Bedrock Integration
