def joined: [.. | objects | select(.kind == "TextComment") | .text] | join("") | gsub("^\\s+|\\s+$"; "");
def pad($n; $fill): . + ([range(0; $n - length)] | map($fill)) | .[0:$n];
def fnode: if .kind == "FunctionTemplateDecl" then ([(.inner // [])[] | select(.kind | IN("CXXMethodDecl", "CXXConstructorDecl", "CXXConversionDecl", "CXXDestructorDecl", "FunctionDecl"))] | first) else . end;
def comment: ([ (.inner // [])[] | select(.kind == "FullComment") ] + [ (fnode | (.inner // [])[] | select(.kind == "FullComment")) ]) | first;
def cparts: (comment | (.inner // []))[];
def retvals: [ cparts | select(.kind == "BlockCommandComment" and .name == "retval")
               | (.args // []) as $a | (joined) as $t | {names: (($a | join(" ")) + " " + $t | gsub("^\\s+|\\s+$"; "")), text: "", on: true} ];
def example: [ cparts | select(.kind == "VerbatimBlockComment" and .name == "code") | (.inner // [])[] | .text | gsub("^\\s+|\\s+$"; "") | select(test("^(call|result):")) | {line: ., on: true} ];
def snippets: [ cparts | select(.kind == "VerbatimLineComment" and (.text | test("\\.cpp "))) | {line: (.text | gsub("^\\s+|\\s+$"; "")), on: true} ];
def sees: [ cparts | select(.kind == "BlockCommandComment" and .name == "see") | {line: joined, on: true} ];
def brief: ([ cparts | select(.kind == "BlockCommandComment" and .name == "brief") | joined ] | first) // "";
. as $all
| [ $all[] | select(.kind == "CXXRecordDecl" and .name == $class and .completeDefinition == true) ] | first as $cls
| ($cls.inner | reduce .[] as $m ({acc: ($cls.tagUsed == "class" | if . then "private" else "public" end), out: []};
     if $m.kind == "AccessSpecDecl" then .acc = $m.access
     elif .acc == "public" and ($m | comment) != null then .out += [$m] else . end) | .out) as $members
| ($members | map({kind, name: (.name // ""), b: .range.begin.offset, e: (.range.end.offset + (.range.end.tokLen // 1)),
                  brief: brief, errors: retvals, example: example, snippets: snippets, sees: sees})) as $rows
| ($rows | map(.errors | length) | max) as $ne | ($rows | map(.example | length) | max) as $nx
| ($rows | map(.snippets | length) | max) as $ns | ($rows | map(.sees | length) | max) as $nsee
| { title: ("cbor::" + $class),
    entries: ($rows | map({name, kind, signature: ($src[.b:.e] | gsub("^\\s+|\\s+$"; "")), brief,
          errors: (.errors | pad($ne; {names: "", text: "", on: false})), example: (.example | pad($nx; {line: "", on: false})),
          snippets: (.snippets | pad($ns; {line: "", on: false})), sees: (.sees | pad($nsee; {line: "", on: false}))})) }
