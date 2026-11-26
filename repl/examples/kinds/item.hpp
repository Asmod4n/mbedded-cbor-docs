#pragma once

#include "lazy.hpp"

#include <array>
#include <functional>
#include <ranges>
#include <tuple>
#include <utility>

namespace site
{

inline std::string bytes_text(std::span<std::byte const> const bytes)
{
    return byte_count_text(bytes.size()) + hex_text(bytes);
}

template <>
struct kind<cbor::item> {
    static constexpr std::string_view name = "cbor::item";
    static std::string text(cbor::item const v)
    {
        return "item of " + item_notation(v);
    }
};

using item_elements = typename decltype(std::declval<cbor::item const &>().elements())::value_type;
using item_pairs = typename decltype(std::declval<cbor::item const &>().pairs())::value_type;

template <>
struct kind<item_elements> {
    static constexpr std::string_view name = "elements";
    static std::string text(item_elements const &v)
    {
        std::string out = number_text(v.size()) + (v.size() == 1 ? " element" : " elements");
        char const *separator = ": ";
        for (cbor::item const node : v) {
            out += separator + item_notation(node);
            separator = ", ";
        }
        return out;
    }
};

using item_entry = std::pair<cbor::item, cbor::item>;

template <>
struct kind<item_pairs> {
    static constexpr std::string_view name = "pairs";
    static std::string text(item_pairs const &v)
    {
        std::string out = number_text(v.size()) + (v.size() == 1 ? " pair" : " pairs");
        char const *separator = ": ";
        for (auto const [k, x] : v) {
            out += separator + item_notation(k) + ": " + item_notation(x);
            separator = ", ";
        }
        return out;
    }
};

template <>
struct kind<item_entry> {
    static constexpr std::string_view name = "std::pair<cbor::item, cbor::item>";
    static std::string text(item_entry const &v)
    {
        return "pair of " + item_notation(v.first) + " and " + item_notation(v.second);
    }
};

template <>
struct kind<std::pair<std::uint64_t, cbor::item>> {
    static constexpr std::string_view name = "std::pair<std::uint64_t, cbor::item>";
    static std::string text(std::pair<std::uint64_t, cbor::item> const &v)
    {
        return "pair of " + number_text(v.first) + " and " + kind<cbor::item>::text(v.second);
    }
};

template <>
struct kind<cbor::simple_value> {
    static constexpr std::string_view name = "cbor::simple_value";
    static std::string text(cbor::simple_value const v)
    {
        switch (v) {
        case cbor::simple_value::false_value:
            return "cbor::simple_value::false_value";
        case cbor::simple_value::true_value:
            return "cbor::simple_value::true_value";
        case cbor::simple_value::null:
            return "cbor::simple_value::null";
        case cbor::simple_value::undefined:
            return "cbor::simple_value::undefined";
        }
        return "cbor::simple_value{" + number_text(std::to_underlying(v)) + "}";
    }
};

template <>
struct kind<std::array<char, 16>> {
    static constexpr std::string_view name = "std::array<char, 16>";
    static std::string text(std::array<char, 16> const &v)
    {
        return string_text(std::string_view{std::span<char const>(v)});
    }
};

template <>
struct kind<std::array<std::uint8_t, 2>> {
    static constexpr std::string_view name = "std::array<std::uint8_t, 2>";
    static std::string text(std::array<std::uint8_t, 2> const &v)
    {
        return "{" + number_text(unsigned{v[0]}) + ", " + number_text(unsigned{v[1]}) + "}";
    }
};

template <>
struct kind<std::span<char>> {
    static constexpr std::string_view name = "std::span<char>";
    static std::string text(std::span<char> const v)
    {
        return bytes_text(std::as_bytes(v));
    }
};

template <>
struct kind<std::span<std::uint8_t, 2>> {
    static constexpr std::string_view name = "std::span<std::uint8_t, 2>";
    static std::string text(std::span<std::uint8_t, 2> const v)
    {
        return bytes_text(std::as_bytes(v));
    }
};

template <>
struct kind<std::span<std::byte const, 2>> {
    static constexpr std::string_view name = "std::span<std::byte const, 2>";
    static std::string text(std::span<std::byte const, 2> const v)
    {
        return bytes_text(v);
    }
};

template <>
struct kind<cbor::typed_array> {
    static constexpr std::string_view name = "cbor::typed_array";
    static std::string text(cbor::typed_array const &v)
    {
        return "typed_array of tag " + number_text(v.tag) + " over " + bytes_text(v.bytes);
    }
};

}
