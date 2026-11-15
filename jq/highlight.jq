include "snippet";
include "example";
def record_of($e): if $e.example == "" then "" elif ($e | spec) == null then "e" + $e.example else "e" + ($e | shown_lines) end;
$groups[0] as $g
| ([ .entries[] | "c" + .sigs ]
  + [ .entries[] | record_of(.) ]
  + ["c" + $g.index.example]
  + [ $g.groups[] | "c" + snippet(.name) ]
  + [ $g.console.samples[] | "c" + .call ])
| join("\u001e")
