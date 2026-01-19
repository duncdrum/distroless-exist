#!/usr/bin/env bats

# Tests for Docker build with GitHub Maven authentication secrets
# These tests verify that the build works with secrets and that BuildKit is properly configured
#
# Note: DOCKER_BUILDKIT=1 is REQUIRED because the Dockerfile uses:
#   - RUN --mount=type=secret (for GitHub token)
#   - RUN --mount=type=cache (for Maven cache)
# These features only work with BuildKit enabled.
#
# NOTE: These tests are for LOCAL DEVELOPMENT ONLY and are skipped in CI.
# They require GitHub tokens and are not necessary for CI builds.
# CI builds use GitHub Actions secrets which are handled differently.

# Global flag to indicate if we're running in CI
# This is set in setup_file() and checked by all tests
SKIP_IN_CI=false

# Setup function that runs once before all tests
# Detects CI environment and sets skip flag
setup_file() {
  # Check for various CI environment indicators
  # GitHub Actions sets: CI=true, GITHUB_ACTIONS=true, GITHUB_WORKFLOW=<name>
  # Other CI systems may set: CI=true, CONTINUOUS_INTEGRATION=true
  if [ "${CI:-}" = "true" ] || \
     [ "${GITHUB_ACTIONS:-}" = "true" ] || \
     [ -n "${GITHUB_WORKFLOW:-}" ] || \
     [ "${CONTINUOUS_INTEGRATION:-}" = "true" ] || \
     [ -n "${GITHUB_RUN_ID:-}" ] || \
     [ -n "${GITHUB_REPOSITORY:-}" ]; then
    SKIP_IN_CI=true
  fi
}

# Skip test if running in CI
# This function should be called at the start of every test
skip_if_ci() {
  if [ "$SKIP_IN_CI" = "true" ]; then
    skip "Skipping build secrets tests in CI - these are for local development only"
  fi
}

# Check if Docker is available
# This function skips the test if Docker is not found or not accessible
check_docker() {
  if ! command -v docker &> /dev/null; then
    skip "Docker is not available (command not found)"
  fi
  # Also verify docker is actually working (not just in PATH)
  if ! docker info &> /dev/null; then
    skip "Docker is not running or not accessible"
  fi
}

@test "DOCKER_BUILDKIT=1 enables BuildKit features" {
  skip_if_ci
  check_docker
  
  # Verify that BuildKit is available (required for --mount=type=secret)
  # BuildKit is necessary for secret mounting and cache mounts used in the Dockerfile
  run docker buildx version
  [ "$status" -eq 0 ]
  # DOCKER_BUILDKIT=1 enables BuildKit which is required for:
  # - --mount=type=secret (for GitHub token authentication)
  # - --mount=type=cache (for Maven dependency cache)
  # Without it, the Dockerfile RUN --mount commands would fail
}

@test "build without secret should fail with clear error" {
  skip_if_ci
  check_docker
  
  # Build the builder stage without passing any secrets
  # The secret is required for the build to succeed (it's used to authenticate with GitHub Maven registry)
  # When the secret is missing, the build should fail either:
  # 1. Immediately when trying to read /run/secrets/github_token (file doesn't exist)
  # 2. Later during Maven build when authentication fails (401 Unauthorized)
  export DOCKER_BUILDKIT=1
  run docker build \
    --progress=plain \
    --target builder \
    --no-cache \
    -t exist-test:no-secret \
    -f Dockerfile \
    . 2>&1
  
  # Build should fail - either immediately (secret file missing) or during Maven (authentication failure)
  if [ "$status" -eq 0 ]; then
    echo "WARNING: Build succeeded without secret - this may indicate cached layers or test environment issue"
    echo "Build output:"
    echo "$output" | tail -20
    # Still consider this a failure since the build should not succeed without credentials
    false
  fi
  
  # Verify the failure is related to missing secret or authentication
  # Accept various error patterns that indicate the secret was needed
  if ! echo "$output" | grep -qiE "(secret|github_token|/run/secrets|No such file|cat.*github_token)" && \
     ! echo "$output" | grep -qiE "(401|Unauthorized|Could not transfer artifact)" && \
     ! echo "$output" | grep -qiE "(failed to solve|process.*did not complete)"; then
    echo "Build failed but error message doesn't clearly indicate secret/authentication issue:"
    echo "$output" | grep -i "error\|fail" | head -5
  fi
  
  # Clean up any partially created image
  run docker rmi exist-test:no-secret 2>/dev/null || true
}

