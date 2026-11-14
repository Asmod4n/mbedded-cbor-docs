include "man";
def snippet($group): [ $ARGS.named | to_entries[] | select(.key | startswith("test_")) | .value | split("\n")[] ]
  | reduce .[] as $line ({inside: false, out: []};
      if ($line | test("^\\s*// \\[" + $group + " group\\]\\s*$")) then .inside |= not
      elif .inside then .out += [$line | sub("^    "; "")]
      else . end)
  | .out | join("\n");
def listed: [ $groups[0].groups[] | {name, title} ];
. as $docs
| if $page == "index" then
  ($groups[0].index) + {name: "index", groups: listed, rows: overview_page($groups[0].index; $groups[0].groups)}
else
  ($groups[0].groups | map(select(.name == $page)) | first) as $g
  | ([ .entries[] | select(.group == $page) | {qname, id, sigs, brief, body, example, has_body: (.body != ""), has_example: (.example != "")} ]) as $entries
  | if ($entries | length) == 0 then error("the group " + $page + " has no entry") else . end
  | snippet($page) as $snippet
  | ([ $docs.entries[] | select(.group == $page and (.kind | IN("CXXRecordDecl", "ClassTemplateDecl"))) ]) as $classes
  | {name: $page, title: ($page + " - mbedded-cbor"), brief: $g.title, groups: listed, snippet: $snippet, has_snippet: ($snippet != ""), entries: $entries,
     rows: (group_page($g; $docs.entries; $snippet) + ([ $classes[] | class_page(.; $docs.entries; $docs.errors; $page) ] | add // []))}
    + (if $page == "errors" then {errors: .errors} else {} end)
end
