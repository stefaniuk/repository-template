#!/bin/bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for Docker functions.
#
# Usage:
#   $ ./docker.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

# Execute the Docker shell test suite.
function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/docker/docker.lib.sh
  cd ./scripts/docker/tests

  DOCKER_IMAGE=repository-template/docker-test
  DOCKER_TITLE="Repository Template Docker Test"

  test-suite-setup
  local tests=( \
    test-docker-build \
    test-docker-image-from-signature \
    test-docker-version-file \
    test-docker-test \
    test-docker-run \
    test-docker-clean \
    test-docker-get-image-version-and-pull \
  )
  local status=0
  for test in "${tests[@]}"; do
    {
      echo -n "$test"
      # shellcheck disable=SC2015
      $test && echo " PASS" || { echo " FAIL"; ((status++)); }
    }
  done
  echo "Total: ${#tests[@]}, Passed: $(( ${#tests[@]} - status )), Failed: $status"
  test-suite-teardown
  [ $status -gt 0 ] && return 1 || return 0
}

# ==============================================================================

# Set up suite-level fixtures.
function test-suite-setup() {

  :

  return 0
}

# Tear down suite-level fixtures.
function test-suite-teardown() {

  :

  return 0
}

# ==============================================================================

# Test Docker image build.
function test-docker-build() {

  # Arrange
  export BUILD_DATETIME="2023-09-04T15:46:34+0000"
  # Act
  docker-build > /dev/null 2>&1
  # Assert
  docker image inspect "${DOCKER_IMAGE}:$(_get-effective-version)" > /dev/null 2>&1 && return 0 || return 1
}

# Test replacement of `latest` image signatures.
function test-docker-image-from-signature() {

  # Arrange
  local tool_versions
  tool_versions="$(git rev-parse --show-toplevel)/scripts/docker/tests/.tool-versions.test"
  cp Dockerfile Dockerfile.effective
  # Act
  TOOL_VERSIONS="$tool_versions" _replace-image-latest-by-specific-version
  # Assert
  grep -q "FROM python:.*-alpine.*@sha256:.*" Dockerfile.effective && return 0 || return 1
}

# Test creation of effective version file.
function test-docker-version-file() {

  # Arrange
  export BUILD_DATETIME="2023-09-04T15:46:34+0000"
  # Act
  version-create-effective-file
  # Assert
  # shellcheck disable=SC2002
  (
      cat .version | grep -q "20230904-" &&
      cat .version | grep -q "2023.09.04-" &&
      cat .version | grep -q "somme-name-yyyyeah"
  ) && return 0 || return 1
}

# Test docker check helper command output.
function test-docker-test() {

  # Arrange
  local cmd="python --version"
  local check="Python"
  local output
  # Act
  output=$(cmd="$cmd" check="$check" docker-check-test)
  # Assert
  echo "$output" | grep -q "PASS" && return 0 || return 1
}

# Test docker run helper output.
function test-docker-run() {

  # Arrange
  local docker_cmd="python --version"
  local output
  # Act
  output=$(DOCKER_CMD="$docker_cmd" docker-run)
  # Assert
  echo "$output" | grep -Eq "Python [0-9]+\.[0-9]+\.[0-9]+" && return 0 || return 1
}

# Test cleanup of Docker image resources.
function test-docker-clean() {

  # Arrange
  local version
  version="$(_get-effective-version)"
  # Act
  docker-clean
  # Assert
  docker image inspect "${DOCKER_IMAGE}:${version}" > /dev/null 2>&1 && return 1 || return 0
}

# Test retrieval and pull of external image version.
function test-docker-get-image-version-and-pull() {

  # Arrange
  local name="ghcr.io/nhs-england-tools/github-runner-image"
  local match_version=".*-rt.*"
  # Act
  name="$name" match_version="$match_version" docker-get-image-version-and-pull > /dev/null 2>&1
  # Assert
  docker images \
    --filter=reference="$name" \
    --format "{{.Tag}}" \
  | grep -vq "<none>" && return 0 || return 1
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
# Arguments:
#   $1=[value to evaluate]
function is-arg-true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
