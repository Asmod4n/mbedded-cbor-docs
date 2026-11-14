#include "pages.hpp"

#include <cerrno>
#include <cstdio>
#include <fstream>
#include <string>
#include <string_view>
#include <system_error>

namespace {

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
        for (const auto &entry : pages)
            write_file(std::string(argv[1]) + "/" + std::string(entry.name) + ".html", entry.make());
    }
    catch (const std::system_error &e) {
        std::fprintf(stderr, "write_pages: %s\n", e.what());
        return 1;
    }
    return 0;
}
