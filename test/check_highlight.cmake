# The records of test/highlight/records.in must come out as the bytes of test/highlight/records.out.
execute_process(COMMAND ${HIGHLIGHT} INPUT_FILE ${DIR}/records.in OUTPUT_VARIABLE actual RESULT_VARIABLE status)
if(NOT status EQUAL 0)
  message(FATAL_ERROR "highlight ended with ${status}")
endif()
file(READ ${DIR}/records.out expected)
if(NOT actual STREQUAL expected)
  message(FATAL_ERROR "highlight gave:\n${actual}\nexpected:\n${expected}")
endif()
