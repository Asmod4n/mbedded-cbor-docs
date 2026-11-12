# mbedded-cbor-docs

This repository makes the documentation of mbedded-cbor: one page of the
headers and, later, a page for each group and a man page for each group.

clang writes the AST of the headers as JSON. jq takes the comments and the
text of each declaration out of it and writes them as a JSON literal into a
header. A C++26 program reads that literal at compile time with simdjson and
renders the page with mbedded-mustache. The page is an array in the program.
The program write_pages writes it to a file.

CMake fetches the current mbedded-cbor from main.

## Build

    cmake -S . -B build -DCMAKE_CXX_COMPILER=g++-16
    cmake --build build
    ctest --test-dir build

The page is build/index.html. The limits of the constant evaluation are the
cache variables DOCS_CONSTEXPR_OPS_LIMIT and DOCS_CONSTEXPR_LOOP_LIMIT.
