#!/bin/bash

# ============================================
# Test Script for deploy_container.sh
# ============================================
# Validates the deployment script without actually deploying
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

TEST_PASSED=0
TEST_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Testing: $test_name"
    
    if eval "$test_command"; then
        log_success "$test_name"
        ((TEST_PASSED++))
        return 0
    else
        log_error "$test_name"
        ((TEST_FAILED++))
        return 1
    fi
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🧪 Testing deploy_container.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Script exists and is executable
run_test "Script exists and is executable" \
    "test -x '$SCRIPT_DIR/deploy_container.sh'"

# Test 2: Script has valid bash syntax
run_test "Script has valid bash syntax" \
    "bash -n '$SCRIPT_DIR/deploy_container.sh'"

# Test 3: Script has correct shebang
run_test "Script has correct shebang" \
    "head -1 '$SCRIPT_DIR/deploy_container.sh' | grep -q '#!/bin/bash'"

# Test 4: Required commands are available
run_test "snow CLI is available" \
    "command -v snow >/dev/null 2>&1"

run_test "docker is available" \
    "command -v docker >/dev/null 2>&1"

run_test "jq is available" \
    "command -v jq >/dev/null 2>&1"

# Test 5: Docker daemon is running
run_test "Docker daemon is running" \
    "docker info >/dev/null 2>&1"

# Test 6: Required files exist
run_test "Backend Dockerfile exists" \
    "test -f '$PROJECT_ROOT/docker/Dockerfile.backend'"

run_test "Frontend Dockerfile exists" \
    "test -f '$PROJECT_ROOT/docker/Dockerfile.frontend'"

run_test "Backend directory exists" \
    "test -d '$PROJECT_ROOT/backend'"

run_test "Frontend directory exists" \
    "test -d '$PROJECT_ROOT/frontend'"

run_test "Backend package.json exists" \
    "test -f '$PROJECT_ROOT/backend/requirements.txt'"

run_test "Frontend package.json exists" \
    "test -f '$PROJECT_ROOT/frontend/package.json'"

# Test 7: Snowflake connection
log_info "Testing: Snowflake DEPLOYMENT connection"
if snow connection test --connection DEPLOYMENT >/dev/null 2>&1; then
    log_success "Snowflake DEPLOYMENT connection"
    ((TEST_PASSED++))
else
    log_warning "Snowflake DEPLOYMENT connection (optional for syntax testing)"
fi

# Test 8: Script contains expected functions
run_test "Script has validate_prerequisites function" \
    "grep -q 'validate_prerequisites()' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script has create_compute_pool function" \
    "grep -q 'create_compute_pool()' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script has create_image_repository function" \
    "grep -q 'create_image_repository()' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script has build_backend_image function" \
    "grep -q 'build_backend_image()' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script has build_frontend_image function" \
    "grep -q 'build_frontend_image()' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script has deploy_service function" \
    "grep -q 'deploy_service()' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script has main function" \
    "grep -q 'main()' '$SCRIPT_DIR/deploy_container.sh'"

# Test 9: Script has proper error handling
run_test "Script has 'set -e' for error handling" \
    "grep -q 'set -e' '$SCRIPT_DIR/deploy_container.sh'"

# Test 10: Script references correct paths
run_test "Script references PROJECT_ROOT variable" \
    "grep -q 'PROJECT_ROOT=' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script changes to PROJECT_ROOT directory" \
    "grep -q 'cd.*PROJECT_ROOT' '$SCRIPT_DIR/deploy_container.sh'"

# Test 11: Script has updated header
run_test "Script header mentions 'Container Services'" \
    "grep -q 'Container Services' '$SCRIPT_DIR/deploy_container.sh'"

# Test 12: Configuration variables are set
run_test "Script defines SNOWFLAKE_ACCOUNT" \
    "grep -q 'SNOWFLAKE_ACCOUNT=' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script defines DATABASE_NAME" \
    "grep -q 'DATABASE_NAME=' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script defines SERVICE_NAME" \
    "grep -q 'SERVICE_NAME=' '$SCRIPT_DIR/deploy_container.sh'"

run_test "Script defines COMPUTE_POOL_NAME" \
    "grep -q 'COMPUTE_POOL_NAME=' '$SCRIPT_DIR/deploy_container.sh'"

# Test 13: Check for common issues
run_test "Script doesn't reference old 'unified_service' name" \
    "! grep -i 'deploy_unified_service' '$SCRIPT_DIR/deploy_container.sh'"

# Test 14: Verify manage_services.sh exists (referenced in output)
run_test "manage_services.sh exists" \
    "test -f '$SCRIPT_DIR/manage_services.sh'"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 TEST RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}Passed:${NC} $TEST_PASSED"
echo -e "  ${RED}Failed:${NC} $TEST_FAILED"
echo ""

if [ $TEST_FAILED -eq 0 ]; then
    echo -e "  ${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "  The deploy_container.sh script is ready to use."
    echo ""
    echo "  To deploy:"
    echo "    cd deployment"
    echo "    ./deploy_container.sh"
    echo ""
    exit 0
else
    echo -e "  ${RED}❌ Some tests failed${NC}"
    echo ""
    echo "  Please fix the issues before deploying."
    echo ""
    exit 1
fi
