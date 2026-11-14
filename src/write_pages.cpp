#include "pages.hpp"

#include <cerrno>
#include <cstdio>
#include <filesystem>
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
    const std::string directory = argv[1];
    try {
        std::filesystem::create_directories(directory + "/man3");
        for (const auto &entry : pages) {
            write_file(directory + "/" + std::string(entry.name) + ".html", entry.make());
            const auto man = entry.make_man();
            if (!man) {
                std::fprintf(stderr, "write_pages: page %s: %s\n", std::string(entry.name).c_str(), man.error().c_str());
                return 1;
            }
            for (const auto &file : *man)
                write_file(directory + "/man3/" + file.name, file.text);
        }
    }
    catch (const std::system_error &e) {
        std::fprintf(stderr, "write_pages: %s\n", e.what());
        return 1;
    }
    return 0;
}
