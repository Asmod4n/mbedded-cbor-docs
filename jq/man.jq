def unique_in_order: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
def flags: ["file", "sh", "name", "nf", "fi", "include", "sp", "sig", "line", "text", "pp", "tp", "ex", "see"];
def plain: gsub("`"; "");
def row($kind; $file; $a; $b; $c; $d): ($kind | IN("text", "pp", "tp", "name")) as $p
  | {file: $file, a: (if $p then $a | plain else $a end), b: (if $p then $b | plain else $b end), c: $c, d: $d}
  + ([ flags[] as $f | {("is_" + $f): ($kind == $f)} ] | add);
def paragraphs: split("\n\n") | map(select(. != ""));
def regex_escaped: gsub("(?<c>[^A-Za-z0-9_])"; "\\" + .c);
def named_row($file; $line; $name):
  ($name | regex_escaped) as $re
  | (([ $line | match("\\b" + $re + "(?=\\()"; "g") ] | first) // ([ $line | match("\\b" + $re + "\\b"; "g") ] | last)) as $m
  | if $m == null then row("line"; $file; $line; ""; ""; "")
    else row("sig"; $file; $line[0:$m.offset]; $name; $line[($m.offset + $m.length):]; "") end;
def signature_rows($file; $e): [ ($e.sigs | split("\n"))[] | named_row($file; .; $e.name) ];
def section($file; $title; $rows): if ($rows | length) == 0 then [] else [row("sh"; $file; $title; ""; ""; "")] + $rows end;
def tag_rows($file; $pairs): [ $pairs[] | row("tp"; $file; .[0]; .[1]; ""; "") ];
def text_of($e): ([$e.brief] + ($e.body | paragraphs)) | map(select(. != "")) | join(" ");
def error_pairs($errors): [ $errors[] | .names | split("\n")[]
  | capture("^(?<tag>[A-Za-z0-9_]+(, [A-Za-z0-9_]+)*) (?<text>.*)$") | [.tag, .text] ];
def see_names($entries; $own): [ $entries[] | .sees | split("\n")[] | select(. != "" and . != $own) ] | unique_in_order;
def see_rows($file; $names): if ($names | length) == 0 then [] else [row("see"; $file; ($names | join(", ")); ""; ""; "")] end;
def file_rows($file; $title; $brief): [row("file"; $file; $title; $file; $ARGS.named.date; $ARGS.named.source), row("sh"; $file; "NAME"; ""; ""; ""), row("name"; $file; $title; $brief; ""; "")];
def synopsis_rows($file; $lines): [row("sh"; $file; "SYNOPSIS"; ""; ""; ""), row("nf"; $file; ""; ""; ""; ""), row("include"; $file; "#include <cbor/cbor.hpp>"; ""; ""; "")]
  + (if ($lines | length) > 0 then [row("sp"; $file; ""; ""; ""; "")] + $lines else [] end) + [row("fi"; $file; ""; ""; ""; "")];
def class_page($c; $entries; $errors; $group):
  ($c.qname + ".3") as $file
  | [ $entries[] | select(.scope == $c.qname) ] as $members
  | ([$c] + $members) as $all
  | file_rows($file; $c.qname; $c.brief)
  + synopsis_rows($file; ([ $all[] | signature_rows($file; .)[] ]))
  + section($file; "DESCRIPTION";
      ([ $c.body | paragraphs | to_entries[] | row(if .key == 0 then "text" else "pp" end; $file; .value; ""; ""; "") ]
       + [ $members[] | row("tp"; $file; .name; text_of(.); ""; "") ]))
  + section($file; "ERRORS"; tag_rows($file; error_pairs([ $errors[] | select(.scope == $c.qname or (.scope | startswith($c.qname + "::"))) ])))
  + section($file; "EXAMPLES"; [ $all[] | select(.example != "") ] | to_entries | map(.key as $k | .value | row(if $k == 0 then "text" else "pp" end; $file; .qname; ""; ""; ""), row("ex"; $file; .example; ""; ""; "")))
  + section($file; "SEE ALSO"; see_rows($file; (see_names($all; $c.qname) + ["mbedded-cbor-" + $group])));
def group_page($g; $entries; $snippet):
  ("mbedded-cbor-" + $g.name + ".3") as $file
  | [ $entries[] | select(.group == $g.name) ] as $mine
  | [ $mine[] | select(.kind | IN("CXXRecordDecl", "ClassTemplateDecl")) ] as $classes
  | [ $mine[] | select(.scope == "cbor" and (.kind | IN("CXXRecordDecl", "ClassTemplateDecl") | not)) ] as $functions
  | file_rows($file; "mbedded-cbor-" + $g.name; $g.title)
  + synopsis_rows($file; [ $functions[] | signature_rows($file; .)[] ])
  + section($file; "DESCRIPTION";
      ([ $classes[] | row("tp"; $file; .qname; .brief; ""; "") ] + [ $functions[] | row("tp"; $file; .qname; .brief; ""; "") ]))
  + section($file; "EXAMPLES"; if $snippet == "" then [] else [row("ex"; $file; $snippet; ""; ""; "")] end)
  + section($file; "SEE ALSO"; see_rows($file; (["mbedded-cbor"] + [ $classes[] | .qname ])));
def overview_page($index; $groups):
  ("mbedded-cbor.3") as $file
  | file_rows($file; "mbedded-cbor"; $index.brief)
  + synopsis_rows($file; [])
  + section($file; "DESCRIPTION"; [ $groups[] | row("tp"; $file; "mbedded-cbor-" + .name; .title; ""; "") ])
  + section($file; "EXAMPLES"; [row("ex"; $file; $index.example; ""; ""; "")])
  + section($file; "SEE ALSO"; see_rows($file; [ $groups[] | "mbedded-cbor-" + .name ]));
