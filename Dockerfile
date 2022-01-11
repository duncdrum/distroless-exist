FROM openjdk:11-jdk-slim-bullseye as builder

WORKDIR /usr/local
RUN apt-get update && apt-get install -y --no-install-recommends maven libsaxonb-java git
RUN git clone --depth 1 https://github.com/eXist-db/exist.git &&\
    cd exist &&\
    git checkout develop 
WORKDIR /usr/local/exist    
RUN mvn -T2C -V -B -q clean install -DskipTests -Ddependency-check.skip=true -Ddocker=false -P \!build-dist-archives,\!mac-dmg-on-mac,\!codesign-mac-dmg,\!mac-dmg-on-unix,\!installer,\!concurrency-stress-tests,\!micro-benchmarks,\!appassembler-booter
# RUN saxonb-xslt -s:dump/exist-distribution-5.3.1/etc/log4j2.xml -xsl:log4j2-docker.xslt -o:log4j2.xml