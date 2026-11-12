"#pragma once\n#include <simdjson.h>\ninline constexpr auto docs_json = simdjson::compile_time::parse_json<R\"json(" + tojson + ")json\">();\n"
