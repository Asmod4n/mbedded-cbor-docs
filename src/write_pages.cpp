#include "docs.hpp"

#include <mustache/mustache.hpp>
#include <simdjson.h>

#include <cerrno>
#include <cstdio>
#include <fstream>
#include <string>
#include <string_view>
#include <system_error>

#ifndef DOCS_CLASS_NAME
#error the name of the class is set by CMake
#endif

namespace {

constexpr auto make()
{
    return docs_json;
}

constexpr auto page = mustache::static_page_of<
    "<h1>{{title}}</h1>\n"
    "{{#entries}}<h2>{{name}}</h2>\n"
    "<pre>{{signature}}</pre>\n"
    "<p>{{brief}}</p>\n"
    "{{#errors}}{{#on}}<li>{{names}}</li>\n{{/on}}{{/errors}}"
    "{{#example}}{{#on}}<code>{{line}}</code>\n{{/on}}{{/example}}"
    "{{/entries}}",
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
        write_file(std::string(argv[1]) + "/" DOCS_CLASS_NAME ".html", std::string_view(page.data()));
    }
    catch (const std::system_error &e) {
        std::fprintf(stderr, "write_pages: %s\n", e.what());
        return 1;
    }
    return 0;
}
