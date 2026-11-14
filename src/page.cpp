#include "data.hpp"
#include "man_render.hpp"
#include "pages.hpp"
#include "templates.hpp"

#include <mustache/mustache.hpp>
#include <simdjson.h>

#include <string_view>

namespace {

constexpr auto make()
{
    return docs_json;
}

constexpr auto page = mustache::static_page_of<PAGE_TEMPLATE, make,
    mustache::static_partial<"head", template_head>, mustache::static_partial<"foot", template_foot>>;

}

std::expected<std::vector<man_file>, std::string> PAGE_MAN_FUNCTION()
{
    return render_man(docs_json.rows);
}

std::string_view PAGE_FUNCTION()
{
    return std::string_view(page.data());
}
