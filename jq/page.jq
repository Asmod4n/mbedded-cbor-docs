def snippet($group): [ $ARGS.named | to_entries[] | select(.key | startswith("test_")) | .value | split("\n")[] ]
  | reduce .[] as $line ({inside: false, out: []};
      if ($line | test("^\\s*// \\[" + $group + " group\\]\\s*$")) then .inside |= not
      elif .inside then .out += [$line | sub("^    "; "")]
      else . end)
  | .out | join("\n");
def listed: [ $groups[0].groups[] | {name, title} ];
if $page == "index" then
  ($groups[0].index) + {name: "index", groups: listed}
else
  ($groups[0].groups | map(select(.name == $page)) | first) as $g
  | ([ .entries[] | select(.group == $page) | {qname, id, sigs, brief, body, example, has_body: (.body != ""), has_example: (.example != "")} ]) as $entries
  | if ($entries | length) == 0 then error("the group " + $page + " has no entry") else . end
  | {name: $page, title: ($page + " - mbedded-cbor"), brief: $g.title, groups: listed, snippet: snippet($page), has_snippet: (snippet($page) != ""), entries: $entries}
    + (if $page == "errors" then {errors: .errors} else {} end)
end
