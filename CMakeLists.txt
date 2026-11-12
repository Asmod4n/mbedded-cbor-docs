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

set(DOCS_CONSTEXPR_OPS_LIMIT 2000000000 CACHE STRING "the limit of the operations of a constant evaluation")
set(DOCS_CONSTEXPR_LOOP_LIMIT 2000000000 CACHE STRING "the limit of the iterations of a loop of a constant evaluation")

set(DOCS_HEADER_DIR ${mbedded_cbor_SOURCE_DIR}/include/cbor)
set(DOCS_AST ${CMAKE_BINARY_DIR}/cbor.ast.json)
set(DOCS_HPP ${CMAKE_BINARY_DIR}/docs.hpp)
set(DOCS_PAGE ${CMAKE_BINARY_DIR}/index.html)
file(WRITE ${CMAKE_BINARY_DIR}/all.cpp "#include <cbor/cbor.hpp>\n")
file(GLOB DOCS_HEADERS ${DOCS_HEADER_DIR}/*.hpp)
set(DOCS_SOURCE_ARGS)
foreach(header IN LISTS DOCS_HEADERS)
  get_filename_component(header_name ${header} NAME_WE)
  list(APPEND DOCS_SOURCE_ARGS --rawfile src_${header_name} ${header})
endforeach()

add_custom_command(
  OUTPUT ${DOCS_AST}
  COMMAND ${DOCS_CLANG} -std=c++26 -I${mbedded_cbor_SOURCE_DIR}/include -fsyntax-only
          -Xclang -ast-dump=json -Xclang -ast-dump-filter=cbor
          ${CMAKE_BINARY_DIR}/all.cpp > ${DOCS_AST}
  DEPENDS ${DOCS_HEADERS}
  COMMENT "The AST of the headers"
  VERBATIM)

add_custom_command(
  OUTPUT ${DOCS_HPP}
  COMMAND ${DOCS_JQ} -n ${DOCS_SOURCE_ARGS} -f ${CMAKE_SOURCE_DIR}/jq/docs.jq ${DOCS_AST} > ${CMAKE_BINARY_DIR}/docs.json
  COMMAND ${DOCS_JQ} -rf ${CMAKE_SOURCE_DIR}/jq/hpp.jq ${CMAKE_BINARY_DIR}/docs.json > ${DOCS_HPP}
  DEPENDS ${DOCS_AST} ${CMAKE_SOURCE_DIR}/jq/docs.jq ${CMAKE_SOURCE_DIR}/jq/hpp.jq
  COMMENT "The JSON of the comments as a header"
  VERBATIM)

add_executable(write_pages src/write_pages.cpp ${DOCS_HPP})
target_include_directories(write_pages PRIVATE ${CMAKE_BINARY_DIR} ${mustache_SOURCE_DIR}/include)
target_compile_features(write_pages PRIVATE cxx_std_26)
target_compile_definitions(write_pages PRIVATE SIMDJSON_STATIC_REFLECTION=1)
target_compile_options(write_pages PRIVATE -freflection -Wall -Wextra -Werror
  -fconstexpr-ops-limit=${DOCS_CONSTEXPR_OPS_LIMIT}
  -fconstexpr-loop-limit=${DOCS_CONSTEXPR_LOOP_LIMIT})
target_link_libraries(write_pages PRIVATE simdjson::simdjson)

add_custom_command(
  OUTPUT ${DOCS_PAGE}
  COMMAND write_pages ${CMAKE_BINARY_DIR}
  DEPENDS write_pages
  COMMENT "The page of the headers"
  VERBATIM)
add_custom_target(docs ALL DEPENDS ${DOCS_PAGE})

add_test(NAME page
  COMMAND ${CMAKE_COMMAND} -DPAGE=${DOCS_PAGE}
          "-DEXPECTED=<h2>cbor::lazy</h2>;<h2>cbor::lazy::view</h2>;static std::expected&lt;lazy, error&gt; view(;<h2>cbor::at_path</h2>;<h2>cbor::error</h2>;enum class error"
          -P ${CMAKE_SOURCE_DIR}/test/check_page.cmake)
