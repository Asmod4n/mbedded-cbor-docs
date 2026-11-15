def norm: gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "") | gsub("`"; "");
def minimum_words: 4;
def counts($s): ($s | norm | split(" ") | length) >= minimum_words;
def keep_sentence($state; $s):
  ($s | norm) as $k
  | if counts($s) | not then [true, $state]
    elif $state.seen[$k] then [false, $state]
    else [true, ($state | .seen[$k] = true)] end;
def text_deduped($state; $text):
  reduce ($text | split("\n\n")[]) as $paragraph ({state: $state, paragraphs: []};
    (reduce ($paragraph | split("(?<=[.!?])\\s+"; null)[] | select(. != "")) as $s ({state: .state, kept: []};
        keep_sentence(.state; $s) as [$keep, $next] | .state = $next | if $keep then .kept += [$s] else . end)) as $r
    | .state = $r.state
    | if ($r.kept | length) > 0 then .paragraphs += [$r.kept | join(" ")] else . end)
  | {state, text: (.paragraphs | join("\n\n"))};
def entries_deduped($ordered):
  (reduce ($ordered[] | .brief | split("\n\n")[] | split("(?<=[.!?])\\s+"; null)[] | select(counts(.))) as $s ({}; .[$s | norm] = true)) as $briefs
  | reduce $ordered[] as $e ({state: {seen: $briefs}, out: {}};
      text_deduped(.state; $e.body) as $t
      | .state = $t.state | .out[$e.id] = $t.text);
def briefs_deduped($ordered):
  reduce $ordered[] as $e ({first: {}, out: {}};
    ($e.brief | norm) as $k
    | if counts($e.brief) and .first[$k] != null then .out[$e.id] = "See " + .first[$k] + "."
      else .first[$k] = $e.qname | .out[$e.id] = $e.brief end);
def sentences_in_body: [ split("\n\n")[] | select(startswith("Throws:") | not) | split("(?<=[.!?])\\s+"; null)[] | select(. != "") ];
def short_body($count): sentences_in_body | .[0:$count] | join(" ");
def sentences_per_entry: 2;
