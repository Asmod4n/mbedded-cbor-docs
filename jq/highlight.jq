include "snippet";
include "example";
include "html";
def record_of($e): if $e.example == "" then "" elif ($e | spec) == null then "e" + $e.example else "p" + (if ($e | spec).message != null then "message: " + ($e | spec).message else "bytes: " + ($e | spec).bytes end) + "\n" + (($e | spec).calls | map(.call + "\t" + .result) | join("\n")) end;
$groups[0] as $g
| ([ .entries[] | "c" + qualified_sigs(.) ]
  + [ .entries[] | record_of(.) ]
  + ["c" + $g.index.example]
  + [ $g.groups[] | "c" + snippet(.name) ]
  + [ $g.console.samples[] | "c" + .call ])
| join("\u001e")
