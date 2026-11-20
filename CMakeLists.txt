cmake_minimum_required(VERSION 3.25)
project(mbedded-cbor-docs LANGUAGES CXX)

include(FetchContent)
include(CTest)
include(GNUInstallDirs)

FetchContent_Declare(mbedded_cbor
  GIT_REPOSITORY https://github.com/Asmod4n/mbedded-cbor.git
  GIT_TAG claude/item-16-byte
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
set(DOCS_RECORDS ${CMAKE_BINARY_DIR}/records.txt)
set(DOCS_MARKED ${CMAKE_BINARY_DIR}/marked.txt)
set(DOCS_EXAMPLES ${CMAKE_BINARY_DIR}/examples.json)
set(DOCS_EXAMPLE_BYTES ${CMAKE_BINARY_DIR}/examples.bytes.json)
find_program(DOCS_NODE NAMES node nodejs REQUIRED)
set(DOCS_OUTPUT_DIR ${CMAKE_BINARY_DIR}/site)
set(DOCS_WASM ${DOCS_OUTPUT_DIR}/examples.wasm)
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

add_custom_command(
  OUTPUT ${DOCS_RECORDS}
  COMMAND ${DOCS_JQ} -L ${CMAKE_SOURCE_DIR}/jq -j --slurpfile groups ${CMAKE_SOURCE_DIR}/groups.json --slurpfile examples ${DOCS_EXAMPLES} --slurpfile bytes ${DOCS_EXAMPLE_BYTES} ${DOCS_TEST_ARGS} -f ${CMAKE_SOURCE_DIR}/jq/highlight.jq ${DOCS_JSON} > ${DOCS_RECORDS}
  DEPENDS ${DOCS_JSON} ${DOCS_EXAMPLE_BYTES} ${CMAKE_SOURCE_DIR}/jq/code.jq ${CMAKE_SOURCE_DIR}/jq/highlight.jq ${CMAKE_SOURCE_DIR}/jq/snippet.jq ${CMAKE_SOURCE_DIR}/jq/example.jq ${CMAKE_SOURCE_DIR}/groups.json
  COMMENT "The records of the C++ to colour"
  VERBATIM)
add_custom_command(
  OUTPUT ${DOCS_MARKED}
  COMMAND highlight < ${DOCS_RECORDS} > ${DOCS_MARKED}
  DEPENDS highlight ${DOCS_RECORDS}
  COMMENT "The C++ with its colours"
  VERBATIM)
add_custom_command(
  OUTPUT ${DOCS_EXAMPLES}
  COMMAND ${DOCS_JQ} -L ${CMAKE_SOURCE_DIR}/jq --slurpfile groups ${CMAKE_SOURCE_DIR}/groups.json -f ${CMAKE_SOURCE_DIR}/jq/examples.jq ${DOCS_JSON} > ${DOCS_EXAMPLES}
  DEPENDS ${DOCS_JSON} ${CMAKE_SOURCE_DIR}/jq/examples.jq ${CMAKE_SOURCE_DIR}/jq/example.jq ${CMAKE_SOURCE_DIR}/groups.json
  COMMENT "The examples that run"
  VERBATIM)
add_custom_command(
  OUTPUT ${DOCS_EXAMPLE_BYTES}
  COMMAND ${DOCS_NODE} ${CMAKE_SOURCE_DIR}/repl/bytes.mjs ${DOCS_WASM} ${DOCS_EXAMPLES} ${DOCS_EXAMPLE_BYTES}
  DEPENDS ${DOCS_WASM} ${DOCS_EXAMPLES} ${CMAKE_SOURCE_DIR}/repl/bytes.mjs ${CMAKE_SOURCE_DIR}/site/examples.mjs
  COMMENT "The bytes of the examples"
  VERBATIM)

execute_process(COMMAND git -C ${mbedded_cbor_SOURCE_DIR} log -1 --format=%cs OUTPUT_VARIABLE DOCS_COMMIT_DATE OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND git -C ${mbedded_cbor_SOURCE_DIR} log -1 --format=%h OUTPUT_VARIABLE DOCS_COMMIT OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
file(READ ${mbedded_cbor_SOURCE_DIR}/CMakeLists.txt DOCS_CBOR_CMAKE)
string(REGEX MATCH "project\\(mbedded-cbor VERSION ([0-9.]+)" DOCS_CBOR_PROJECT "${DOCS_CBOR_CMAKE}")
set(DOCS_CBOR_VERSION ${CMAKE_MATCH_1})
if(NOT DOCS_CBOR_VERSION)
  message(FATAL_ERROR "the version of mbedded-cbor is not in its project()")
endif()
set(DOCS_MAN_SOURCE "mbedded-cbor ${DOCS_CBOR_VERSION} ${DOCS_COMMIT}")

file(READ ${CMAKE_SOURCE_DIR}/groups.json DOCS_GROUPS_JSON)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/groups.json)
set(DOCS_PAGES index)
string(JSON DOCS_GROUP_COUNT LENGTH "${DOCS_GROUPS_JSON}" groups)
math(EXPR DOCS_LAST_GROUP "${DOCS_GROUP_COUNT} - 1")
foreach(i RANGE ${DOCS_LAST_GROUP})
  string(JSON group_name GET "${DOCS_GROUPS_JSON}" groups ${i} name)
  list(APPEND DOCS_PAGES ${group_name})
endforeach()
list(APPEND DOCS_PAGES console)

set(DOCS_TEMPLATES head foot entries group errors index man console)
set(DOCS_TEMPLATES_HPP ${CMAKE_BINARY_DIR}/templates.hpp)
set(templates_text "#pragma once\n#include <mustache/mustache.hpp>\n")
foreach(template IN LISTS DOCS_TEMPLATES)
  file(READ ${CMAKE_SOURCE_DIR}/templates/${template}.mustache template_text)
  string(APPEND templates_text "inline constexpr mustache::fixed_string template_${template}{R\"mustache(${template_text})mustache\"};\n")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/templates/${template}.mustache)
