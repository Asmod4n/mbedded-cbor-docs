def hex_bytes: split(" ") | map(select(. != ""));
def literal_lines($hex): [ $hex | hex_bytes | . as $b | range(0; length; 16) as $i | "    \"" + ($b[$i:($i + 16)] | map("\\x" + .) | join("")) + "\"" ];
def uses($calls; $word): ($calls | map(.call) | join("\n")) | test("\\b" + $word + "\\b");
def without_strings: gsub("\"(?:[^\"\\\\]|\\\\.)*\""; "\"\"");
def key_of: .ns + "::" + .name;
def closed($all; $keys): ([ $keys[] as $k | $all[] | select(key_of == $k) | .uses[] ] + $keys | unique) as $n
  | if ($n | length) == ($keys | length) then $keys else closed($all; $n) end;
def type_lines($spec; $group):
  ([ $groups[0].groups[] | select(.name == $group) | .types // empty ] | first) as $ns
  | if $ns == null then [] else
      ($spec.calls | map(.call) | join("\n") | without_strings) as $text
      | $types[0] as $all
      | closed($all; [ $all[] | select(.ns == $ns) | select(.name as $n | $text | test("\\b" + $n + "\\b")) | key_of ]) as $keys
      | [ $all[] | select(key_of as $k | $keys | index($k)) ] as $used
      | [ $used[] | .struct ] + [ $used[] | .description[] ]
    end;
def literal_using($spec): if ($spec.calls | any(.call | test("_edn\\b"))) then ["using namespace cbor::literals;"] else [] end;
def data_lines($spec; $item; $group):
  literal_lines($item.hex) as $lits
  | (if ($item.notation // "") == "" then "" else "  // " + $item.notation end) as $comment
  | (["std::string bytes ="] | .[0] += $comment) as $head
  | type_lines($spec; $group) + ["using namespace std::string_literals;"] + literal_using($spec) + $head
  + ($lits | to_entries | map(.value + (if .key == (($lits | length) - 1) then "s;" else "" end)))
  + (if uses($spec.calls; "doc")
     then ["auto const doc = cbor::lazy::adopt(" + (if uses($spec.calls; "bytes") then "std::string{bytes}" else "std::move(bytes)" end) + ");"]
     else [] end);
def play_lines($spec; $item; $group): data_lines($spec; $item; $group) + [ $spec.calls[] | .call + ";\t" + .result ];
def example_item($examples; $bytes; $qname): ([ range(0; $examples | length) | select($examples[.].page == $qname and $examples[.].shown) ] | .[0]) as $i
  | if $i == null then null else $bytes[$i] end;
def plain_code($spec; $item; $w; $group):
  data_lines($spec; $item; $group)
  + [ $spec.calls[] | (.call + ";") as $statement | ($statement + "  // " + .result) as $one
      | if ($one | length) <= $w then $one else ($statement, ("    // " + .result)) end ];
