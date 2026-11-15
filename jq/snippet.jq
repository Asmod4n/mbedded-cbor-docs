def snippet($group): [ $ARGS.named | to_entries[] | select(.key | startswith("test_")) | .value | split("\n")[] ]
  | reduce .[] as $line ({inside: false, out: []};
      if ($line | test("^\\s*// \\[" + $group + " group\\]\\s*$")) then .inside |= not
      elif .inside then .out += [$line | sub("^    "; "")]
      else . end)
  | .out | join("\n");
