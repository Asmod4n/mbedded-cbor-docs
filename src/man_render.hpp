#pragma once

#include "man_file.hpp"
#include "templates.hpp"

#include <mustache/mustache.hpp>

#include <expected>
#include <string>
#include <string_view>
#include <vector>

inline std::string_view fault_name(const mustache::Fault fault)
{
    switch (fault) {
        case mustache::Fault::none: return "none";
        case mustache::Fault::over_limit: return "over_limit";
        case mustache::Fault::not_text: return "not_text";
        case mustache::Fault::too_deep: return "too_deep";
        case mustache::Fault::over_work: return "over_work";
        case mustache::Fault::parse: return "parse";
        case mustache::Fault::no_memory: return "no_memory";
        case mustache::Fault::illegal_control_character: return "illegal_control_character";
    }
    return "unknown";
}

inline std::string render_error_text(const std::string_view file, const mustache::Error &error)
{
    return "man page " + std::string(file) + ": " + std::string(fault_name(error.fault)) + " " + std::string(error.what);
}

template <class Rows>
std::expected<std::vector<man_file>, std::string> render_man(const Rows &rows)
{
    std::vector<man_file> files;
    for (const auto &row : rows) {
        if (row.is_file) files.push_back({std::string(row.b), std::string()});
        if (files.empty()) return std::unexpected("a row of a man page comes before its first file row");
        auto text = mustache::render<template_man>(row, "text/troff");
        if (!text) return std::unexpected(render_error_text(std::string_view(row.file), text.error()));
        files.back().text += *text;
    }
    return files;
}
