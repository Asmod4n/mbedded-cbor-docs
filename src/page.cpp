#include "docs.hpp"

#include <mustache/mustache.hpp>
#include <simdjson.h>

constexpr auto make()
{
    return docs_json;
}

[[gnu::section(".page_html"), gnu::used]] constexpr auto page = mustache::static_page_of<
    "<h1>{{title}}</h1>\n"
    "{{#entries}}<h2>{{name}}</h2>\n"
    "<pre>{{signature}}</pre>\n"
    "<p>{{brief}}</p>\n"
    "{{#errors}}{{#on}}<li>{{names}}</li>\n{{/on}}{{/errors}}"
    "{{#example}}{{#on}}<code>{{line}}</code>\n{{/on}}{{/example}}"
    "{{/entries}}",
    make>;

int main()
{
}
