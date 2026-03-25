#!/usr/bin/env bats

# These tests expect a running container at port 8080 with the name "exist-ci"

@test "logs show use of incubator module" {
  result=$(docker logs exist-ci | grep -o 'Using incubator modules: jdk.incubator.vector')
  [ "$result" == 'Using incubator modules: jdk.incubator.vector' ]
}

@test "default model is present" {
  result=$(docker exec exist-ci ls /exist/onnx-models)
  [ "$result" == 'all-MiniLM-L6-v2' ]
}

@test "xquery vector module responds" {
  run docker exec exist-ci java org.exist.start.Main client -q -u admin -P '' -x 'vector:diagnostics()'
  [ "$status" -eq 0 ]
  [[ "$output" == *'id="all-MiniLM-L6-v2" source="builtin"'* ]]
}
