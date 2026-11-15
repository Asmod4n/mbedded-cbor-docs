include "man";
include "snippet";
include "example";
def listed: [ $groups[0].groups[] | {name, title} ];
def marked: $ARGS.named.marked | split("\u001e");
. as $docs
| ($docs.entries | length) as $n
| ($groups[0].groups | length) as $count
| if $page == "index" then
  ($groups[0].index) + {name: "index", groups: listed, example_html: marked[2 * $n], rows: overview_page($groups[0].index; $groups[0].groups)}
elif $page == "console" then
  ($groups[0].console) + {name: "console", groups: listed, samples: [ $groups[0].console.samples | to_entries[] | . as $s | $s.value + {id: ("sample-" + ($s.key | tostring)), call_html: marked[2 * $n + 1 + $count + $s.key], has_failure: ($s.value.result | is_failure)} ]}
else
  ($groups[0].groups | map(.name) | index([$page])) as $gi
  | ($groups[0].groups[$gi]) as $g
  | ([ $docs.entries | to_entries[] | .key as $i | .value | select(.group == $page)
      | (spec) as $s
      | {qname, id, sigs_html: marked[$i], brief, body, example_html: marked[$n + $i],
         has_body: (.body != ""), has_example: (.example != "" and $s == null)} + play_fields ]) as $entries
  | if ($entries | length) == 0 then error("the group " + $page + " has no entry") else . end
  | snippet($page) as $snippet
  | ([ $docs.entries[] | select(.group == $page and (.kind | IN("CXXRecordDecl", "ClassTemplateDecl"))) ]) as $classes
  | {name: $page, title: ($page + " - mbedded-cbor"), brief: $g.title, groups: listed, snippet_html: marked[2 * $n + 1 + $gi], has_snippet: ($snippet != ""), entries: $entries,
     rows: (group_page($g; $docs.entries; $snippet) + ([ $classes[] | class_page(.; $docs.entries; $docs.errors; $page) ] | add // []))}
    + (if $page == "errors" then {errors: .errors} else {} end)
end
