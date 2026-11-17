def man_width: 73;
def spaces($n): if $n > 0 then " " * $n else "" end;
def wrapped($w; $indent): split(" ")
  | reduce .[] as $word ({lines: [], cur: ""};
      if .cur == "" then .cur = $word
      elif (.cur | length) + 1 + ($word | length) > $w then .lines += [.cur] | .cur = spaces($indent) + $word
      else .cur += " " + $word end)
  | .lines + [.cur];
def hard_broken($w): if length <= $w then [.]
  else ([ match("[,(<]"; "g") | select(.offset < ($w - 1)) ] | last) as $m
    | if $m == null then [.[0:$w]] + (.[$w:] | hard_broken($w))
      else [.[0:($m.offset + 1)]] + (("        " + .[($m.offset + 1):]) | hard_broken($w)) end end;
def code_wrapped($w): split("\n") | map(if length > $w then (wrapped($w; 4) | map(hard_broken($w)) | add) else [.] end) | add | join("\n");
def depth_split: reduce (explode[]) as $c ({parts: [], cur: [], depth: 0};
    if ($c == 60 or $c == 40 or $c == 91) then .depth += 1 | .cur += [$c]
    elif ($c == 62 or $c == 41 or $c == 93) then .depth -= 1 | .cur += [$c]
    elif $c == 44 and .depth == 0 then .parts += [.cur | implode] | .cur = []
    else .cur += [$c] end)
  | .parts + [.cur | implode] | map(sub("^ +"; ""));
def template_split: if startswith("template <") then
    (reduce (explode | to_entries[]) as $c ({depth: 0, end: -1, started: false};
      if .end >= 0 then .
      elif $c.value == 60 then .depth += 1 | .started = true
      elif $c.value == 62 then .depth -= 1 | if .depth == 0 then .end = $c.key else . end
      else . end)) as $s
    | {template: .[0:($s.end + 1)], rest: (.[($s.end + 1):] | sub("^ +"; ""))}
  else {template: "", rest: .} end;
def atom: "(\\([^()]*\\)|[\\w:]+(<([^<>]|<[^<>]*>)*>)?)";
def without_requires: ("\\srequires\\s+" + atom + "(\\s*(\\|\\||&&)\\s*" + atom + ")*\\s") as $pattern | sub($pattern; " ");
def params_wrapped($head; $params; $tail; $w):
  ($params | depth_split) as $ps
  | ($ps | length) as $count
  | (reduce range(0; $count) as $i ({lines: [], cur: $head, empty: true};
      ($ps[$i] + (if $i < $count - 1 then "," else "" end)) as $piece
      | (if $i == $count - 1 then 1 + ($tail | length) else 0 end) as $extra
      | if .empty then
          (if (.cur | length) + ($piece | length) + $extra > $w then .lines += [.cur] | .cur = "    " + $piece else .cur += $piece end) | .empty = false
        elif (.cur | length) + 1 + ($piece | length) + $extra > $w then .lines += [.cur] | .cur = spaces($head | length) + $piece
        else .cur += " " + $piece end)) as $r
  | $r.lines + [$r.cur + ")" + $tail];
def paren_close($s):
  ($s | explode) as $c
  | (reduce range(0; $c | length) as $i ({d: 0, at: -1};
      if .at >= 0 then .
      elif $c[$i] == 40 then .d += 1
      elif $c[$i] == 41 then (.d -= 1 | if .d == 0 then .at = $i else . end)
      else . end)).at;
