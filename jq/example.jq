def is_header: startswith("message: ") or startswith("bytes: ");
def blocks: (.example | split("\n") | map(select(. != "")))
  | reduce .[] as $l ([];
      if length == 0 then [[$l]]
      elif ($l | is_header) and (.[-1] | any(startswith("> "))) then . + [[$l]]
      else .[-1] += [$l] end);
def spec_of_lines($lines):
  reduce $lines[] as $l ({message: null, bytes: null, calls: [], other: false};
      if ($l | startswith("message: ")) then .message = ($l | sub("^message: "; ""))
      elif ($l | startswith("bytes: ")) then .bytes = ($l | sub("^bytes: "; ""))
      elif ($l | startswith("> ")) then .calls += [{call: ($l | sub("^> "; "")), result: null}]
      elif (.calls | length) > 0 and .calls[-1].result == null then .calls[-1].result = $l
      else .other = true end)
  | if .other or ((.message == null) == (.bytes == null)) or (.calls | length) == 0 or any(.calls[]; .result == null) then null
    else {message, bytes, calls} end;
def specs: [ blocks[] | spec_of_lines(.) ];
def spec: if .example == "" then null else (specs | first) end;
def play_fields: spec as $s
  | if $s == null then {has_play: false, has_message: false, play_message: "", play_bytes: "", play_calls: "", play_rows: "1"}
    else {has_play: true, has_message: ($s.message != null), play_message: ($s.message // ""), play_bytes: ($s.bytes // ""),
          play_calls: ($s.calls | map(.call) | join("\n")), play_rows: ($s.calls | length | tostring)} end;
def shown_lines: (blocks | first) | map(select(is_header | not)) | join("\n");
def is_failure: test("^(fault|unexpected)");
