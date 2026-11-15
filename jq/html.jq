def escaped: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
def unlinked: gsub("\\[(?<t>[^\\]]+)\\]\\([^)]*\\)"; "\(.t)");
def coded: unlinked | escaped | gsub("`(?<c>[^`]+)`"; "<code>\(.c)</code>");
def table_cells: split("|") | map(gsub("^\\s+|\\s+$"; "")) | .[1:];
def table_rows: table_cells
  | reduce .[] as $c ({rows: [], row: []};
      if $c == "" then (if (.row | length) > 0 then .rows += [.row] | .row = [] else . end)
      else .row += [$c] end)
  | (if (.row | length) > 0 then .rows + [.row] else .rows end)
  | map(select(all(.[]; test("^-+$")) | not));
def table_html: table_rows as $r
  | "<table class=\"data\">\n<tr>" + ($r[0] | map("<th>" + coded + "</th>") | join("")) + "</tr>\n"
  + ($r[1:] | map("<tr>" + (map("<td>" + coded + "</td>") | join("")) + "</tr>\n") | join("")) + "</table>\n";
def is_table: contains("|---") or contains("| ---");
def body_html($sentences):
  [ split("\n\n")[] | select(startswith("Throws:") | not) ] as $paragraphs
  | reduce $paragraphs[] as $p ({left: $sentences, out: ""};
      if ($p | is_table) then .out += ($p | table_html)
      elif .left <= 0 then .
      else ([ $p | split("(?<=[.!?])\\s+"; null)[] | select(. != "") ]) as $ss
        | .out += "<p>" + ($ss[0:.left] | join(" ") | coded) + "</p>\n" | .left -= ($ss | length) end)
  | .out;
