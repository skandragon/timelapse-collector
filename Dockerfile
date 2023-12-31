#
# Copyright 2023 Michael Graff
#
# Licensed under the Apache License, Version 2.0 (the "License")
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# Install the latest versions of our mods.  This is done as a separate step
# so it will pull from an image cache if possible, unless there are changes.
#
FROM --platform=${BUILDPLATFORM} golang:1.21-alpine AS buildmod
ENV CGO_ENABLED=0
RUN mkdir /build
WORKDIR /build
COPY go.mod .
COPY go.sum .
RUN go mod download

#
# Compile the code.
#
FROM buildmod AS build-binaries
COPY . .
ARG TARGETOS
ARG TARGETARCH
RUN mkdir /out
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-s -w" -o /out/timelapse-collector app/timelapse-collector/*.go
RUN ls -l /out

#
# Establish a base OS image used by all the applications.
#
FROM alpine:3 AS base-image
RUN apk update && apk upgrade && apk add ca-certificates curl jq ffmpeg && rm -rf /var/cache/apk/*
RUN update-ca-certificates
RUN mkdir /local /local/ca-certificates && rm -rf /usr/local/share/ca-certificates && ln -s  /local/ca-certificates /usr/local/share/ca-certificates
COPY docker/run.sh /app/run.sh
ENTRYPOINT ["/bin/sh", "/app/run.sh"]

#
# For a base image without an OS, this can be used:
#
#FROM scratch AS base-image
#COPY --from=alpine:3 /etc/ssl/cert.pem /etc/ssl/cert.pem

#
# Build the timelapse-collector image.  This should be a --target on docker build.
#
FROM base-image AS timelapse-collector-image
WORKDIR /app
COPY --from=build-binaries /out/timelapse-collector /app
ARG GIT_BRANCH
ENV GIT_BRANCH=${GIT_BRANCH}
ARG GIT_HASH
ENV GIT_HASH=${GIT_HASH}
EXPOSE 8090
CMD ["/app/timelapse-collector"]