def decl_lines($whole; $name; $w):
  ($whole | sub(" requires [^;{]*$"; "")) as $decl
  | if ($decl | length) <= $w then [$decl]
  else (($decl | index($name + "(")) // null) as $at
    | if $at == null then ($decl | wrapped($w; 4) | map(hard_broken($w)) | add)
      else ($decl[0:$at] | sub(" +$"; "")) as $prefix
        | $decl[$at:] as $rest
        | ($name | length) as $open
        | paren_close($rest[$open:]) as $close_relative
        | ($open + $close_relative) as $close
        | $rest[($open + 1):$close] as $params
        | ($rest[($close + 1):] | sub("^ +"; "")) as $tail
        | (if $prefix == "" then [] elif ($prefix | length) > $w then ($prefix | wrapped($w; 4) | map(hard_broken($w)) | add) else [$prefix] end)
          + (if ($rest | length) <= $w then [$rest]
             else ($tail | length) as $tail_length
               | (if $tail_length > 0 and ($tail_length + 20) > $w then "" else (if $tail == "" then "" else " " + $tail end) end) as $inline_tail
               | params_wrapped($rest[0:($open + 1)]; $params; $inline_tail; $w)
                 + (if $inline_tail == "" and $tail != "" then ($tail | wrapped($w - 4; 4) | map("    " + .)) else [] end)
             end)
      end
  end;
def sig_text_lines($line; $name; $reduce):
  ($line | capture("^(?<number>\\([0-9]+\\) )?(?<decl>.*)$")) as $p
  | ($p.number // "") as $number
  | ($p.decl | without_requires | template_split) as $t
  | (man_width - ($number | length) - $reduce) as $w
  | ((if $t.template == "" then [] elif ($t.template | length) > $w then ($t.template | wrapped($w; 10) | map(hard_broken($w)) | add) else [$t.template] end)
     + decl_lines($t.rest; $name; $w))
  | . as $all | [ range(0; $all | length) as $i | (if $i == 0 then $number else spaces($number | length) end) + $all[$i] ];
def throws_of($e): [ ($e.body | split("\n\n"))[] | select(startswith("Throws:"))
  | capture("^Throws: (?<type>[^ ]+) ?(?<text>.*)$") ];
def unique_in_order: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
def flags: ["file", "sh", "name", "nf", "fi", "include", "sp", "sig", "line", "text", "pp", "tp", "ex", "see"];
def plain: gsub("\\[(?<t>[^\\]]+)\\]\\([^)]*\\)"; "\(.t)") | gsub("`"; "");
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
def line_index($lines; $pattern): ([ range(0; $lines | length) | select($lines[.] | test($pattern)) ] | .[0]);
def sig_decl_lines($e; $indent; $suffix):
  [ $e.sigs | split("\n")[] | sig_text_lines(.; $e.name; $indent + ($suffix | length)) | (.[-1] += $suffix) | map(spaces($indent) + .) ] | add;
def signature_rows($file; $e; $indent; $suffix):
  sig_decl_lines($e; $indent; $suffix) as $lines
  | (line_index($lines; ($e.name | regex_escaped) + "\\(") // line_index($lines; "\\b" + ($e.name | regex_escaped) + "\\b") // -1) as $at
  | [ range(0; $lines | length) as $i | if $i == $at then named_row($file; $lines[$i]; $e.name) else row("line"; $file; $lines[$i]; ""; ""; "") end ];
def signature_block($file; $entries; $indent; $suffix): [ $entries | to_entries[] | (if .key > 0 then [row("sp"; $file; ""; ""; ""; "")] else [] end) + signature_rows($file; .value; $indent; $suffix) ] | add // [];
def text_row($file; $text): row("line"; $file; $text; ""; ""; "");
def namespace_of($scope; $classes): ($scope | split("::")) as $parts
  | (reduce range(0; $parts | length) as $i ({done: false, ns: []};
      if .done then . elif (($parts[0:($i + 1)] | join("::")) | IN($classes[])) then .done = true else .ns += [$parts[$i]] end)).ns | join("::");
def class_synopsis($file; $c; $members; $classes):
  namespace_of($c.scope; $classes) as $ns
  | (($c.scope | ltrimstr($ns) | ltrimstr("::")) | if . == "" then "" else . + "::" end) as $outer
  | ($c + {name: ($outer + $c.name), sigs: ($c.sigs | split("\n") | map(sub("(?<![\\w:])" + ($c.name | regex_escaped) + "\\b"; $outer + $c.name)) | join("\n"))}) as $shown
  | [text_row($file; "namespace " + $ns + " {")]
  + (if ($members | length) == 0 then signature_rows($file; $shown; 0; ";")
     else signature_rows($file; $shown; 0; " {") + signature_block($file; $members; 4; ";") + [text_row($file; "};")] end)
  + [text_row($file; "}")];
def function_synopsis($file; $functions):
  [ $functions | group_by(.scope)[] | . as $g | [text_row($file; "namespace " + $g[0].scope + " {")] + signature_block($file; $g; 0; ";") + [text_row($file; "}")] ]
  | to_entries | map((if .key > 0 then [row("sp"; $file; ""; ""; ""; "")] else [] end) + .value) | add // [];
def section($file; $title; $rows): if ($rows | length) == 0 then [] else [row("sh"; $file; $title; ""; ""; "")] + $rows end;
def tag_rows($file; $pairs): [ $pairs[] | row("tp"; $file; .[0]; .[1]; ""; "") ];
def text_of($e): ([$e.brief] + ($e.body | paragraphs | map(select(startswith("Throws:") | not)))) | map(select(. != "")) | join(" ");
def throws_pairs($entries; $own): [ $entries[] | . as $e | throws_of($e)[] | [.type, (if $e.qname == $own then .text else $e.name + "(): " + .text end)] ];
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
  + synopsis_rows($file; class_synopsis($file; $c; $members; [ $entries[] | select(.kind | IN("CXXRecordDecl", "ClassTemplateDecl")) | .qname ]))
  + section($file; "DESCRIPTION";
      ([ $c.body | paragraphs | map(select(startswith("Throws:") | not)) | to_entries[] | row(if .key == 0 then "text" else "pp" end; $file; .value; ""; ""; "") ]
       + [ $members[] | row("tp"; $file; .name; text_of(.); ""; "") ]))
  + section($file; "ERRORS"; tag_rows($file; throws_pairs($all; $c.qname) + error_pairs([ $errors[] | select(.scope == $c.qname or (.scope | startswith($c.qname + "::"))) ])))
  + section($file; "EXAMPLES"; [ $all[] | select(.example != "") ] | to_entries | map(.key as $k | .value | row(if $k == 0 then "text" else "pp" end; $file; .qname; ""; ""; ""), row("ex"; $file; (.example | code_wrapped(man_width)); ""; ""; "")))
  + section($file; "SEE ALSO"; see_rows($file; (see_names($all; $c.qname) + ["mbedded-cbor-" + $group])));
def group_page($g; $entries; $snippet):
  ("mbedded-cbor-" + $g.name + ".3") as $file
  | [ $entries[] | select(.group == $g.name) ] as $mine
  | [ $mine[] | select(.kind | IN("CXXRecordDecl", "ClassTemplateDecl")) ] as $classes
  | [ $mine[] | select(.scope == "cbor" and (.kind | IN("CXXRecordDecl", "ClassTemplateDecl") | not)) ] as $functions
  | file_rows($file; "mbedded-cbor-" + $g.name; $g.title)
  + synopsis_rows($file; function_synopsis($file; $functions))
  + section($file; "DESCRIPTION";
      ([ $classes[] | row("tp"; $file; .qname; .brief; ""; "") ] + [ $functions[] | row("tp"; $file; .qname; .brief; ""; "") ]))
  + section($file; "ERRORS"; tag_rows($file; throws_pairs($functions; "")))
  + section($file; "EXAMPLES"; if $snippet == "" then [] else [row("ex"; $file; ($snippet | code_wrapped(man_width)); ""; ""; "")] end)
  + section($file; "SEE ALSO"; see_rows($file; (["mbedded-cbor"] + [ $classes[] | .qname ])));
def overview_page($index; $groups):
  ("mbedded-cbor.3") as $file
  | file_rows($file; "mbedded-cbor"; $index.brief)
  + synopsis_rows($file; [])
  + section($file; "DESCRIPTION"; [ $groups[] | row("tp"; $file; "mbedded-cbor-" + .name; .title; ""; "") ])
  + section($file; "EXAMPLES"; [row("ex"; $file; ($index.example | code_wrapped(man_width)); ""; ""; "")])
  + section($file; "SEE ALSO"; see_rows($file; [ $groups[] | "mbedded-cbor-" + .name ]));
