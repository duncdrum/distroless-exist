#!/usr/bin/env bats

# Basic start-up and connection tests
# These tests expect a running container at port 8080 with the name "exist-ci"

@test "container jvm responds from client" {
  run docker exec exist-ci java -version
  [ "$status" -eq 0 ]
}

@test "container can be reached via http" {
  result=$(curl -Is http://127.0.0.1:8080/ | grep -o 'Jetty')
  [ "$result" == 'Jetty' ]
}

@test "container reports healthy to docker" {
  result=$(docker ps | grep -c 'healthy')
  [ "$result" -eq 2 ]
  #   result=$(docker ps | grep -o 'healthy')
  # [ "$result" == 'healthy' ]
}

@test "logs show clean start" {
  result=$(docker logs exist-ci | grep -o 'Server has started')
  [ "$result" == 'Server has started' ]
}

@test "logs are error free" {
  result=$(docker logs exist-ci | grep -ow -c 'ERROR' || true)
  [ "$result" -eq 0 ]
}

@test "no fatalities in logs" {
  result=$(docker logs exist | grep -ow -c 'FATAL' || true)
  [ "$result" -eq 0 ]
}

# Only appears on boot with non empty autodeploy directory
@test "logs contain repo.log output" {
  result=$(docker logs exist-ci | grep -o -m 1 'Deployment.java')
  [ "$result" == 'Deployment.java' ]
}

# Check for cgroup config warning 
@test "check logs for cgroup file warning" {
    result=$(docker logs exist-ci | grep -ow -c 'Unable to open cgroup memory limit file' || true )
  [ "$result" -eq 0 ]
}