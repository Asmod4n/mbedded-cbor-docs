# The page of one class must hold what the header says, and no empty row.
# A row that is padded to the longest list of all entries is hidden by its
# flag, so an empty list item or an empty code line is a fault.
file(READ "${PAGE}" text)
foreach(expected IN LISTS EXPECTED)
  string(FIND "${text}" "${expected}" at)
  if(at EQUAL -1)
    message(FATAL_ERROR "the page does not hold: ${expected}")
  endif()
endforeach()
foreach(forbidden IN ITEMS "<li></li>" "<code></code>")
  string(FIND "${text}" "${forbidden}" at)
  if(NOT at EQUAL -1)
    message(FATAL_ERROR "the page holds an empty row: ${forbidden}")
  endif()
endforeach()