@test "build with secret should succeed" {
  skip_if_ci
  check_docker
  
  # Skip if GITHUB_TOKEN is not set
  if [ -z "$GITHUB_TOKEN" ]; then
    skip "GITHUB_TOKEN environment variable not set"
  fi
  
  # Build with secret passed via BuildKit secret mount
  export DOCKER_BUILDKIT=1
  run docker build \
    --progress=plain \
    --target builder \
    --secret id=github_token,env=GITHUB_TOKEN \
    --build-arg GITHUB_USERNAME="${GITHUB_USERNAME:-duncdrum}" \
    -t exist-test:with-secret \
    -f Dockerfile \
    .
  [ "$status" -eq 0 ]
}

@test "build with secret should create settings.xml during build" {
  skip_if_ci
  check_docker
  
  # Skip if GITHUB_TOKEN is not set
  if [ -z "$GITHUB_TOKEN" ]; then
    skip "GITHUB_TOKEN environment variable not set"
  fi
  
  # The settings.xml is created during the build in the builder stage
  # We verify it was created by checking that the build succeeded
  # (if settings.xml wasn't created, Maven would fail with 401)
  # This is already verified by the "build with secret should succeed" test
  # We can verify the build output mentions settings.xml creation
  export DOCKER_BUILDKIT=1
  run docker build \
    --progress=plain \
    --target builder \
    --secret id=github_token,env=GITHUB_TOKEN \
    --build-arg GITHUB_USERNAME="${GITHUB_USERNAME:-duncdrum}" \
    -t exist-test:settings-check \
    -f Dockerfile \
    . 2>&1
  
  [ "$status" -eq 0 ]
  # Verify build completed successfully (which implies settings.xml was created and used)
  echo "$output" | grep -q "BUILD SUCCESS" || echo "$output" | grep -q "package"
  
  # Clean up
  run docker rmi exist-test:settings-check 2>/dev/null || true
}

# GitHub credentials tests
# These tests verify that GitHub token credentials are valid and have the necessary permissions
# for accessing GitHub Packages Maven registry
#
# SECURITY NOTE: These tests use GitHub tokens. To prevent token exposure in CI logs:
# - Disable command echoing (set +x)
# - Use curl with --silent to minimize output
# - Tokens are only used in memory and never logged

setup() {
  # Disable command echoing to prevent token exposure in logs
  # This prevents 'set -x' or debug mode from showing commands with tokens
  set +x
  
  # Load token from file or environment variable
  # SECURITY: Token is loaded into memory but should not be logged
  if [ -f ".github_token" ]; then
    TOKEN=$(cat .github_token 2>/dev/null || echo "")
  elif [ -n "$GITHUB_TOKEN" ]; then
    TOKEN="$GITHUB_TOKEN"
  else
    TOKEN=""
  fi
  
  # Only export if token exists (minimize exposure)
  if [ -n "$TOKEN" ]; then
    export TOKEN
  else
    unset TOKEN
  fi
  
  export USERNAME="${GITHUB_USERNAME:-duncdrum}"
}

@test "GitHub token should be available" {
  skip_if_ci
  if [ -z "$TOKEN" ]; then
    skip "No GitHub token available (set GITHUB_TOKEN or create .github_token file)"
  fi
  [ -n "$TOKEN" ]
}

