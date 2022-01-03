#
# eXist-db Open Source Native XML Database
# Copyright (C) 2001 The eXist-db Authors
#
# info@exist-db.org
# http://www.exist-db.org
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#

# FROM openjdk:11-jdk-slim-bullseye as builder

# WORKDIR /usr/local
# RUN apt-get update && apt-get install -y --no-install-recommends maven libsaxonb-java

# RUN mvn -T2C clean install -DskipTests -Ddependency-check.skip=true -Ddocker=false -P skip-build-dist-archives,\!build-dist-archives,\!mac-dmg-on-mac,\!codesign-mac-dmg,\!mac-dmg-on-unix,\!installer,\!concurrency-stress-tests,\!micro-benchmarks,\!appassembler-booter
# RUN saxonb-xslt -s:dump/exist-distribution-5.3.1/etc/log4j2.xml -xsl:log4j2-docker.xslt -o:log4j2.xml

FROM gcr.io/distroless/java11-debian11:latest


# Copy eXist-db
COPY dump/exist-distribution-5.3.1/LICENSE /exist/LICENSE
COPY dump/exist-distribution-5.3.1/autodeploy /exist/autodeploy
COPY dump/exist-distribution-5.3.1/etc /exist/etc
COPY dump/exist-distribution-5.3.1/lib /exist/lib
COPY log4j2.xml /exist/etc


# Build-time metadata as defined at http://label-schema.org
# and used by autobuilder @hooks/build
# LABEL org.label-schema.build-date=${build-tstamp} \
#       org.label-schema.description="${project.description}" \
#       org.label-schema.name="existdb" \
#       org.label-schema.schema-version="1.0" \
#       org.label-schema.url="${project.url}" \
#       org.label-schema.vcs-ref=${build-commit-abbrev} \
#       org.label-schema.vcs-url="${project.scm.url}" \
#       org.label-schema.vendor="existdb"

EXPOSE 8080 8443

# make CACHE_MEM and MAX_BROKER available to users
ARG CACHE_MEM
ARG MAX_BROKER
ARG JVM_MAX_RAM_PERCENTAGE

ENV EXIST_HOME "/exist"
# ENV CLASSPATH=/exist/lib/${exist.uber.jar.filename}
ENV CLASSPATH=/exist/lib/*


ENV JAVA_TOOL_OPTIONS \
  -Dfile.encoding=UTF8 \
  -Dsun.jnu.encoding=UTF-8 \
  -Djava.awt.headless=true \
  -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M \
  -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20} \
  -Dlog4j.configurationFile=/exist/etc/log4j2.xml \
  -Dexist.home=/exist \
  -Dexist.configurationFile=/exist/etc/conf.xml \
  -Djetty.home=/exist \
  -Dexist.jetty.config=/exist/etc/jetty/standard.enabled-jetty-configs \
  -XX:+UseStringDeduplication \
  -XX:MaxRAMPercentage=${JVM_MAX_RAM_PERCENTAGE:-75.0} \
  -XX:MinRAMPercentage=${JVM_MAX_RAM_PERCENTAGE:-75.0} \
  -XX:+ExitOnOutOfMemoryError

HEALTHCHECK CMD [ "java", \
    "org.exist.start.Main", "client", \
    "--no-gui",  \
    "--user", "guest", "--password", "guest", \
    "--xpath", "system:get-version()" ]

ENTRYPOINT [ "java", \
    "org.exist.start.Main", "jetty" ]
