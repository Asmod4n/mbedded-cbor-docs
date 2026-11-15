# mbedded-cbor-docs

The documentation of [mbedded-cbor](https://github.com/Asmod4n/mbedded-cbor): a site and man pages, made from the comments of its headers.

The site is at https://asmod4n.github.io/mbedded-cbor-docs/.

## What it makes

- One page for each group of the library, a start page and a console page, as HTML. Each example runs in the browser, in the library compiled to WebAssembly.
- One man page (section 3) for each public class, one for each group and one for the library: `cbor::lazy.3`, `mbedded-cbor-lazy.3`, `mbedded-cbor.3`.

## How

clang writes the AST of the headers as JSON. jq reads the comments and the declarations out of it. A C++26 program reads that data at compile time with simdjson and renders the pages with mbedded-mustache. The man pages are rendered with the media type `text/troff`. libclang gives the tokens for the colours of the C++.

CMake fetches the current mbedded-cbor from its main branch and mbedded-mustache at a fixed commit.

## Build

The container image in `containers/docs.Containerfile` holds every tool (Debian sid).

    podman build -t mbedded-cbor-docs -f containers/docs.Containerfile containers
    podman run --rm -v "$PWD":/work -w /work mbedded-cbor-docs sh -ec '
      cmake -S . -B build -G Ninja -DCMAKE_CXX_COMPILER=g++-16
      cmake --build build
      ctest --test-dir build --output-on-failure'

The site is `build/site`. The man pages are `build/site/man3`.

## Install the man pages

    cmake --install build --prefix /usr/local

This puts the pages into `share/man/man3`.

## Tests

`ctest` checks the data of the headers, each page, the man pages with `mandoc -T lint -W warning`, every example in the WebAssembly module, every link of the site, and the height and width of each page in a headless browser.

## CI

`.github/workflows/docs.yml` builds and tests on a push that changes a file of the build. On `main` it also publishes the site with GitHub Pages. A night run builds again, because a push to mbedded-cbor does not start a run here. It starts at a time between 00:13 and 03:43 UTC that the run of the night before drew.

GitHub turns off a schedule in a public repository after 60 days with no activity in it. To turn it on again, open the Actions tab and enable the workflow `docs`.
