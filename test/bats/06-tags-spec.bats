#!/usr/bin/env bats

# These tests expect prebuild images with the tags:
# - duncdrum/existdb:exist-ci-debug 
# - duncdrum/existdb:exist-ci, and 
# - duncdrum/existdb:exist-ci

#  Unskip for local testing
@test "create debug container" {
    skip
    run docker build --build-arg DISTRO_TAG=debug --tag duncdrum/exist-ci:debug .
    [ "$status" -eq 0 ]
    run docker build --build-arg DISTRO_TAG=nonroot --tag duncdrum/exist-ci:nonroot .
    [ "$status" -eq 0 ]

}

# Uses pre-build images on CI
@test "busybox should respond on debug container" {
    result=$(docker run --entrypoint whoami --name busybox --rm duncdrum/existdb:exist-ci-debug)
    [ "$result" == "root" ]
}

@test "busybox should not respond on latest container" {
    run docker run --entrypoint whoami --name noshell --rm duncdrum/existdb:exist-ci
    [ "$status" -ne 0 ]
    [ "$output" != "root" ]
    # [ "$output" == 'docker: Error response from daemon: OCI runtime create failed: container_linux.go:380: starting container process caused: exec: "whoami": executable file not found in $PATH: unknown.' ]
}

@test "should use user on non-root container" {
    skip
    run docker run -it --entrypoint sh --name busybox --rm duncdrum/existdb:exist-ci-nonroot 
}

@test "should use root on latest container" {
    skip
    run docker run -it --entrypoint sh --name busybox --rm duncdrum/existdb:exist-ci
}