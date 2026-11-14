// A value with a tab must fail the render, and the error must name the page and the fault.
#include "man_render.hpp"

#include <simdjson.h>

#include <cstdio>
#include <string>

namespace {

constexpr auto data = simdjson::compile_time::parse_json<R"json({"rows": [
  {"file": "x.3", "a": "x", "b": "x.3", "c": "date", "d": "source", "is_file": true, "is_sh": false, "is_name": false, "is_nf": false,
   "is_fi": false, "is_include": false, "is_sp": false, "is_sig": false, "is_line": false, "is_text": false, "is_pp": false,
   "is_tp": false, "is_ex": false, "is_see": false},
  {"file": "x.3", "a": "a\tb", "b": "", "c": "", "d": "", "is_file": false, "is_sh": false, "is_name": false, "is_nf": false,
   "is_fi": false, "is_include": false, "is_sp": false, "is_sig": false, "is_line": false, "is_text": true, "is_pp": false,
   "is_tp": false, "is_ex": false, "is_see": false}]})json">();

}

int main()
{
    const auto files = render_man(data.rows);
    if (files) {
        std::fputs("the render accepted a tab\n", stderr);
        return 1;
    }
    if (files.error().find("man page x.3: illegal_control_character") == std::string::npos) {
        std::fprintf(stderr, "the error is: %s\n", files.error().c_str());
        return 1;
    }
    return 0;
}
