FROM mirror.gcr.io/library/golang:1.18-alpine AS build
ARG TARGETPLATFORM TARGETOS TARGETARCH
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN apk --no-cache add bash && \
    apk --no-cache add git && \
    rm -rf /var/cache/apk/*

# Install build depdencies for all supported arches
RUN apk --no-cache add libc6-compat device-mapper findutils build-base linux-headers bash wget  && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    rm -rf /var/cache/apk/*

# Install the extra depdencies to compile libpfm only on amd64.
# Also install zfs, but only on amd64 since it's not available on arm64.
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    apk --no-cache add zfs python3 cmake pkgconfig ndctl-dev && \
    apk --no-cache add thin-provisioning-tools --repository http://dl-3.alpinelinux.org/alpine/edge/main/ && \
    rm -rf /var/cache/apk/*; fi

RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
  wget https://sourceforge.net/projects/perfmon2/files/libpfm4/libpfm-4.11.0.tar.gz && \
  echo "112bced9a67d565ff0ce6c2bb90452516d1183e5  libpfm-4.11.0.tar.gz" | sha1sum -c  && \
  tar -xzf libpfm-4.11.0.tar.gz && \
  rm libpfm-4.11.0.tar.gz; fi

RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
  export DBG="-g -Wall" && \
  make -e -C libpfm-4.11.0 && \
  make install -C libpfm-4.11.0; fi

# Compile ipmctl for amd64
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    git clone -b v02.00.00.3820 https://github.com/intel/ipmctl/ && \
    cd ipmctl && \
    mkdir output && \
    cd output && \
    cmake -DRELEASE=ON -DCMAKE_INSTALL_PREFIX=/ -DCMAKE_INSTALL_LIBDIR=/usr/local/lib .. && \
    make -j all && \
    make install; fi

ADD . /go/src/github.com/google/cadvisor
WORKDIR /go/src/github.com/google/cadvisor

RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    GO_OS="$TARGETOS" GO_ARCH="$TARGETARCH" GO_FLAGS="-tags=libpfm,netgo,libipmctl" ./build/build.sh; fi

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    GO_OS="$TARGETOS" GO_ARCH="$TARGETARCH" ./build/build.sh; fi

FROM mirror.gcr.io/library/alpine:3.15
ARG TARGETPLATFORM TARGETOS TARGETARCH
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}
MAINTAINER dengnan@google.com vmarmol@google.com vishnuk@google.com jimmidyson@gmail.com stclair@google.com

RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    apk --no-cache add libc6-compat device-mapper findutils zfs ndctl && \
    apk --no-cache add thin-provisioning-tools --repository http://dl-3.alpinelinux.org/alpine/edge/main/ && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    rm -rf /var/cache/apk/*; fi

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    apk --no-cache add libc6-compat device-mapper findutils && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    rm -rf /var/cache/apk/*; fi

# Grab cadvisor,libpfm4 and libipmctl from "build" container (if they exist, only on amd64 currently)
COPY --from=build /usr/local/lib/libpfm.so* /usr/local/lib/
COPY --from=build /usr/local/lib/libipmctl.so* /usr/local/lib/
COPY --from=build /go/src/github.com/google/cadvisor/_output/cadvisor /usr/bin/cadvisor

EXPOSE 8080

ENV CADVISOR_HEALTHCHECK_URL=http://localhost:8080/healthz

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider $CADVISOR_HEALTHCHECK_URL || exit 1

ENTRYPOINT ["/usr/bin/cadvisor", "-logtostderr"]
