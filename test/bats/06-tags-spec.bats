#!/usr/bin/env bats

# These tests expect prebuild images with the tags:
# - duncdrum/existdb:exist-ci running as exist-ci
# - duncdrum/existdb:exist-ci-debug , and 
# - duncdrum/existdb:exist-ci-nonroot running as nonroot

#  Unskip for local testing
@test "create debug container" {
    skip
    run docker build --build-arg DISTRO_TAG=debug --tag duncdrum/exist-ci:debug .
    [ "$status" -eq 0 ]
    run docker build --build-arg DISTRO_TAG=nonroot --build-arg USR=nonroot:nonroot --tag duncdrum/exist-ci:nonroot .
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
}

@test "should not use root on nonroot containers" {
    # run docker run -it --name nonroot --rm duncdrum/existdb:exist-ci-nonroot 
    # [ "$status" -ne 0 ]
    # sleep 10
    result=$(docker logs nonroot | grep -o "Running as user 'nonroot'")
    [ "$result" == "Running as user 'nonroot'" ] 
}

@test "should use root on latest container" {
    result=$(docker logs exist-ci | grep -o "Running as user 'root'")
    [ "$result" == "Running as user 'root'" ] 
}