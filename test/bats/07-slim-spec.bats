#!/usr/bin/env bats

# These tests expect prebuild images with the tags:
# - duncdrum/existdb:exist-ci running as exist-ci
# - duncdrum/existdb:exist-ci-debug , and 
# - duncdrum/existdb:exist-ci-nonroot running as nonroot
# - duncdrum/existdb:exist-ci-debug-slim as slim

#  Unskip for local testing
@test "create debug-slim container" {
    skip
    run docker build --build-arg DISTRO_TAG=debug --build-arg FLAVOR=slim --tag duncdrum/exist-ci:debug-slim .
    [ "$status" -eq 0 ]

}

# Uses pre-build images on CI
@test "autodeploy should be empty in container" {
    result=$(docker run --entrypoint ls -w /exist/autodeploy --name slim --rm duncdrum/existdb:exist-ci-debug-slim | wc -l)
    [ "$result" -eq 0 ]
}
