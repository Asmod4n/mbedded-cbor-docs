# Runs clang and docs.jq over test/jq/<CASE>.hpp and compares the entries with test/jq/<CASE>.json.
# A case with MUST_FAIL_WITH has no .json: docs.jq must fail with a message that holds that text.
execute_process(
  COMMAND ${CLANG} -std=c++26 -fsyntax-only -Xclang -ast-dump=json -Xclang -ast-dump-filter=cbor ${DIR}/${CASE}.hpp
  OUTPUT_FILE ${OUT}/${CASE}.ast.json
  RESULT_VARIABLE clang_status)
if(NOT clang_status EQUAL 0)
  message(FATAL_ERROR "clang failed on ${CASE}.hpp")
endif()
execute_process(
  COMMAND ${JQ} -n --rawfile src_${CASE} ${DIR}/${CASE}.hpp -f ${DOCS_JQ} ${OUT}/${CASE}.ast.json
  OUTPUT_FILE ${OUT}/${CASE}.docs.json
  ERROR_VARIABLE jq_error
  RESULT_VARIABLE jq_status)
if(MUST_FAIL_WITH)
  if(jq_status EQUAL 0)
    message(FATAL_ERROR "docs.jq accepted ${CASE}.hpp")
  endif()
  string(FIND "${jq_error}" "${MUST_FAIL_WITH}" at)
  if(at EQUAL -1)
    message(FATAL_ERROR "docs.jq failed with: ${jq_error}")
  endif()
  return()
endif()
if(NOT jq_status EQUAL 0)
  message(FATAL_ERROR "docs.jq failed on ${CASE}.hpp: ${jq_error}")
endif()
execute_process(
  COMMAND ${JQ} -e --slurpfile want ${DIR}/${CASE}.json
    ".entries as $got | $want[0] as $w | ($got | length) == ($w | length) and all(range(0; $w | length); . as $i | $w[$i] == ($got[$i] | with_entries(select(.key | in($w[$i])))))"
    ${OUT}/${CASE}.docs.json
  OUTPUT_QUIET
  RESULT_VARIABLE compare_status)
if(NOT compare_status EQUAL 0)
  execute_process(COMMAND ${JQ} -c ".entries" ${OUT}/${CASE}.docs.json OUTPUT_VARIABLE got)
  message(FATAL_ERROR "the entries of ${CASE}.hpp differ from ${CASE}.json; got: ${got}")
endif()
