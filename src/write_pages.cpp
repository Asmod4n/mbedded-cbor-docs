#include "docs.hpp"

#include <mustache/mustache.hpp>
#include <simdjson.h>

#include <cerrno>
#include <cstdio>
#include <fstream>
#include <string>
#include <string_view>
#include <system_error>

namespace {

constexpr auto make()
{
    return docs_json;
}

constexpr auto page = mustache::static_page_of<
    "<h1>{{title}}</h1>\n"
    "{{#entries}}<h2>{{scope}}::{{name}}</h2>\n"
    "<pre>{{sigs}}</pre>\n"
    "<p>{{brief}}</p>\n"
    "{{#call}}<pre>&gt; {{call}}\n{{result}}</pre>\n{{/call}}"
    "{{/entries}}"
    "<h2>Errors</h2>\n"
    "{{#errors}}<h3>{{scope}}</h3>\n<pre>{{names}}</pre>\n{{/errors}}",
    make>;

void write_file(const std::string &path, const std::string_view text)
{
    std::ofstream out(path, std::ios::binary);
    out.write(text.data(), static_cast<std::streamsize>(text.size()));
    out.flush();
    if (!out) throw std::system_error(errno, std::generic_category(), path);
}

}

int main(const int argc, const char *const *const argv)
{
    if (argc != 2) {
        std::fputs("usage: write_pages <output directory>\n", stderr);
        return 2;
    }
    try {
        write_file(std::string(argv[1]) + "/index.html", std::string_view(page.data()));
    }
    catch (const std::system_error &e) {
        std::fprintf(stderr, "write_pages: %s\n", e.what());
        return 1;
    }
    return 0;
}
