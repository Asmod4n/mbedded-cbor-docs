def trim: gsub("^\\s+|\\s+$"; "");
def collapse: gsub("\\s+"; " ") | trim;
def unique_in_order: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
def sources: $ARGS.named | to_entries[] | select(.key | startswith("src_"));
def outside_ascii: sources | .key as $k | .value | split("\n") | to_entries[] | select(.value | test("[^\\x20-\\x7e]"))
  | error("\($k | sub("^src_"; "")): line \(.key + 1): a byte outside printable ASCII");
def attribute_macros: [ sources | .value | scan("(?m)^[ \\t]*#[ \\t]*define[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*(\\[\\[[^\\n]*\\]\\])?[ \\t]*$") | .[0] ] | unique;
def without_macros($macros): reduce $macros[] as $m (.; gsub("\\b" + $m + "\\b"; ""));
def cut_initializers: explode as $c
  | (reduce range(0; $c | length) as $i ({d: 0, at: null};
      if .at != null then .
      else $c[$i] as $x
        | if $x == 40 or $x == 91 or $x == 123 then .d += 1
          elif $x == 41 or $x == 93 or $x == 125 then .d -= 1
          elif $x == 58 and .d == 0 and $c[$i - 1] != 58 and $c[$i + 1] != 58 then .at = $i
          else . end
      end)) as $r
  | if $r.at == null then . else ($c[0:$r.at] | implode) end;
