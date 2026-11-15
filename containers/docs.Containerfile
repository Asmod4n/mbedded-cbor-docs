FROM docker.io/library/debian:sid
RUN apt-get update \
 && apt-get install -y --no-install-recommends clang-23 libclang-23-dev g++-16 cmake ninja-build jq \
    libsimdjson-dev mandoc git ca-certificates lld-23 libc++-23-dev-wasm32 libc++abi-23-dev-wasm32 \
    libclang-rt-23-dev-wasm32 wasi-libc nodejs libboost-dev \
 && rm -rf /var/lib/apt/lists/*
