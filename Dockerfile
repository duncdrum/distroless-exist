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
ARG FLAVOR=full

FROM maven:3-eclipse-temurin-21 AS builder
ARG BRANCH=develop
ARG GITHUB_USERNAME
# TODO (DP) add cache mount ?
RUN git clone --single-branch --branch=${BRANCH} --depth=1 https://github.com/eXist-db/exist.git
RUN mkdir no-auto

WORKDIR /exist
# Copy Maven settings template
COPY settings.xml.template /tmp/settings.xml.template
# Configure Maven settings.xml with GitHub authentication
# The secret is required for accessing GitHub Maven registry dependencies
# According to https://hub.docker.com/_/maven/, settings.xml in /usr/share/maven/ref/ is automatically used
# Yay for buildkit
# Create settings.xml and run Maven in the same step to ensure settings.xml is available
# The cache mount for /root/.m2 is set up, then we create settings.xml, then run mvn
RUN --mount=type=cache,id=maven,target=/root/.m2 \
    --mount=type=secret,id=github_token \
    sh -c 'mkdir -p /root/.m2 && \
        GITHUB_TOKEN=$(cat /run/secrets/github_token) && \
        GITHUB_USERNAME="${GITHUB_USERNAME:-duncdrum}" && \
        awk -v username="$GITHUB_USERNAME" -v token="$GITHUB_TOKEN" \
            "{gsub(/\\$\\{GITHUB_USERNAME\\}/, username); gsub(/\\$\\{GITHUB_TOKEN\\}/, token); print}" \
            /tmp/settings.xml.template > /root/.m2/settings.xml && \
        test -f /root/.m2/settings.xml || (echo "ERROR: settings.xml not found!" && exit 1) && \
        mvn -s /root/.m2/settings.xml -q -DskipTests -Ddocker=false -Ddependency-check.skip=true -Dmac.signing=false -Dizpack-signing=false -Denv.CI=true -P '\''!mac-dmg-on-unix,!installer,!concurrency-stress-tests,!micro-benchmarks'\'' package && \
        rm -f /root/.m2/settings.xml && \
        echo "Cleaned up settings.xml to prevent token exposure"'


FROM gcr.io/distroless/java21-debian13:${DISTRO_TAG} AS build_full
ARG USR=root
# Copy autodeploy folder from dist
ONBUILD COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/autodeploy /exist/autodeploy


FROM gcr.io/distroless/java21-debian13:${DISTRO_TAG} AS build_slim
ARG USR=root
ONBUILD COPY --from=builder --chown=${USR} /no-auto /exist/autodeploy


FROM build_${FLAVOR}
ARG USR=root
# Copy eXist-db
COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/LICENSE /exist/LICENSE
COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/etc /exist/etc
COPY --from=builder --chown=${USR} /exist/exist-distribution/target/exist-distribution-*-dir/lib /exist/lib
COPY --chown=${USR} log4j2.xml /exist/etc


EXPOSE 8080 8443

# make CACHE_MEM and MAX_BROKER available to users
ARG CACHE_MEM
ARG MAX_BROKER
ARG JVM_MAX_RAM_PERCENTAGE

ENV EXIST_HOME=/exist
ENV CLASSPATH=/exist/lib/*


ENV JAVA_TOOL_OPTIONS="\
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
  -XX:+ExitOnOutOfMemoryError"

USER ${USR}

HEALTHCHECK CMD [ "java", "org.exist.start.Main", "client", \
    "--no-gui",  \
    "--user", "guest", \
    "--password", "guest", \
    "--xpath", "system:get-version()" ]

ENTRYPOINT [ "java", "org.exist.start.Main"]

CMD ["jetty"]
