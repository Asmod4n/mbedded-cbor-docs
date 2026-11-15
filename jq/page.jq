include "man";
include "snippet";
include "example";
include "dedupe";
include "html";
include "code";
def man_entry($examples; $bytes): (spec) as $s | example_item($examples; $bytes; .qname) as $item | if $s == null or $item == null then . else . + {example: (plain_code($s; $item; man_width) | join("\n"))} end;
def listed: [ $groups[0].groups[] | {name, title} ];
def marked: $ARGS.named.marked | split("\u001e");
. as $docs
| ($docs.entries | length) as $n
| ($docs.entries | map(man_entry($examples[0]; $bytes[0]))) as $man_entries
| ($groups[0].groups | length) as $count
| entries_deduped([ $groups[0].groups[] | .name as $name | $docs.entries[] | select(.group == $name) ]).out as $bodies
| briefs_deduped([ $groups[0].groups[] | .name as $name | $docs.entries[] | select(.group == $name) ]).out as $briefs
| if $page == "index" then
  ($groups[0].index) + {name: "index", groups: listed, example_html: marked[2 * $n], rows: overview_page($groups[0].index; $groups[0].groups)}
elif $page == "console" then
  ($groups[0].console) + {name: "console", groups: listed, samples: [ $groups[0].console.samples | to_entries[] | . as $s | $s.value + {id: ("sample-" + ($s.key | tostring)), call_html: marked[2 * $n + 1 + $count + $s.key], has_failure: ($s.value.result | is_failure)} ]}
else
  ($groups[0].groups | map(.name) | index([$page])) as $gi
  | ($groups[0].groups[$gi]) as $g
  | ([ $docs.entries | to_entries[] | .key as $i | .value | select(.group == $page)
      | (spec) as $s
      | {qname, id, sigs_html: marked[$i], brief_html: ($briefs[.id] // .brief | coded), body_html: ($bodies[.id] // "" | body_html(sentences_per_entry)), example_html: marked[$n + $i],
         has_body: (($bodies[.id] // "" | body_html(sentences_per_entry)) != ""), has_example: (.example != "" and $s == null)} + play_fields ]) as $entries
  | if ($entries | length) == 0 then error("the group " + $page + " has no entry") else . end
  | snippet($page) as $snippet
  | ([ $man_entries[] | select(.group == $page and (.kind | IN("CXXRecordDecl", "ClassTemplateDecl"))) ]) as $classes
  | {name: $page, title: ($page + " - mbedded-cbor"), brief: $g.title, groups: listed, snippet_html: marked[2 * $n + 1 + $gi], has_snippet: ($snippet != ""), entries: $entries,
     rows: (group_page($g; $man_entries; $snippet) + ([ $classes[] | class_page(.; $man_entries; $docs.errors; $page) ] | add // []))}
    + (if $page == "errors" then {errors: .errors} else {} end)
end