endforeach()
file(GENERATE OUTPUT ${DOCS_TEMPLATES_HPP} CONTENT "${templates_text}")

set(pages_text "#pragma once\n#include \"man_file.hpp\"\n#include <expected>\n#include <string_view>\n#include <vector>\n")
foreach(page IN LISTS DOCS_PAGES)
  string(MAKE_C_IDENTIFIER ${page} page_id)
  string(APPEND pages_text "std::string_view page_${page_id}();\nstd::expected<std::vector<man_file>, std::string> man_${page_id}();\n")
endforeach()
string(APPEND pages_text "struct page_function {\n    std::string_view name;\n    std::string_view (*make)();\n    std::expected<std::vector<man_file>, std::string> (*make_man)();\n};\ninline constexpr page_function pages[] = {\n")
foreach(page IN LISTS DOCS_PAGES)
  string(MAKE_C_IDENTIFIER ${page} page_id)
  string(APPEND pages_text "    {\"${page}\", page_${page_id}, man_${page_id}},\n")
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
    COMMAND ${DOCS_JQ} -L ${CMAKE_SOURCE_DIR}/jq --arg date ${DOCS_COMMIT_DATE} --arg source "${DOCS_MAN_SOURCE}" --arg page ${page} --slurpfile groups ${CMAKE_SOURCE_DIR}/groups.json --slurpfile examples ${DOCS_EXAMPLES} --slurpfile bytes ${DOCS_EXAMPLE_BYTES} --rawfile marked ${DOCS_MARKED} ${DOCS_TEST_ARGS}
            -f ${CMAKE_SOURCE_DIR}/jq/page.jq ${DOCS_JSON} > ${page_dir}/data.json
    DEPENDS ${DOCS_JSON} ${DOCS_MARKED} ${DOCS_EXAMPLE_BYTES} ${CMAKE_SOURCE_DIR}/jq/code.jq ${CMAKE_SOURCE_DIR}/jq/dedupe.jq ${CMAKE_SOURCE_DIR}/jq/html.jq ${CMAKE_SOURCE_DIR}/jq/page.jq ${CMAKE_SOURCE_DIR}/jq/man.jq ${CMAKE_SOURCE_DIR}/jq/snippet.jq ${CMAKE_SOURCE_DIR}/jq/example.jq ${CMAKE_SOURCE_DIR}/groups.json
    COMMENT "The data of the page ${page}"
    VERBATIM)
  add_custom_command(
    OUTPUT ${page_dir}/data.hpp
    COMMAND ${DOCS_JQ} -rf ${CMAKE_SOURCE_DIR}/jq/hpp.jq ${page_dir}/data.json > ${page_dir}/data.hpp
    DEPENDS ${page_dir}/data.json ${CMAKE_SOURCE_DIR}/jq/hpp.jq
    COMMENT "The data of the page ${page} as a header"
    VERBATIM)
  if(page STREQUAL "index" OR page STREQUAL "errors" OR page STREQUAL "console")
    set(page_template template_${page})
  else()
    set(page_template template_group)
  endif()
  add_library(page_${page_id} OBJECT src/page.cpp ${page_dir}/data.hpp)
  target_include_directories(page_${page_id} PRIVATE ${page_dir} ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/src ${mustache_SOURCE_DIR}/include)
  target_compile_features(page_${page_id} PRIVATE cxx_std_26)
  target_compile_definitions(page_${page_id} PRIVATE SIMDJSON_STATIC_REFLECTION=1 PAGE_FUNCTION=page_${page_id} PAGE_MAN_FUNCTION=man_${page_id} PAGE_TEMPLATE=${page_template})
  if(page STREQUAL "console")
    target_compile_definitions(page_${page_id} PRIVATE PAGE_WITHOUT_MAN=1)
  endif()
  target_compile_options(page_${page_id} PRIVATE -freflection -Wall -Wextra -Werror
    -fconstexpr-ops-limit=${DOCS_CONSTEXPR_OPS_LIMIT}
    -fconstexpr-loop-limit=${DOCS_CONSTEXPR_LOOP_LIMIT})
  target_link_libraries(page_${page_id} PRIVATE simdjson::simdjson)
  list(APPEND DOCS_OBJECTS $<TARGET_OBJECTS:page_${page_id}>)
