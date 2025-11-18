# CI/CD Pipeline Guide - Phase WOR-13

Complete automation of testing, security, and deployment using GitHub Actions.

**Estimated Time**: 30 minutes to understand, fully automated execution

**Components**:
1. Test workflow (lint, unit, integration tests)
2. Docker build/push workflow (multi-platform builds)
3. Security scanning (SAST, DAST, secrets, licenses)
4. Dependabot auto-updates
5. Automated deployment

---

## Quick Reference

### Workflow Files

```text
.github/workflows/
├── test.yml              # Lint, type check, unit/integration tests
├── docker.yml            # Build, push, test Docker images
├── security.yml          # Full security scanning suite
└── dependabot.yml        # Automated dependency updates
```

### Trigger Events

| Workflow | On Push | On PR | Manual | Schedule |
|----------|---------|-------|--------|----------|
| **test.yml** | ✅ main, develop, feat/** | ✅ main, develop | - | - |
| **docker.yml** | ✅ main, develop, tags | ✅ main, develop | ✅ yes | - |
| **security.yml** | ✅ main, develop | ✅ main, develop | - | ✅ daily |
| **dependabot.yml** | - | - | - | ✅ scheduled |

---

## Test Workflow (.github/workflows/test.yml)

### Purpose

Comprehensive testing on every push and pull request.

### Jobs

#### 1. Lint & Type Check (15 min)

```bash
npm run lint              # ESLint
npm run type-check       # TypeScript compiler
npm run format:check     # Prettier
```

**Status**: Reports but doesn't fail CI (continue-on-error: true)

#### 2. Unit Tests (20 min)

```bash
npm run test:unit -- --coverage --forceExit
```

**Coverage Reporting**:
- Uploads to Codecov
- Comments PR with coverage report
- Tracks coverage trends

**Requirements**:
- 80%+ coverage on changed files
- All test suites pass

#### 3. Build Docker Image (30 min)

```bash
docker build -t claude-code:${SHA}
```

**Features**:
- Uses BuildKit for caching
- Multi-platform (amd64, arm64)
- Doesn't push to registry
- Layer caching from GHA

#### 4. Integration Tests (30 min)

```bash
npm run test:integration -- --forceExit
```

**Services**:
- LocalStack (mock AWS services)
- Bedrock API mocking

**Note**: May fail due to LocalStack limitations (continue-on-error: true)

#### 5. Security Checks (15 min)

```bash
npm audit --audit-level=moderate
snyk test
```

**Non-blocking**: Continues even if vulnerabilities found

### PR Comments

Automatically posts test results as PR comments:

```text
## Test Results

| Check | Status |
|-------|--------|
| Lint & Type Check | ✅ success |
| Unit Tests | ✅ success |
| Docker Build | ✅ success |
| Integration Tests | ✅ success |
| Security Checks | ✅ success |
```

---

## Docker Build Workflow (.github/workflows/docker.yml)

### Purpose

Build, test, scan, and publish Docker images.

### Jobs

#### 1. Build (45 min)

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push (on main/develop only)
```

**Outputs**:
- Multi-architecture image
- Metadata (tags, digest)
- GHA cache for next build

#### 2. Security Scanning (30 min)

```bash
trivy image ghcr.io/user/repo:tag
snyk container test ghcr.io/user/repo:tag
```

**Results**:
- SARIF format
- Uploaded to GitHub Security tab
- Fails on CRITICAL severity

#### 3. Image Testing (30 min)

```bash
docker run -p 3000:3000 claude-code:test
curl http://localhost:3000/health
```

**Verification**:
- Health check endpoint responds
- Container logs captured
- Image size reported

### Image Tagging Strategy

```text
ghcr.io/user/repo:main                 # Latest on main
ghcr.io/user/repo:develop              # Latest on develop
ghcr.io/user/repo:v1.0.0               # Release tag
ghcr.io/user/repo:main-abc123          # Commit SHA
ghcr.io/user/repo:pr-123               # PR number
ghcr.io/user/repo:latest               # Latest release
```

---

## Security Workflow (.github/workflows/security.yml)

### Purpose

Comprehensive security scanning with multiple tools.

### Jobs

#### 1. Dependency Check (15 min)

```bash
npm audit --json
```

**Scans For**:
- Known vulnerabilities
- Version mismatch issues
- License conflicts

#### 2. SAST - CodeQL (30 min)

```bash
codeql database create
codeql database analyze
```

**Detects**:
- Code injection
- XSS vulnerabilities
- SQL injection
- Logic errors

**Results**: GitHub Security tab

#### 3. Secret Scanning (15 min)

```bash
trufflehog filesystem .
```

**Detects**:
- API keys
- Passwords
- Private keys
- Tokens

**Blocks**: Prevents commit if secrets found

#### 4. DAST - Snyk (30 min)

```bash
snyk test --all-projects
npm-check-updates
```

**Analyzes**:
- Transitive dependencies
- Update availability
- Security advisories

#### 5. License Compliance (15 min)

```bash
license-checker --failOn GPL
```

**Checks**:
- Allowed licenses (MIT, Apache, BSD, ISC)
- Detects GPL (usually forbidden in commercial)

#### 6. Container Scanning (30 min)

```bash
trivy image claude-code:security-scan
```

**Scans**:
- Base image vulnerabilities
- Installed packages
- System libraries

### Schedule

```yaml
# Daily security scan at 2 AM UTC
schedule:
  - cron: '0 2 * * *'
```

---

## Dependabot Configuration (.github/dependabot.yml)

### Purpose

Automated dependency updates with auto-merge for safe versions.

### Package Ecosystems

#### npm (Daily)

```yaml
schedule:
  interval: "daily"
  time: "03:00"
```

**Grouping**:
- AWS SDK updates together
- TypeScript types together
- ESLint packages together

**Auto-Merge**:
- Patch versions: ✅ auto-merge
- Minor versions: ✅ auto-merge (if all checks pass)
- Major versions: ❌ manual review

#### Docker (Weekly)

```yaml
schedule:
  interval: "weekly"
  day: "monday"
```

**Updates**:
- Base image patches
- Multi-stage builder image
- Security patches

#### GitHub Actions (Weekly)

```yaml
schedule:
  interval: "weekly"
  day: "monday"
```

**Updates**:
- Workflow actions
- Setup/build tools
- CI/CD improvements

### How Auto-Merge Works

1. **Dependency Check**: Runs test workflow
2. **All Checks Pass**: Marks ready for merge
3. **Auto-Merge**: Merges if approved
4. **Notification**: Posts in PR comment

---

## Linear ↔ GitHub Integration

### Automatic Branch Creation

When you start a Linear issue:
1. Linear creates associated GitHub issue
2. You manually create feature branch: `git checkout -b feat/wor-13-...`
3. Push to GitHub

**Branch Naming Convention**:
```text
feat/wor-13-phase-name
fix/bugname
docs/area
refactor/component
```

### Automatic Status Updates

When you push commits:
1. Tests run automatically
2. Results posted as PR comments
3. You manually link PR to Linear

**Manual Process**:
1. Create pull request
2. Add Linear issue link in PR description
3. Linear auto-updates status when PR merged

### Automated Deployment

**Current**: Manual deployment
**Planned (WOR-14)**: Automatic staging/prod deploy on merge

---

## Running Workflows Manually

### From GitHub UI

1. Go to **Actions** tab
2. Select workflow (e.g., "Test & Lint")
3. Click **Run workflow**
4. Select branch
5. Click **Run**

### Using GitHub CLI

```bash
# Run test workflow
gh workflow run test.yml --ref main

# Run docker workflow
gh workflow run docker.yml --ref develop

# List workflow runs
gh run list --repo user/repo

# View workflow status
gh run view <run-id>

# Cancel running workflow
gh run cancel <run-id>
```

---

## Monitoring Workflow Runs

### From GitHub UI

1. **Actions** tab → see all runs
2. Click run to see job details
3. Click job to see step logs
4. Search logs for errors

### Environment Variables

Most workflows use these environment variables:

```bash
NODE_VERSION: '22'           # Node.js version
REGISTRY: ghcr.io           # Docker registry
IMAGE_NAME: owner/repo      # Full image name
```

### Artifacts & Logs

**Artifacts Stored**:
- Coverage reports (npm tests)
- Trivy SARIF files (security)
- npm audit JSON (dependencies)
- License reports

**Log Retention**:
- 90 days (GitHub default)
- Searchable in UI

---

## Troubleshooting

### Workflow Fails to Run

**Problem**: No workflow runs triggered

**Solutions**:
```bash
# Check workflow syntax
act --dry-run

# Verify workflow file
yamllint .github/workflows/test.yml

# Check branch protection rules
# (may require approvals before running)
```

### Tests Pass Locally But Fail in CI

**Common Issues**:

1. **Environment Variables**: CI doesn't have local env
   ```bash
   # Solution: Set in workflow or use .env.test
   ```

2. **Node Version Mismatch**: Local v22, CI v20
   ```bash
   # Check NODE_VERSION in workflow
   node --version
   ```

3. **Docker Image**: Not available in CI
   ```bash
   # Solution: Build in CI or use pre-built
   ```

### Docker Build Takes Too Long

**Problem**: Build consistently exceeds timeout

**Solutions**:

1. **Enable BuildKit**: Already enabled (DOCKER_BUILDX)
2. **Use layer caching**: Already configured (cache-from: type=gha)
3. **Reduce build context**: .dockerignore already optimized
4. **Increase timeout**: Change timeout-minutes in workflow

### Security Scan Reports False Positives

**Problem**: Known safe dependency flagged as vulnerable

**Solution**: Update ignore list in dependabot or suppress in workflow

```yaml
# Suppress specific CVE
- name: Scan with Snyk
  continue-on-error: true  # Non-blocking
```

### PR Not Auto-Merging

**Problem**: Dependabot created PR but didn't auto-merge

**Causes**:
1. Checks didn't pass
2. Branch protection requires approval
3. Auto-merge disabled

**Solution**:
```bash
# Enable branch auto-merge
gh pr merge <pr-number> --auto --squash
```

---

## Performance Optimization

### Reduce Workflow Duration

#### Current Timing (Per Workflow)
- **test.yml**: ~40 minutes total
- **docker.yml**: ~60 minutes total (parallel jobs)
- **security.yml**: ~30 minutes total

#### Optimization Strategies

1. **Parallel Jobs** (already done)
   - Tests run in parallel
   - Reduces total time

2. **Caching** (already optimized)
   - npm cache: `cache: npm`
   - Docker layer cache: `cache-from: type=gha`

3. **Conditional Steps**
   ```yaml
   - if: github.event_name != 'pull_request'
   ```
   Skips unnecessary steps on PRs

4. **Selective Testing**
   ```yaml
   - if: contains(github.event.head_commit.modified, 'src/')
   ```
   Only test if source changed

### Reduce CI Resource Usage

1. **Matrix Reduction**: Currently only Node 22
2. **Platform Reduction**: Full multi-arch (amd64 + arm64)
3. **Container Cleanup**: Remove unused images
   ```bash
   docker system prune -a --volumes
   ```

---

## Security Best Practices

### 1. Protect Secrets

```bash
# Never log secrets
- run: echo ${{ secrets.MY_SECRET }}  # ❌ WRONG

# Use secret masking
- run: |
    SECRET="${{ secrets.MY_SECRET }}"
    some-command "$SECRET"  # Automatically masked
```

### 2. Workflow Permissions

Current workflow uses minimal permissions:

```yaml
permissions:
  contents: read          # Read code
  packages: write         # Write Docker images
  security-events: write  # Report vulnerabilities
```

### 3. Branch Protection Rules

Recommended configuration on `main`:

```text
- Require status checks before merging:
  - test (all jobs)
  - security (critical checks)

- Require code review: 1 approval
- Require up-to-date before merge
- Dismiss stale reviews
- Include administrators
```

### 4. Access Control

- **Docker Registry**: Authenticated with GitHub token
- **Snyk**: Token stored in GitHub secrets
- **Codecov**: Public repo, no token needed

---

## Deployment Integration (WOR-14)

Planned deployment workflow:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    needs: [test, docker, security]
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
      - name: Deploy to staging
        run: ./scripts/deploy-staging.sh
      - name: Run smoke tests
        run: npm run test:smoke
      - name: Deploy to production
        run: ./scripts/deploy-prod.sh
```

---

## GitHub Integration Examples

### Link Linear Issue in PR

```markdown
# PR Description

Closes [WOR-13](https://linear.app/workdev/issue/WOR-13)

## Changes
- Implemented GitHub Actions workflows
- Added security scanning
- Configured Dependabot

## Testing
- [x] Tests pass locally
- [x] No TypeScript errors
- [x] Docker image builds
```

### Check Workflow Status

```bash
# List recent runs
gh run list --repo user/repo --branch main

# Get specific run details
gh run view <run-id> --log

# Check specific job
gh run view <run-id> --job <job-id>
```

### Manual Workflow Trigger

```bash
# Trigger from command line
gh workflow run test.yml \
  --ref main \
  --input skip-integration-tests=true
```

---

## Maintenance

### Weekly Tasks

- Monitor failing workflows
- Review Dependabot PRs
- Check security alerts
- Update documentation

### Monthly Tasks

- Review workflow performance
- Optimize slow jobs
- Update action versions
- Audit access permissions

### Quarterly Tasks

- Full workflow audit
- Update security policies
- Plan new CI/CD features
- Review cost optimization

---

## Files Reference

### Workflow Configurations

- **.github/workflows/test.yml** (270 lines)
  - Lint, type check, tests, Docker build
  - PR comments with results
  - Codecov integration

- **.github/workflows/docker.yml** (200 lines)
  - Multi-platform Docker builds
  - Container scanning (Trivy, Snyk)
  - Image testing and verification
  - Release creation

- **.github/workflows/security.yml** (280 lines)
  - npm audit and Snyk scanning
  - CodeQL SAST analysis
  - Secret detection (TruffleHog)
  - License compliance checking
  - Container vulnerability scanning

- **.github/dependabot.yml** (120 lines)
  - npm daily checks with auto-merge
  - Docker weekly updates
  - GitHub Actions weekly updates
  - Grouping and labeling

---

**Phase**: WOR-13 - CI/CD Pipeline
**Status**: Complete
**Estimated Duration**: 10 hours for full implementation
**Created**: 2025-11-18
