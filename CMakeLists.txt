cmake_minimum_required(VERSION 3.25)
project(mbedded-cbor-docs LANGUAGES CXX)

include(FetchContent)
include(CTest)

FetchContent_Declare(mbedded_cbor
  GIT_REPOSITORY https://github.com/Asmod4n/mbedded-cbor.git
  GIT_TAG main
  SOURCE_SUBDIR no-cmake-project)
FetchContent_Declare(mustache
  GIT_REPOSITORY https://github.com/Asmod4n/mbedded-mustache.git
  GIT_TAG claude/troff-media-type
  SOURCE_SUBDIR no-cmake-project)
FetchContent_MakeAvailable(mbedded_cbor mustache)

find_package(simdjson REQUIRED)
find_program(DOCS_CLANG NAMES clang++-23 clang++ REQUIRED)
find_program(DOCS_JQ jq REQUIRED)
find_program(DOCS_OBJCOPY objcopy REQUIRED)

set(DOCS_CONSTEXPR_OPS_LIMIT 4000000000 CACHE STRING "the limit of the operations of a constant evaluation")
set(DOCS_CONSTEXPR_LOOP_LIMIT 1000000000 CACHE STRING "the limit of the iterations of a loop of a constant evaluation")
set(DOCS_CLASS lazy CACHE STRING "the class that the page documents")

set(DOCS_HEADER_DIR ${mbedded_cbor_SOURCE_DIR}/include/cbor)
set(DOCS_AST ${CMAKE_BINARY_DIR}/${DOCS_CLASS}.ast.json)
set(DOCS_HPP ${CMAKE_BINARY_DIR}/docs.hpp)
set(DOCS_PAGE ${CMAKE_BINARY_DIR}/${DOCS_CLASS}.html)
file(WRITE ${CMAKE_BINARY_DIR}/all.cpp "#include <cbor/cbor.hpp>\n")

add_custom_command(
  OUTPUT ${DOCS_AST}
  COMMAND ${DOCS_CLANG} -std=c++26 -I${mbedded_cbor_SOURCE_DIR}/include -fsyntax-only
          -Xclang -ast-dump=json -Xclang -ast-dump-filter=cbor::${DOCS_CLASS}
          ${CMAKE_BINARY_DIR}/all.cpp > ${DOCS_AST}
  DEPENDS ${DOCS_HEADER_DIR}/${DOCS_CLASS}.hpp
  COMMENT "The AST of cbor::${DOCS_CLASS}"
  VERBATIM)

add_custom_command(
  OUTPUT ${DOCS_HPP}
  COMMAND ${DOCS_JQ} -s --arg class ${DOCS_CLASS} --rawfile src ${DOCS_HEADER_DIR}/${DOCS_CLASS}.hpp
          -f ${CMAKE_SOURCE_DIR}/jq/docs.jq ${DOCS_AST} > ${CMAKE_BINARY_DIR}/docs.json
  COMMAND ${DOCS_JQ} -rf ${CMAKE_SOURCE_DIR}/jq/hpp.jq ${CMAKE_BINARY_DIR}/docs.json > ${DOCS_HPP}
  DEPENDS ${DOCS_AST} ${CMAKE_SOURCE_DIR}/jq/docs.jq ${CMAKE_SOURCE_DIR}/jq/hpp.jq
  COMMENT "The JSON of the comments as a header"
  VERBATIM)

add_library(page OBJECT src/page.cpp ${DOCS_HPP})
target_include_directories(page PRIVATE ${CMAKE_BINARY_DIR} ${mustache_SOURCE_DIR}/include)
target_compile_features(page PRIVATE cxx_std_26)
target_compile_definitions(page PRIVATE SIMDJSON_STATIC_REFLECTION=1)
target_compile_options(page PRIVATE -freflection -Wall -Wextra -Werror
  -fconstexpr-ops-limit=${DOCS_CONSTEXPR_OPS_LIMIT}
  -fconstexpr-loop-limit=${DOCS_CONSTEXPR_LOOP_LIMIT})
target_link_libraries(page PRIVATE simdjson::simdjson)

add_custom_command(
  OUTPUT ${DOCS_PAGE}
  COMMAND ${DOCS_OBJCOPY} -O binary --only-section=.page_html $<TARGET_OBJECTS:page> ${DOCS_PAGE}
  DEPENDS page
  COMMENT "The page of cbor::${DOCS_CLASS}"
  VERBATIM)
add_custom_target(docs ALL DEPENDS ${DOCS_PAGE})

add_test(NAME lazy_page
  COMMAND ${CMAKE_COMMAND} -DPAGE=${DOCS_PAGE}
          "-DEXPECTED=<h1>cbor::lazy</h1>;<h2>view</h2>;static std::expected&lt;lazy, error&gt; view(;<h2>adopt</h2>;<h2>at_path</h2>"
          -P ${CMAKE_SOURCE_DIR}/test/check_page.cmake)