endforeach()

add_executable(write_pages src/write_pages.cpp ${DOCS_OBJECTS})
target_include_directories(write_pages PRIVATE ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/src ${mustache_SOURCE_DIR}/include)
target_compile_features(write_pages PRIVATE cxx_std_26)
target_compile_options(write_pages PRIVATE -Wall -Wextra -Werror)
target_link_libraries(write_pages PRIVATE simdjson::simdjson)


set(DOCS_PAGE_FILES)
foreach(page IN LISTS DOCS_PAGES)
  list(APPEND DOCS_PAGE_FILES ${DOCS_OUTPUT_DIR}/${page}.html)
endforeach()
add_custom_command(
  OUTPUT ${DOCS_PAGE_FILES}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${DOCS_OUTPUT_DIR}
  COMMAND write_pages ${DOCS_OUTPUT_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/site/style.css ${CMAKE_SOURCE_DIR}/site/site.js ${CMAKE_SOURCE_DIR}/site/examples.mjs ${DOCS_OUTPUT_DIR}
  DEPENDS write_pages ${CMAKE_SOURCE_DIR}/site/style.css ${CMAKE_SOURCE_DIR}/site/site.js ${CMAKE_SOURCE_DIR}/site/examples.mjs
  COMMENT "The pages of the headers"
  VERBATIM)
file(GLOB_RECURSE DOCS_WASM_SOURCES ${CMAKE_SOURCE_DIR}/repl/*.cpp ${CMAKE_SOURCE_DIR}/repl/*.hpp)
add_custom_command(
  OUTPUT ${DOCS_WASM}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${DOCS_OUTPUT_DIR}
  COMMAND ${DOCS_CLANG} --target=wasm32-wasip1 -mexec-model=reactor -std=c++26 -O2 -fno-exceptions
          -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wold-style-cast -Wnull-dereference -Werror
          -idirafter /usr/include -I${mbedded_cbor_SOURCE_DIR}/include -I${mbedded_cbor_SOURCE_DIR}/test
          -Wl,--strip-all,--gc-sections -o ${DOCS_WASM} ${CMAKE_SOURCE_DIR}/repl/examples.cpp
  DEPENDS ${DOCS_WASM_SOURCES} ${DOCS_HEADERS}
  COMMENT "The library as WebAssembly for the examples"
  VERBATIM)
add_custom_target(docs ALL DEPENDS ${DOCS_PAGE_FILES} ${DOCS_WASM} ${DOCS_EXAMPLES})

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

find_program(DOCS_MANDOC mandoc REQUIRED)
add_test(NAME man_pages
  COMMAND ${CMAKE_COMMAND} -DMANDOC=${DOCS_MANDOC} -DMAN_DIR=${DOCS_OUTPUT_DIR}/man3 -DEXPECTED=${CMAKE_SOURCE_DIR}/test/expected/man.txt
          -P ${CMAKE_SOURCE_DIR}/test/check_man.cmake)

install(DIRECTORY ${DOCS_OUTPUT_DIR}/man3/ DESTINATION ${CMAKE_INSTALL_MANDIR}/man3 FILES_MATCHING PATTERN "*.3")
add_test(NAME man_install COMMAND ${CMAKE_COMMAND} --install ${CMAKE_BINARY_DIR} --prefix ${CMAKE_BINARY_DIR}/prefix)
set_tests_properties(man_install PROPERTIES FIXTURES_SETUP man_prefix)
add_test(NAME man_install_title
  COMMAND ${CMAKE_COMMAND} -E cat ${CMAKE_BINARY_DIR}/prefix/${CMAKE_INSTALL_MANDIR}/man3/cbor::lazy.3)
set_tests_properties(man_install_title PROPERTIES FIXTURES_REQUIRED man_prefix PASS_REGULAR_EXPRESSION "\\.TH \"cbor::lazy\" 3 ")

add_executable(man_render_error test/man_render_error.cpp)
target_include_directories(man_render_error PRIVATE ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/src ${mustache_SOURCE_DIR}/include)
target_compile_features(man_render_error PRIVATE cxx_std_26)
target_compile_definitions(man_render_error PRIVATE SIMDJSON_STATIC_REFLECTION=1)
target_compile_options(man_render_error PRIVATE -freflection -Wall -Wextra -Werror
  -fconstexpr-ops-limit=${DOCS_CONSTEXPR_OPS_LIMIT} -fconstexpr-loop-limit=${DOCS_CONSTEXPR_LOOP_LIMIT})
target_link_libraries(man_render_error PRIVATE simdjson::simdjson)
add_test(NAME man_render_error COMMAND man_render_error)

add_test(NAME jq_tab
  COMMAND ${CMAKE_COMMAND} -DCASE=tab "-DMUST_FAIL_WITH=tab: line 4: a byte outside printable ASCII" -DCLANG=${DOCS_CLANG} -DJQ=${DOCS_JQ}
          -DDIR=${CMAKE_SOURCE_DIR}/test/jq -DOUT=${CMAKE_BINARY_DIR} -DDOCS_JQ=${CMAKE_SOURCE_DIR}/jq/docs.jq -P ${CMAKE_SOURCE_DIR}/test/jq_case.cmake)

find_library(DOCS_CLANG_LIBRARY NAMES clang-23 clang REQUIRED PATHS /usr/lib/llvm-23/lib)
find_path(DOCS_CLANG_INCLUDE clang-c/Index.h REQUIRED PATHS /usr/lib/llvm-23/include)
add_executable(highlight src/highlight.cpp)
target_include_directories(highlight PRIVATE ${DOCS_CLANG_INCLUDE})
target_compile_features(highlight PRIVATE cxx_std_23)
target_compile_options(highlight PRIVATE -Wall -Wextra -Werror)
target_link_libraries(highlight PRIVATE ${DOCS_CLANG_LIBRARY})
add_test(NAME highlight_records
  COMMAND ${CMAKE_COMMAND} -DHIGHLIGHT=$<TARGET_FILE:highlight> -DDIR=${CMAKE_SOURCE_DIR}/test/highlight -P ${CMAKE_SOURCE_DIR}/test/check_highlight.cmake)

add_test(NAME examples_run
  COMMAND ${DOCS_NODE} ${CMAKE_SOURCE_DIR}/test/check_examples.mjs ${DOCS_WASM} ${DOCS_EXAMPLES} ${DOCS_OUTPUT_DIR} ${DOCS_HEADER_DIR}/error.hpp)
add_test(NAME links_of_the_site COMMAND ${DOCS_NODE} ${CMAKE_SOURCE_DIR}/test/check_links.mjs ${DOCS_OUTPUT_DIR})
add_test(NAME links_finds_a_broken_one COMMAND ${DOCS_NODE} ${CMAKE_SOURCE_DIR}/test/check_links.mjs ${CMAKE_SOURCE_DIR}/test/links/bad)
set_tests_properties(links_finds_a_broken_one PROPERTIES WILL_FAIL TRUE)

find_program(DOCS_CHROMIUM NAMES chromium chromium-browser REQUIRED)
add_test(NAME screens_of_the_site COMMAND ${DOCS_NODE} ${CMAKE_SOURCE_DIR}/test/check_screens.mjs ${DOCS_CHROMIUM} ${DOCS_OUTPUT_DIR})
add_test(NAME screens_finds_a_bad_page COMMAND ${DOCS_NODE} ${CMAKE_SOURCE_DIR}/test/check_screens.mjs ${DOCS_CHROMIUM} ${CMAKE_SOURCE_DIR}/test/screens/bad)
set_tests_properties(screens_finds_a_bad_page PROPERTIES WILL_FAIL TRUE)
