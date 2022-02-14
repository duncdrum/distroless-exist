#!/usr/bin/env bats

# Tests for modifying eXist's configuration files
# These tests expect a running container at port 8080 with the name "exist-ci"
# The test will create a temporary container "ex-mod" running on port 9090

@test "copy configuration file from container to disk" {
  run docker cp exist-ci:exist/etc/conf.xml ./conf.xml && [[ -e ./conf.xml ]] && ls -l ./conf.xml
  [ "$status" -eq 0 ]
}

@test "modify the copied config file" {
  run sed -i.bak 's/wait-before-shutdown="120000"/wait-before-shutdown="60000"/' ./conf.xml
  [ "$status" -eq 0 ]
}

# TODO(DP): this now works on CI and local, but it could be improved by using the pre-build images duncdrum/existdb:exist-ci when on CI
# keeping the current code for running on local. This would speed up CI runs quite a bit and avoid pesky volume limitations no different OS
@test "create modified image" {
  run docker create --name ex-mod -p 9090:8080 -v "$(pwd)"/exist/autodeploy:/exist/autodeploy duncdrum/existdb
  [ "$status" -eq 0 ]
  run docker cp ./conf.xml ex-mod:exist/etc/conf.xml
  [ "$status" -eq 0 ]
  run docker start ex-mod
  [ "$status" -eq 0 ]
}

@test "modification is applied in container" {
  # Make sure container is running
  result=$(docker ps | grep -o 'ex-mod')
  [ "$result" == 'ex-mod' ]
  sleep 10
  result=$(docker logs ex-mod | grep -o "60,000 ms during shutdown")
  [ "$result" == '60,000 ms during shutdown' ]
}

# TODO(DP): see https://github.com/eXist-db/exist/issues/2987 
#  modify MAX_CACHE via ARG and confirm result 

# TODO(DP): see https://github.com/eXist-db/exist/issues/1771
# upload xar with jar, and make see if it works

@test "teardown modified image" {
  run docker stop ex-mod
  [ "$status" -eq 0 ]
  [ "$output" == "ex-mod" ]
  run docker rm ex-mod
  [ "$status" -eq 0 ]
  [ "$output" == "ex-mod" ]
  run rm ./conf.xml
  [ "$status" -eq 0 ]
  run rm ./conf.xml.bak
  [ "$status" -eq 0 ]
}

@test "log queries to system are visible to docker" {
  run docker exec exist-ci java org.exist.start.Main client -q -u admin -P '' -x 'util:log-system-out("HELLO SYSTEM-OUT")'
  [ "$status" -eq 0 ]
  result=$(docker logs exist-ci | grep -o "HELLO SYSTEM-OUT" | head -1)
  [ "$result" == "HELLO SYSTEM-OUT" ]
}

@test "regular log queries are visible to docker" {
  run docker exec exist-ci java org.exist.start.Main client -q -u admin -P '' -x 'util:log("INFO", "HELLO logged INFO")'
  [ "$status" -eq 0 ]
  result=$(docker logs exist-ci | grep -o "HELLO logged INFO" | head -1)
  [ "$result" == "HELLO logged INFO" ]
}