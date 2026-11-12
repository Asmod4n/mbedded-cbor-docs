def trim: gsub("^\\s+|\\s+$"; "");
def joined: [.. | objects | select(.kind == "TextComment") | .text] | join("") | trim;
def pad($n; $fill): . + ([range(0; $n - length)] | map($fill)) | .[0:$n];
def template_kinds: ["FunctionTemplateDecl", "ClassTemplateDecl", "TypeAliasTemplateDecl", "VarTemplateDecl"];
def templated: if (.kind | IN(template_kinds[])) then
    ([(.inner // [])[] | select(.kind | IN("TemplateTypeParmDecl", "NonTypeTemplateParmDecl", "TemplateTemplateParmDecl", "ParenExpr", "BinaryOperator", "UnresolvedLookupExpr", "ConceptSpecializationExpr", "CXXFoldExpr", "RequiresExpr", "CallExpr", "UnaryOperator", "DeclRefExpr", "CXXBoolLiteralExpr", "ImplicitCastExpr", "TypeTraitExpr") | not)] | first)
  else . end;
def comment: ([ (.inner // [])[] | select(.kind == "FullComment") ] + [ (templated | (.inner // [])[] | select(.kind == "FullComment")) ]) | first;
def cparts: (comment | (.inner // []))[];
def has_comment: comment != null;
def retvals: [ cparts | select(.kind == "BlockCommandComment" and .name == "retval")
               | {names: (((.args // []) | join(" ")) + " " + joined | trim), on: true} ];
def example: [ cparts | select(.kind == "VerbatimBlockComment" and .name == "code") | (.inner // [])[] | .text | trim | select(test("^(call|result):")) | {line: ., on: true} ];
def snippets: [ cparts | select(.kind == "VerbatimLineComment" and (.text | test("\\.(cpp|hpp) "))) | {line: (.text | trim), on: true} ];
def sees: [ cparts | select(.kind == "BlockCommandComment" and .name == "see") | {line: joined, on: true} ];
def brief: ([ cparts | select(.kind == "BlockCommandComment" and .name == "brief") | joined ] | first) // "";
def group_of: ([ cparts | select(.kind == "VerbatimLineComment" and (.text | test("\\.(cpp|hpp) ") | not)) | .text | trim ] | first) // "";
def record_kinds: ["CXXRecordDecl", "ClassTemplateDecl"];
def member_kinds: ["FunctionTemplateDecl", "FunctionDecl", "CXXMethodDecl", "CXXConstructorDecl", "CXXConversionDecl", "CXXDestructorDecl", "EnumDecl", "TypeAliasDecl", "TypeAliasTemplateDecl", "VarTemplateDecl", "VarDecl", "ConceptDecl", "FieldDecl", "TypedefDecl"];
def srcof($file): ($file | split("/") | last | sub("\\.hpp$"; "")) as $b | ($ARGS.named["src_" + $b] // "");
def entry($file; $scope; $grp): . as $d
  | ($d | templated) as $t
  | {kind: $d.kind, scope: $scope, name: ($t.name // $d.name // ""), file: ($file | split("/") | last),
     group: (($d | group_of) | if . == "" then $grp else . end),
     b: ($d.range.begin.offset // -1),
     e: ((($t.inner // []) | map(select(.kind == "CompoundStmt")) | first | .range.begin.offset) // (($d.range.end.offset // -1) + ($d.range.end.tokLen // 1))),
     whole: (($d.range.end.offset // -1) + ($d.range.end.tokLen // 1)),
     brief: ($d | brief), errors: ($d | retvals), example: ($d | example), snippets: ($d | snippets), sees: ($d | sees)};
# emits entries for the children of a node, in document order, with the file of each
def children($file; $scope; $grp; $acc):
  (reduce ((.inner // [])[]) as $c ({file: $file, acc: $acc, out: []};
    if $c.kind == "AccessSpecDecl" then .acc = $c.access
    else
      ($c.loc.file // $c.loc.expansionLoc.file // .file) as $f
      | .file = $f
      | if ($c.isImplicit // false) then .
        elif $c.kind == "NamespaceDecl" then
          (if $c.name == "detail" then . else .out += [$c | children($f; $scope + "::" + ($c.name // ""); $grp; "public") | .[]] end)
        elif (.acc == "public") and ($c.kind | IN(record_kinds[])) then
          (($c | templated) as $r
           | (if ($c | has_comment) then [$c | entry($f; $scope; $grp)] else [] end) as $self
           | ($c | group_of | if . == "" then $grp else . end) as $g
           | (if ($r.completeDefinition // false) then [$r | children($f; $scope + "::" + ($r.name // ""); $g; (if $r.tagUsed == "class" then "private" else "public" end)) | .[]] else [] end) as $kids
           | .out += $self + $kids)
        elif (.acc == "public") and ($c.kind | IN(member_kinds[])) and ($c | has_comment) then .out += [$c | entry($f; $scope; $grp)]
        else . end
    end) | .out);
def run: . as $ns | [ $ns | children(($ns.loc.file); "cbor"; ""; "public") | .[] ];
[ inputs | select(.kind == "NamespaceDecl") | run ] | add
| map(. + {sig: ((srcof(.file)) as $s | (if (.kind | IN("EnumDecl", "CXXRecordDecl", "ClassTemplateDecl")) then ($s[.b:.whole] | (index("{") // length) as $i | .[0:$i]) elif .b >= 0 and .e > .b then $s[.b:.e] else "" end) | trim)})
| def unique_in_order: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
  def first_pair: ([ .[] | select(.line | startswith("call:")) ] | first) as $c
    | ([ .[] | select(.line | startswith("result:")) ] | first) as $r
    | {call: (($c.line // "") | sub("^call:\\s*"; "")), result: (($r.line // "") | sub("^result:\\s*"; ""))};
  . as $all
  | ($all | map(.scope + "::" + .name) | unique_in_order) as $keys
  | {title: "mbedded-cbor",
     entries: [ $keys[] as $k | ($all | map(select(.scope + "::" + .name == $k))) as $g
                | ($g | map(.example | first_pair) | map(select(.call != "")) | first // {call: "", result: ""}) as $p
                | {kind: $g[0].kind, scope: $g[0].scope, name: $g[0].name, group: $g[0].group,
                   sigs: ($g | map(.sig) | map(select(. != "")) | unique_in_order | join("\n")),
                   brief: ($g | map(.brief) | map(select(. != "")) | first // ""),
                   call: $p.call, result: $p.result} ],
     errors: [ $keys | map(select(. != null)) | .[] as $k | ($all | map(select(.scope + "::" + .name == $k)))
               | map(.errors[] | .names) | unique_in_order | select(length > 0) | {scope: $k, names: join("\n")} ]}