def inline_text: if .kind == "TextComment" then .text
  elif .kind == "InlineCommandComment" then
    ((.args // []) | join(" ")) as $a
    | if (.name | IN("p", "c", "a", "e", "em", "b")) then $a
      else ((.name | .[0:1] | ascii_upcase) + (.name | .[1:]) + ":" + (if $a == "" then "" else " " + $a end)) end
  else "" end;
def paragraph_text: [(.inner // [])[] | inline_text] | join("") | collapse;
def block_text: [(.inner // [])[] | select(.kind == "ParagraphComment") | paragraph_text] | map(select(. != "")) | join(" ");
def args_and_text: (((.args // []) | join(" ")) + " " + block_text) | trim;
def template_kinds: ["FunctionTemplateDecl", "ClassTemplateDecl", "TypeAliasTemplateDecl", "VarTemplateDecl"];
def templated: if (.kind | IN(template_kinds[])) then
    ([(.inner // [])[] | select(.kind | IN("TemplateTypeParmDecl", "NonTypeTemplateParmDecl", "TemplateTemplateParmDecl", "ParenExpr", "BinaryOperator", "UnresolvedLookupExpr", "ConceptSpecializationExpr", "CXXFoldExpr", "RequiresExpr", "CallExpr", "UnaryOperator", "DeclRefExpr", "CXXBoolLiteralExpr", "ImplicitCastExpr", "TypeTraitExpr") | not)] | first)
  else . end;
def comment: ([ (.inner // [])[] | select(.kind == "FullComment") ] + [ (templated | (.inner // [])[] | select(.kind == "FullComment")) ]) | first;
def cparts: (comment | (.inner // []))[];
def has_comment: comment != null;
def retvals: [ cparts | select(.kind == "BlockCommandComment" and .name == "retval") | args_and_text ];
def example: [ cparts | select(.kind == "VerbatimBlockComment" and .name == "code") | (.inner // [])[] | .text | trim
               | select(startswith("{.") | not) | if startswith("call:") then "> " + sub("^call:\\s*"; "")
                 elif startswith("result:") then sub("^result:\\s*"; "")
                 else . end ] | map(select(. != "")) | join("\n");
def sees: [ cparts | select(.kind == "BlockCommandComment" and .name == "see") | block_text ];
def brief: ([ cparts | select(.kind == "BlockCommandComment" and .name == "brief") | block_text ] | first) // "";
def paragraphs: [ cparts | select(.kind == "ParagraphComment") | paragraph_text | select(. != "") ]
  + [ cparts | select(.kind == "BlockCommandComment" and (.name | IN("return", "throws")))
      | (if .name == "return" then "Returns: " else "Throws: " end) + args_and_text ];
def group_of: ([ cparts | select(.kind == "VerbatimLineComment" and (.text | test("\\.(cpp|hpp) ") | not)) | .text | trim ] | first) // "";
def plain_name: if startswith("operator") then . else sub("<.*"; "") end;
def record_kinds: ["CXXRecordDecl", "ClassTemplateDecl"];
def member_kinds: ["FunctionTemplateDecl", "FunctionDecl", "CXXMethodDecl", "CXXConstructorDecl", "CXXConversionDecl", "CXXDestructorDecl", "EnumDecl", "TypeAliasDecl", "TypeAliasTemplateDecl", "VarTemplateDecl", "VarDecl", "ConceptDecl", "FieldDecl", "TypedefDecl"];
def srcof($file): ($file | split("/") | last | sub("\\.hpp$"; "")) as $b | ($ARGS.named["src_" + $b] // "");
def begin_of($r): $r.begin.offset // $r.begin.expansionLoc.offset // -1;
def end_of($r): ($r.end.offset // $r.end.expansionLoc.offset // -1) + ($r.end.tokLen // $r.end.expansionLoc.tokLen // 1);
def fullcomments: [.. | objects | select(.kind == "FullComment")] | length;
def skipped_of($scope; $why): (fullcomments) as $n | if $n == 0 then [] else [{scope: $scope, name: (.name // ""), why: $why, n: $n}] end;
def entry($file; $scope; $grp): . as $d
  | ($d | templated) as $t
  | {kind: $d.kind, scope: $scope, name: (($t.name // $d.name // "") | plain_name), file: ($file | split("/") | last),
     group: (($d | group_of) | if . == "" then $grp else . end),
     b: begin_of($d.range),
     e: (((($t.inner // []) | map(select(.kind == "CompoundStmt")) | first) as $body | if $body then begin_of($body.range) else end_of($d.range) end)),
     whole: end_of($d.range),
     brief: ($d | brief), paragraphs: ($d | paragraphs), errors: ($d | retvals), example: ($d | example), sees: ($d | sees)};
def children($file; $scope; $grp; $acc):
  reduce ((.inner // [])[]) as $c ({file: $file, acc: $acc, out: [], skipped: []};
    if $c.kind == "AccessSpecDecl" then .acc = $c.access
    else
      ($c.loc.file // $c.loc.expansionLoc.file // .file) as $f
      | .file = $f
      | if ($c.isImplicit // false) then .
        elif $c.kind == "NamespaceDecl" then
          if $c.name == "detail" then .skipped += ($c | skipped_of($scope; "detail namespace"))
          else ($c | children($f; $scope + "::" + ($c.name // ""); $grp; "public")) as $r | .out += $r.out | .skipped += $r.skipped end
        elif (.acc == "public") and ($c.kind | IN(record_kinds[])) then
          (($c | templated) as $r
           | (if ($c | has_comment) then [$c | entry($f; $scope; $grp)] else [] end) as $self
           | ($c | group_of | if . == "" then $grp else . end) as $g
           | (if ($r.completeDefinition // false) then ($r | children($f; $scope + "::" + (($r.name // "") | plain_name); $g; (if $r.tagUsed == "class" then "private" else "public" end))) else {out: [], skipped: []} end) as $kids
           | .out += $self + $kids.out | .skipped += $kids.skipped)
        elif (.acc == "public") and ($c.kind | IN(member_kinds[])) and ($c | has_comment) then .out += [$c | entry($f; $scope; $grp)]
        else .skipped += ($c | skipped_of($scope; (if .acc == "public" then "kind with no entry" else "not public" end))) end
    end);
def merged: . as $all | ($all | map(.scope + "::" + .name) | unique_in_order) as $keys
  | [ $keys[] as $k | ($all | map(select(.scope + "::" + .name == $k))) as $g
      | ($g | map(.sig) | map(select(. != "")) | unique_in_order) as $sigs
      | {kind: $g[0].kind, scope: $g[0].scope, name: $g[0].name, qname: $k, id: ($k | gsub("[^A-Za-z0-9]+"; "-")),
         group: $g[0].group, overloads: ($g | length),
         sigs: (if ($sigs | length) > 1 then ($sigs | to_entries | map("(\(.key + 1)) " + .value) | join("\n")) else ($sigs | join("")) end),
         brief: ($g | map(.brief) | map(select(. != "")) | first // ""),
         body: ($g | map(.paragraphs[]) | unique_in_order | join("\n\n")),
         example: ($g | map(.example) | map(select(. != "")) | first // ""),
         sees: ($g | map(.sees[]) | unique_in_order | join("\n"))} ];
attribute_macros as $macros
| ([ outside_ascii ] | length) as $ascii
| [ inputs | select(.kind == "NamespaceDecl") ] as $namespaces
| ([ $namespaces[] | children(.loc.file; "cbor"; ""; "public") ]) as $runs
| ([ $runs[].out[] ]) as $raw
| ($raw | map(. as $e | . + {sig: ((srcof(.file)) as $s
      | (if (.kind | IN("EnumDecl", "CXXRecordDecl", "ClassTemplateDecl")) then ($s[.b:.whole] | (index("{") // length) as $i | .[0:$i])
         elif .b >= 0 and .e > .b then $s[.b:.e]
         else "" end)
      | (if $e.kind == "CXXConstructorDecl" then cut_initializers else . end) | without_macros($macros) | collapse)})) as $sigged
| ($sigged | map(select(.sig == "")) | map(.scope + "::" + .name)) as $empty
| if ($empty | length) > 0 then error("an entry has no signature: " + ($empty | join(", "))) else . end
| {title: "mbedded-cbor",
   entries: ($sigged | merged),
   errors: [ $sigged | map(select(.errors | length > 0)) | .[] | {scope: .scope, names: .errors} ]
           | group_by(.scope) | map({scope: .[0].scope, names: (map(.names[]) | unique_in_order | join("\n"))}),
   counts: {entries: ($raw | length), skipped: ([ $runs[].skipped[].n ] | add // 0), ast: ([ $namespaces[] | fullcomments ] | add // 0)}}
