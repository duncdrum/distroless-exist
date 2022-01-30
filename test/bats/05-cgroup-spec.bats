#!/usr/bin/env bats

# These tests expect a running container at port 8080 with the name "exist-ci"
# These test will create a container "cgroup" running on port 8899

# create an empty named docker volume for use at startup -v no-auto:/exist/autodeploy

@test "create cgroup container" {
  run docker create -it -p 8899:8080  -m 1g --cpus="1.5" --name cgroup --rm duncdrum/existdb
  [ "$status" -eq 0 ]
  run docker start cgroup
  [ "$status" -eq 0 ]
  sleep 30
}

# Tests for modifying container memory
@test "memory flag is used at startup" {
  result=$(docker logs cgroup | grep -o -m 1 "Approximate maximum amount of memory for JVM: 1 GB")
  [ "$result" == 'Approximate maximum amount of memory for JVM: 1 GB' ]
}

# Tests for modifying container cpu shares
# Seems bugged, and use the value defined via daemon preferences instead
@test "cpu shares are used at startup" {
  skip
  result=$(docker logs cgroup | grep "Number of processors available to JVM: " | tail -c 4)
  [ "$status" -eq 0 ]
  ["$result" == '1.5' ]
}

# Check for cgroup config warning 
@test "check logs for cgroup file warning" {
  result=$(docker logs cgroup | grep -ow -c 'Unable to open cgroup memory limit file' || true )
  [ "$result" -eq 0 ]
}

@test "teardown cgroup container" {
    run docker stop cgroup
    [ "$status" -eq 0 ]
    [ "$output" == "cgroup" ] 
}