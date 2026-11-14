FROM docker.io/library/debian:sid
RUN apt-get update \
 && apt-get install -y --no-install-recommends clang-23 libclang-23-dev g++-16 cmake ninja-build jq \
    libsimdjson-dev mandoc git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