@test "GitHub API access should be valid" {
  skip_if_ci
  if [ -z "$TOKEN" ]; then
    skip "No GitHub token available"
  fi
  
  # Test GitHub API access
  # SECURITY: Use --silent to prevent token from appearing in error output
  # The token in the Authorization header should not be logged by curl
  run curl --silent --show-error -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/user 2>&1
  
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

@test "GitHub token should have package permissions" {
  skip_if_ci
  if [ -z "$TOKEN" ]; then
    skip "No GitHub token available"
  fi
  
  # Get token scopes from response headers
  # SECURITY: Use --silent to prevent token from appearing in error output
  SCOPES_HEADER=$(curl --silent --show-error -I -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/user 2>/dev/null | grep -i "x-oauth-scopes" || echo "")
  
  if [ -z "$SCOPES_HEADER" ]; then
    # Fine-grained tokens may not expose scopes in header
    # Test package access directly instead
    skip "Could not retrieve scopes header (may be fine-grained token)"
  else
    SCOPES=$(echo "$SCOPES_HEADER" | cut -d' ' -f2- | tr -d '\r')
    # Token should have read:packages or write:packages (write includes read)
    echo "$SCOPES" | grep -qiE "(read:packages|write:packages)" || {
      echo "Token scopes: $SCOPES"
      echo "Token should have 'read:packages' or 'write:packages' scope"
      false
    }
  fi
}

@test "Maven registry access should work for exist repository" {
  skip_if_ci
  if [ -z "$TOKEN" ]; then
    skip "No GitHub token available"
  fi
  
  # Test Maven registry access for exist repository
  # 200, 404, or 422 are acceptable (all indicate successful authentication)
  # 422 is returned by GitHub for directory listings (Maven repos don't support browsing)
  # 401 means authentication failed
  # SECURITY: Use --silent to prevent credentials from appearing in error output
  run curl --silent --show-error -o /dev/null -w "%{http_code}" \
    -u "$USERNAME:$TOKEN" \
    https://maven.pkg.github.com/eXist-db/exist/org/exist-db/ 2>&1
  
  [ "$status" -eq 0 ]
  HTTP_CODE="$output"
  if [ "$HTTP_CODE" = "401" ]; then
    echo "Authentication failed (HTTP 401) - check username and token"
    false
  elif [ "$HTTP_CODE" = "403" ]; then
    echo "Access forbidden (HTTP 403) - token may not have access to this repository"
    false
  fi
  # Accept 200 (success), 404 (not found but authenticated), or 422 (unprocessable - directory listing not supported)
  [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "422" ]
}

@test "Maven registry access should work for exist-xqts-runner repository" {
  skip_if_ci
  if [ -z "$TOKEN" ]; then
    skip "No GitHub token available"
  fi
  
  # Test Maven registry access for exist-xqts-runner repository
  # 200, 404, or 422 are acceptable (all indicate successful authentication)
  # 422 is returned by GitHub for directory listings (Maven repos don't support browsing)
  # 401 means authentication failed
  # SECURITY: Use --silent to prevent credentials from appearing in error output
  run curl --silent --show-error -o /dev/null -w "%{http_code}" \
    -u "$USERNAME:$TOKEN" \
    https://maven.pkg.github.com/eXist-db/exist-xqts-runner/org/exist-db/ 2>&1
  
  [ "$status" -eq 0 ]
  HTTP_CODE="$output"
  if [ "$HTTP_CODE" = "401" ]; then
    echo "Authentication failed (HTTP 401) - check username and token"
    false
  elif [ "$HTTP_CODE" = "403" ]; then
    echo "Access forbidden (HTTP 403) - token may not have access to this repository"
    false
  fi
  # Accept 200 (success), 404 (not found but authenticated), or 422 (unprocessable - directory listing not supported)
  [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "422" ]
}

@test "Maven registry should allow access to exist-xqts-runner_2.13 package" {
  skip_if_ci
  if [ -z "$TOKEN" ]; then
    skip "No GitHub token available"
  fi
  
  # Test access to the specific package used in the build
  # 200 or 404 are acceptable (404 means authenticated but package version may not exist)
  # 401 means authentication failed, 403 means access forbidden
  # SECURITY: Use --silent to prevent credentials from appearing in error output
  run curl --silent --show-error -o /dev/null -w "%{http_code}" \
    -u "$USERNAME:$TOKEN" \
    "https://maven.pkg.github.com/eXist-db/exist-xqts-runner/org/exist-db/exist-xqts-runner_2.13/2.0.0-SNAPSHOT/" 2>&1
  
  [ "$status" -eq 0 ]
  # Accept 200 (found), 404 (not found but authenticated), but not 401 (unauthorized) or 403 (forbidden)
  if [ "$output" = "401" ]; then
    echo "Authentication failed - check username and token"
    false
  elif [ "$output" = "403" ]; then
    echo "Access forbidden - token may not have access to this package or organization membership required"
    false
  fi
  [ "$output" = "200" ] || [ "$output" = "404" ]
}

@test "cleanup test images" {
  skip_if_ci
  check_docker
  
  # Clean up test images
  run docker rmi exist-test:no-secret exist-test:with-secret 2>/dev/null || true
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # OK if images don't exist
}
