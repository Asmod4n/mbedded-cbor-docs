// Writes each record of standard input as HTML, with the tokens of libclang for the colours of the C++.
#include <clang-c/Index.h>

#include <cstdint>
#include <cstdio>
#include <iostream>
#include <iterator>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {

constexpr char record_separator = '\x1e';
constexpr char code_record = 'c';
constexpr char example_record = 'e';
constexpr std::string_view call_prompt = "> ";
constexpr std::string_view message_prefix = "message: ";
constexpr std::string_view bytes_prefix = "bytes: ";
constexpr std::string_view fault_prefix = "fault";
constexpr std::string_view unexpected_prefix = "unexpected";
constexpr char const *snippet_name = "snippet.cpp";
constexpr char const *language_arguments[] = {"-x", "c++", "-std=c++26"};

struct token {
    CXTokenKind kind;
    std::uint32_t offset;
    std::uint32_t length;
};

std::string_view class_of(const CXTokenKind kind)
{
    switch (kind) {
        case CXToken_Keyword: return "keyword";
        case CXToken_Literal: return "literal";
        case CXToken_Comment: return "comment";
        case CXToken_Punctuation:
        case CXToken_Identifier: return "";
    }
    return "";
}

std::string html_escaped(const std::string_view text)
{
    std::string out;
    for (const char c : text) {
        switch (c) {
            case '&': out += "&amp;"; break;
            case '<': out += "&lt;"; break;
            case '>': out += "&gt;"; break;
            default: out += c;
        }
    }
    return out;
}

std::uint32_t offset_of(const CXSourceLocation location)
{
    unsigned offset = 0;
    clang_getSpellingLocation(location, nullptr, nullptr, nullptr, &offset);
    return offset;
}

std::vector<token> tokens_read(const CXIndex index, const std::string_view text)
{
    CXUnsavedFile unsaved{snippet_name, text.data(), static_cast<unsigned long>(text.size())};
    CXTranslationUnit unit = nullptr;
    if (clang_parseTranslationUnit2(index, snippet_name, language_arguments, static_cast<int>(std::size(language_arguments)), &unsaved, 1,
                                    CXTranslationUnit_KeepGoing, &unit) != CXError_Success)
        throw std::runtime_error("libclang cannot parse a record");
    const CXFile file = clang_getFile(unit, snippet_name);
    const CXSourceRange whole = clang_getRange(clang_getLocationForOffset(unit, file, 0),
                                               clang_getLocationForOffset(unit, file, static_cast<unsigned>(text.size())));
    CXToken *found = nullptr;
    unsigned count = 0;
    clang_tokenize(unit, whole, &found, &count);
    std::vector<token> out;
    for (const CXToken &t : std::span(found, count)) {
        const CXSourceRange extent = clang_getTokenExtent(unit, t);
        const std::uint32_t begin = offset_of(clang_getRangeStart(extent));
        out.push_back({clang_getTokenKind(t), begin, offset_of(clang_getRangeEnd(extent)) - begin});
    }
    clang_disposeTokens(unit, found, count);
    clang_disposeTranslationUnit(unit);
    return out;
}

std::string code_highlighted(const CXIndex index, const std::string_view text)
{
    std::string out;
    std::uint32_t at = 0;
    for (const token &t : tokens_read(index, text)) {
        out += html_escaped(text.substr(at, t.offset - at));
        const std::string_view name = class_of(t.kind);
        if (name.empty())
            out += html_escaped(text.substr(t.offset, t.length));
        else
            out += "<span class=\"" + std::string(name) + "\">" + html_escaped(text.substr(t.offset, t.length)) + "</span>";
        at = t.offset + t.length;
    }
    return out + html_escaped(text.substr(at));
}

std::string line_highlighted(const CXIndex index, const std::string_view line)
{
    if (line.starts_with(call_prompt))
        return "<span class=\"call\">" + code_highlighted(index, line.substr(call_prompt.size())) + "</span>";
    if (line.starts_with(message_prefix) || line.starts_with(bytes_prefix))
        return "<span class=\"call\">" + html_escaped(line) + "</span>";
    const bool failed = line.starts_with(fault_prefix) || line.starts_with(unexpected_prefix);
    return std::string(failed ? "<span class=\"err\">" : "<span class=\"ok\">") + html_escaped(line) + "</span>";
}

std::string example_highlighted(const CXIndex index, const std::string_view text)
{
    std::string out;
    std::size_t at = 0;
    while (at <= text.size()) {
        const std::size_t end = text.find('\n', at);
        const std::string_view line = text.substr(at, end == std::string_view::npos ? end : end - at);
        if (!line.empty()) {
            if (!out.empty()) out += '\n';
            out += line_highlighted(index, line);
        }
        if (end == std::string_view::npos) break;
        at = end + 1;
    }
    return out;
}

std::string record_highlighted(const CXIndex index, const std::string_view record)
{
    if (record.empty()) return {};
    if (record.front() == code_record) return code_highlighted(index, record.substr(1));
    if (record.front() == example_record) return example_highlighted(index, record.substr(1));
    throw std::runtime_error("a record starts with neither c nor e");
}

}

int main()
{
    try {
        const std::string input{std::istreambuf_iterator<char>(std::cin), std::istreambuf_iterator<char>()};
        const CXIndex index = clang_createIndex(0, 0);
        std::string out;
        std::size_t at = 0;
        bool first = true;
        while (at <= input.size()) {
            const std::size_t end = input.find(record_separator, at);
            if (!first) out += record_separator;
            first = false;
            out += record_highlighted(index, std::string_view(input).substr(at, end == std::string::npos ? end : end - at));
            if (end == std::string::npos) break;
            at = end + 1;
        }
        clang_disposeIndex(index);
        std::cout << out;
        return std::cout ? 0 : 1;
    }
    catch (const std::exception &e) {
        std::fprintf(stderr, "highlight: %s\n", e.what());
        return 1;
    }
}
