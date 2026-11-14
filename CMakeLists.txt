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
  GIT_TAG 138449e93b69b37acfbfa8515909feb8990213c8
  SOURCE_SUBDIR no-cmake-project)
FetchContent_MakeAvailable(mbedded_cbor mustache)

find_package(simdjson REQUIRED)
find_program(DOCS_CLANG NAMES clang++-23 clang++ REQUIRED)
find_program(DOCS_JQ jq REQUIRED)

set(DOCS_CONSTEXPR_OPS_LIMIT 2000000000 CACHE STRING "the limit of the operations of a constant evaluation")
set(DOCS_CONSTEXPR_LOOP_LIMIT 2000000000 CACHE STRING "the limit of the iterations of a loop of a constant evaluation")

set(DOCS_HEADER_DIR ${mbedded_cbor_SOURCE_DIR}/include/cbor)
set(DOCS_AST ${CMAKE_BINARY_DIR}/cbor.ast.json)
set(DOCS_JSON ${CMAKE_BINARY_DIR}/docs.json)
file(WRITE ${CMAKE_BINARY_DIR}/all.cpp "#include <cbor/cbor.hpp>\n")
file(GLOB DOCS_HEADERS ${DOCS_HEADER_DIR}/*.hpp)
file(GLOB DOCS_REFERENCE_TESTS ${mbedded_cbor_SOURCE_DIR}/test/doc_reference_*.cpp)
set(DOCS_SOURCE_ARGS)
foreach(header IN LISTS DOCS_HEADERS)
  get_filename_component(header_name ${header} NAME_WE)
  list(APPEND DOCS_SOURCE_ARGS --rawfile src_${header_name} ${header})
endforeach()
set(DOCS_TEST_ARGS)
foreach(test_file IN LISTS DOCS_REFERENCE_TESTS)
  get_filename_component(test_name ${test_file} NAME_WE)
  list(APPEND DOCS_TEST_ARGS --rawfile test_${test_name} ${test_file})
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
  OUTPUT ${DOCS_JSON}
  COMMAND ${DOCS_JQ} -n ${DOCS_SOURCE_ARGS} -f ${CMAKE_SOURCE_DIR}/jq/docs.jq ${DOCS_AST} > ${DOCS_JSON}
  DEPENDS ${DOCS_AST} ${CMAKE_SOURCE_DIR}/jq/docs.jq
  COMMENT "The JSON of the comments"
  VERBATIM)

file(READ ${CMAKE_SOURCE_DIR}/groups.json DOCS_GROUPS_JSON)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/groups.json)
set(DOCS_PAGES index)
string(JSON DOCS_GROUP_COUNT LENGTH "${DOCS_GROUPS_JSON}" groups)
math(EXPR DOCS_LAST_GROUP "${DOCS_GROUP_COUNT} - 1")
foreach(i RANGE ${DOCS_LAST_GROUP})
  string(JSON group_name GET "${DOCS_GROUPS_JSON}" groups ${i} name)
  list(APPEND DOCS_PAGES ${group_name})
endforeach()

set(DOCS_TEMPLATES head foot group errors index)
set(DOCS_TEMPLATES_HPP ${CMAKE_BINARY_DIR}/templates.hpp)
set(templates_text "#pragma once\n#include <mustache/mustache.hpp>\n")
foreach(template IN LISTS DOCS_TEMPLATES)
  file(READ ${CMAKE_SOURCE_DIR}/templates/${template}.mustache template_text)
  string(APPEND templates_text "inline constexpr mustache::fixed_string template_${template}{R\"mustache(${template_text})mustache\"};\n")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/templates/${template}.mustache)
endforeach()
file(GENERATE OUTPUT ${DOCS_TEMPLATES_HPP} CONTENT "${templates_text}")

set(pages_text "#pragma once\n#include <string_view>\n")
foreach(page IN LISTS DOCS_PAGES)
  string(MAKE_C_IDENTIFIER ${page} page_id)
  string(APPEND pages_text "std::string_view page_${page_id}();\n")
endforeach()
string(APPEND pages_text "struct page_function {\n    std::string_view name;\n    std::string_view (*make)();\n};\ninline constexpr page_function pages[] = {\n")
foreach(page IN LISTS DOCS_PAGES)
  string(MAKE_C_IDENTIFIER ${page} page_id)
  string(APPEND pages_text "    {\"${page}\", page_${page_id}},\n")
endforeach()
string(APPEND pages_text "};\n")
file(GENERATE OUTPUT ${CMAKE_BINARY_DIR}/pages.hpp CONTENT "${pages_text}")

set(DOCS_OBJECTS)
foreach(page IN LISTS DOCS_PAGES)
  string(MAKE_C_IDENTIFIER ${page} page_id)
  set(page_dir ${CMAKE_BINARY_DIR}/pages/${page})
  file(MAKE_DIRECTORY ${page_dir})
  add_custom_command(
    OUTPUT ${page_dir}/data.json
    COMMAND ${DOCS_JQ} --arg page ${page} --slurpfile groups ${CMAKE_SOURCE_DIR}/groups.json ${DOCS_TEST_ARGS}
            -f ${CMAKE_SOURCE_DIR}/jq/page.jq ${DOCS_JSON} > ${page_dir}/data.json
    DEPENDS ${DOCS_JSON} ${CMAKE_SOURCE_DIR}/jq/page.jq ${CMAKE_SOURCE_DIR}/groups.json
    COMMENT "The data of the page ${page}"
    VERBATIM)
  add_custom_command(
    OUTPUT ${page_dir}/data.hpp
    COMMAND ${DOCS_JQ} -rf ${CMAKE_SOURCE_DIR}/jq/hpp.jq ${page_dir}/data.json > ${page_dir}/data.hpp
    DEPENDS ${page_dir}/data.json ${CMAKE_SOURCE_DIR}/jq/hpp.jq
    COMMENT "The data of the page ${page} as a header"
    VERBATIM)
  if(page STREQUAL "index" OR page STREQUAL "errors")
    set(page_template template_${page})
  else()
    set(page_template template_group)
  endif()
  add_library(page_${page_id} OBJECT src/page.cpp ${page_dir}/data.hpp)
  target_include_directories(page_${page_id} PRIVATE ${page_dir} ${CMAKE_BINARY_DIR} ${mustache_SOURCE_DIR}/include)
  target_compile_features(page_${page_id} PRIVATE cxx_std_26)
  target_compile_definitions(page_${page_id} PRIVATE SIMDJSON_STATIC_REFLECTION=1 PAGE_FUNCTION=page_${page_id} PAGE_TEMPLATE=${page_template})
  target_compile_options(page_${page_id} PRIVATE -freflection -Wall -Wextra -Werror
    -fconstexpr-ops-limit=${DOCS_CONSTEXPR_OPS_LIMIT}
    -fconstexpr-loop-limit=${DOCS_CONSTEXPR_LOOP_LIMIT})
  target_link_libraries(page_${page_id} PRIVATE simdjson::simdjson)
  list(APPEND DOCS_OBJECTS $<TARGET_OBJECTS:page_${page_id}>)
endforeach()

add_executable(write_pages src/write_pages.cpp ${DOCS_OBJECTS})
target_include_directories(write_pages PRIVATE ${CMAKE_BINARY_DIR})
target_compile_features(write_pages PRIVATE cxx_std_26)
target_compile_options(write_pages PRIVATE -Wall -Wextra -Werror)
target_link_libraries(write_pages PRIVATE simdjson::simdjson)

set(DOCS_OUTPUT_DIR ${CMAKE_BINARY_DIR}/site)
set(DOCS_PAGE_FILES)
foreach(page IN LISTS DOCS_PAGES)
  list(APPEND DOCS_PAGE_FILES ${DOCS_OUTPUT_DIR}/${page}.html)
endforeach()
add_custom_command(
  OUTPUT ${DOCS_PAGE_FILES}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${DOCS_OUTPUT_DIR}
  COMMAND write_pages ${DOCS_OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/site/style.css ${DOCS_OUTPUT_DIR}/style.css
  DEPENDS write_pages ${CMAKE_SOURCE_DIR}/site/style.css
  COMMENT "The pages of the headers"
  VERBATIM)
add_custom_target(docs ALL DEPENDS ${DOCS_PAGE_FILES})

foreach(page IN LISTS DOCS_PAGES)
  add_test(NAME page_${page}
    COMMAND ${CMAKE_COMMAND} -DPAGE=${DOCS_OUTPUT_DIR}/${page}.html -DEXPECTED=${CMAKE_SOURCE_DIR}/test/expected/${page}.txt
            -P ${CMAKE_SOURCE_DIR}/test/check_page.cmake)
endforeach()
add_test(NAME page_prose_repeats
  COMMAND ${CMAKE_COMMAND} -DPAGES=${DOCS_PAGE_FILES} -P ${CMAKE_SOURCE_DIR}/test/check_repeats.cmake)
add_test(NAME docs_json_counts
  COMMAND ${DOCS_JQ} -e ".counts.entries + .counts.skipped == .counts.ast" ${DOCS_JSON})
add_test(NAME docs_json_one_signature_each
  COMMAND ${DOCS_JQ} -e "[.entries[] | (.sigs | split(\"\\n\")) as $lines | ($lines | length) == ($lines | unique | length)] | all" ${DOCS_JSON})
add_test(NAME docs_json_group_of_each_entry
  COMMAND ${DOCS_JQ} -e --slurpfile groups ${CMAKE_SOURCE_DIR}/groups.json "[.entries[] | .group as $g | $groups[0].groups | map(.name) | index([$g]) != null] | all" ${DOCS_JSON})

foreach(case IN ITEMS overloads constructor macros comment)
  add_test(NAME jq_${case}
    COMMAND ${CMAKE_COMMAND} -DCASE=${case} -DCLANG=${DOCS_CLANG} -DJQ=${DOCS_JQ} -DDIR=${CMAKE_SOURCE_DIR}/test/jq
            -DOUT=${CMAKE_BINARY_DIR} -DDOCS_JQ=${CMAKE_SOURCE_DIR}/jq/docs.jq -P ${CMAKE_SOURCE_DIR}/test/jq_case.cmake)
endforeach()
add_test(NAME jq_nonascii
  COMMAND ${CMAKE_COMMAND} -DCASE=nonascii "-DMUST_FAIL_WITH=nonascii: line 5: a byte outside printable ASCII" -DCLANG=${DOCS_CLANG} -DJQ=${DOCS_JQ}
          -DDIR=${CMAKE_SOURCE_DIR}/test/jq -DOUT=${CMAKE_BINARY_DIR} -DDOCS_JQ=${CMAKE_SOURCE_DIR}/jq/docs.jq -P ${CMAKE_SOURCE_DIR}/test/jq_case.cmake)
