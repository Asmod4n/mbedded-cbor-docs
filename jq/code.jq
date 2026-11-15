def hex_bytes: split(" ") | map(select(. != ""));
def literal_lines($hex): [ $hex | hex_bytes | . as $b | range(0; length; 16) as $i | "    \"" + ($b[$i:($i + 16)] | map("\\x" + .) | join("")) + "\"" ];
def uses($calls; $word): ($calls | map(.call) | join("\n")) | test("\\b" + $word + "\\b");
def data_lines($spec; $item):
  literal_lines($item.hex) as $lits
  | (if ($item.notation // "") == "" then "" else "  // " + $item.notation end) as $comment
  | (["std::string bytes ="] | .[0] += $comment) as $head
  | $head + ($lits | to_entries | map(.value + (if .key == (($lits | length) - 1) then ";" else "" end)))
  + (if uses($spec.calls; "doc")
     then ["auto const doc = cbor::lazy::adopt(" + (if uses($spec.calls; "bytes") then "std::string{bytes}" else "std::move(bytes)" end) + ");"]
     else [] end);
def play_lines($spec; $item): data_lines($spec; $item) + [ $spec.calls[] | .call + ";\t" + .result ];
def example_item($examples; $bytes; $qname): ([ range(0; $examples | length) | select($examples[.].page == $qname and $examples[.].shown) ] | .[0]) as $i
  | if $i == null then null else $bytes[$i] end;
def plain_code($spec; $item; $w):
  data_lines($spec; $item)
  + [ $spec.calls[] | (.call + ";") as $statement | ($statement + "  // " + .result) as $one
      | if ($one | length) <= $w then $one else ($statement, ("    // " + .result)) end ];
