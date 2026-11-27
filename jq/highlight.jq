include "snippet";
include "example";
include "html";
include "code";
def record_of($e): if $e.example == "" then "" elif ($e | spec) == null then "e" + $e.example else (example_item($examples[0]; $bytes[0]; $e.qname)) as $item | if $item == null then "e" + $e.example else "p" + (play_lines($e | spec; $item; $e.group) | join("\n")) end end;
$groups[0] as $g
| ([ .entries[] | "c" + qualified_sigs(.) ]
  + [ .entries[] | record_of(.) ]
  + ["c" + $g.index.example]
  + [ $g.groups[] | "c" + snippet(.name) ]
  + [ $g.console.samples[] | "c" + .call ])
| join("\u001e")
