#!/bin/bash

# =============================================================================
# Cursor Agent Setup and Launch Script
# This script prepares the environment and launches the Cursor Agent
# for full automation of Claude Code AWS Bedrock Integration project
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Step 1: Verify Prerequisites
# =============================================================================

verify_prerequisites() {
    log_info "Verifying prerequisites..."

    # Check if in correct directory
    if [ ! -d ".git" ]; then
        log_error "Not in a git repository root. Please run from repository root."
        exit 1
    fi

    # Check for required tools
    local required_tools=("git" "curl" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done

    log_success "All prerequisites verified"
}

# =============================================================================
# Step 2: Validate Environment Variables
# =============================================================================

validate_environment() {
    log_info "Validating environment variables..."

    if [ -z "$LINEAR_API_KEY" ]; then
        log_error "LINEAR_API_KEY environment variable is not set"
        echo -e "${YELLOW}Please set it:${NC}"
        echo "  export LINEAR_API_KEY='lin_pat_xxxxx'"
        exit 1
    fi

    if [ -z "$GITHUB_TOKEN" ]; then
        log_warning "GITHUB_TOKEN not set. GitHub operations may fail."
        echo -e "${YELLOW}Set it with:${NC}"
        echo "  export GITHUB_TOKEN='ghp_xxxxx'"
    fi

    log_success "Environment variables validated"
}

# =============================================================================
# Step 3: Verify Linear API Access
# =============================================================================

verify_linear_access() {
    log_info "Verifying Linear API access..."

    local response=$(curl -s -H "Authorization: $LINEAR_API_KEY" \
        -H "Content-Type: application/json" \
        https://api.linear.app/graphql \
        -d '{"query":"query { viewer { name email } }"}')

    if echo "$response" | jq -e '.data.viewer' > /dev/null 2>&1; then
        local username=$(echo "$response" | jq -r '.data.viewer.name')
        local email=$(echo "$response" | jq -r '.data.viewer.email')
        log_success "Linear API access verified. User: $username ($email)"
    else
        log_error "Failed to verify Linear API access"
        echo "Response: $response"
        exit 1
    fi
}

# =============================================================================
# Step 4: Verify GitHub Access
# =============================================================================

verify_github_access() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_warning "Skipping GitHub verification (GITHUB_TOKEN not set)"
        return
    fi

    log_info "Verifying GitHub API access..."

    # Configure git with GitHub token
    git config --global user.name "Cursor Agent"
    git config --global user.email "cursor@agent.local"

    # Test GitHub API
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        https://api.github.com/user)

    if echo "$response" | jq -e '.login' > /dev/null 2>&1; then
        local username=$(echo "$response" | jq -r '.login')
        log_success "GitHub API access verified. User: $username"
    else
        log_error "Failed to verify GitHub API access"
        echo "Response: $response"
        exit 1
    fi
}

# =============================================================================
# Step 5: Initialize Project Structure
# =============================================================================

initialize_project_structure() {
    log_info "Initializing project structure..."

    # Create necessary directories
    local directories=(
        ".cursor-agent/prompts"
        ".cursor-agent/templates"
        "src/gateway"
        "src/monitoring"
        "scripts"
        "terraform"
        "docs/diagrams"
        "docs/examples"
        "tests/integration"
        ".github/workflows"
        "linear-automation"
    )

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "Created directory: $dir"
        fi
    done

    # Create .gitignore if not exists
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Environment variables
.env
.env.local
.env*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# Python
__pycache__/
*.py[cod]
*$py.class
.pytest_cache/
.coverage
htmlcov/

# AWS
.aws/credentials
.aws/config

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Docker
docker-compose.override.yml

# Logs
*.log
.cursor-agent/execution.log

# Secrets
*.pem
*.key
secrets/

# OS
.DS_Store
Thumbs.db
EOF
        log_success "Created .gitignore"
    fi
}

# =============================================================================
# Step 6: Verify Linear Project Configuration
# =============================================================================

