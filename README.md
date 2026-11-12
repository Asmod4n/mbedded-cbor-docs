# mbedded-cbor-docs

This repository makes the documentation of mbedded-cbor: a page for each
class and a man page for each group.

clang writes the AST of the headers as JSON. jq takes the comments and the
text of each declaration out of it and writes them as a JSON literal into a
header. A C++26 program reads that literal at compile time with simdjson and
renders the page with mbedded-mustache. The page leaves the compiler as an
array in the object file, and objcopy writes it to a file.

CMake fetches the current mbedded-cbor from main.

## Build

    cmake -S . -B build -DCMAKE_CXX_COMPILER=g++-16 -DDOCS_CLASS=lazy
    cmake --build build
    ctest --test-dir build

The page is build/lazy.html. The limits of the constant evaluation are the
cache variables DOCS_CONSTEXPR_OPS_LIMIT and DOCS_CONSTEXPR_LOOP_LIMIT.
