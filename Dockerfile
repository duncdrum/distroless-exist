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

ARG DISTRO_TAG=latest

FROM maven:3-eclipse-temurin-17 as builder
ARG BRANCH=develop

# TODO (DP) add cache mount ?
RUN git clone --single-branch --branch=${BRANCH} --depth=1 https://github.com/eXist-db/exist.git

WORKDIR /exist

# Yay for buildkit
RUN --mount=type=cache,id=maven,target=/root/.m2 \
mvn -q -DskipTests -Ddocker=false -Ddependency-check.skip=true -Dmac.signing=false -Dizpack-signing=false -Denv.CI=true -P '!mac-dmg-on-unix,!installer,!concurrency-stress-tests,!micro-benchmarks' package



FROM gcr.io/distroless/java17-debian12:${DISTRO_TAG}

ARG USR=root

# Copy eXist-db
COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/LICENSE /exist/LICENSE
COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/autodeploy /exist/autodeploy
COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/etc /exist/etc
COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/lib /exist/lib
COPY --chown=${USR} log4j2.xml /exist/etc


EXPOSE 8080 8443

# make CACHE_MEM and MAX_BROKER available to users
ARG CACHE_MEM
ARG MAX_BROKER
ARG JVM_MAX_RAM_PERCENTAGE

ENV EXIST_HOME "/exist"
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
  -XX:+UseNUMA \
  -XX:+UseZGC \
  -XX:+UseStringDeduplication \
  -XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=${JVM_MAX_RAM_PERCENTAGE:-75.0} \
  -XX:+ExitOnOutOfMemoryError

USER ${USR}

HEALTHCHECK CMD [ "java", "org.exist.start.Main", "client", \
    "--no-gui",  \
    "--user", "guest", \
    "--password", "guest", \
    "--xpath", "system:get-version()" ]

ENTRYPOINT [ "java", "org.exist.start.Main"]

CMD ["jetty"]