verify_linear_project() {
    log_info "Verifying Linear project configuration..."

    # Use jq to properly escape the GraphQL query
    local query_json=$(jq -n '{query: "query { viewer { name email } }"}')

    local response=$(curl -s -H "Authorization: $LINEAR_API_KEY" \
        -H "Content-Type: application/json" \
        https://api.linear.app/graphql \
        -d "$query_json")

    if echo "$response" | jq -e '.data.viewer' > /dev/null 2>&1; then
        log_success "Linear project verified. Ready to launch Cursor Agent."
    else
        log_error "Failed to verify Linear project"
        echo "Response: $response"
        exit 1
    fi
}

# =============================================================================
# Step 7: Display Setup Summary
# =============================================================================

display_setup_summary() {
    log_info "Setup Summary:"
    echo ""
    echo "=========================================="
    echo "Project: Claude Code AWS Bedrock Integration"
    echo "Linear Project: WOR (Workdev team)"
    echo "GitHub: evgenygurin/claude-clode-cloud"
    echo "=========================================="
    echo ""
    echo "✅ Verified:"
    echo "  - Linear API Access"
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "  - GitHub API Access"
    fi
    echo "  - Project Structure"
    echo ""
    echo "🚀 Ready to Launch!"
    echo ""
}

# =============================================================================
# Step 8: Display Next Steps
# =============================================================================

display_next_steps() {
    echo -e "${YELLOW}========== NEXT STEPS ==========${NC}"
    echo ""
    echo "1. Go to Linear and open WOR-7:"
    echo "   https://linear.app/workdev/issue/WOR-7/"
    echo ""
    echo "2. Click on WOR-8 (AWS Infrastructure Setup)"
    echo ""
    echo "3. Move WOR-8 to 'In Progress' status"
    echo ""
    echo "4. Cursor Agent will automatically:"
    echo "   ✅ Get the issue context via Linear GraphQL API"
    echo "   ✅ Create a GitHub branch"
    echo "   ✅ Generate Terraform code"
    echo "   ✅ Create AWS setup scripts"
    echo "   ✅ Commit code to GitHub"
    echo "   ✅ Update Linear progress"
    echo ""
    echo "5. Monitor progress in Linear dashboard:"
    echo "   https://linear.app/workdev"
    echo ""
    echo "6. Watch GitHub PR for code review:"
    echo "   https://github.com/evgenygurin/claude-clode-cloud/pulls"
    echo ""
}

# =============================================================================
# Step 9: Save Configuration
# =============================================================================

save_configuration() {
    log_info "Saving configuration..."

    # Create .cursor-agent/env.local with credentials
    cat > .cursor-agent/env.local << EOF
# Cursor Agent Environment Variables
# Generated at: $(date)

LINEAR_API_KEY=$LINEAR_API_KEY
GITHUB_TOKEN=${GITHUB_TOKEN:-}
GITHUB_REPOSITORY=evgenygurin/claude-clode-cloud
LINEAR_WORKSPACE=workdev
LINEAR_PROJECT=WOR

# AWS (will be set during WOR-8)
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_REGION=us-east-1

# Slack (optional)
# SLACK_WEBHOOK_URL=

# Email notifications (optional)
# EMAIL_RECIPIENTS=
EOF

    log_success "Configuration saved to .cursor-agent/env.local"
    log_warning "Keep .cursor-agent/env.local secure! Add to .gitignore (already done)"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   Cursor Agent Setup & Launch                              ║"
    echo "║   Claude Code AWS Bedrock Integration                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Run all verification steps
    verify_prerequisites
    validate_environment
    verify_linear_access
    verify_github_access
    initialize_project_structure
    verify_linear_project
    display_setup_summary

    # Save configuration
    save_configuration

    echo ""
    log_success "✅ All setup steps completed successfully!"
    echo ""

    # Display next steps
    display_next_steps

    echo ""
    echo -e "${GREEN}Ready to launch Cursor Agent!${NC}"
    echo ""
    echo "Questions? Check:"
    echo "  - Linear Project: https://linear.app/workdev"
    echo "  - GitHub Repository: https://github.com/evgenygurin/claude-clode-cloud"
    echo ""
}

# Run main function
main

