is_before() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort | head -n 1)" = "$1" ]
}

night_decision() {
  if [ -z "${3:-}" ]; then
    echo run
  elif [ "$1" = "$3" ]; then
    if is_before "$2" "$4"; then echo skip; else echo run; fi
  elif is_before "$1" "$3"; then
    echo skip
  else
    echo run
  fi
}

night_draw() {
  hour=$(($2 % 8 / 2))
  if [ $(($2 % 2)) -eq 0 ]; then minute=13; else minute=43; fi
  printf '%s 0%s:%s\n' "$(date -u -d "$1 + 1 day" +%F)" "$hour" "$minute"
}
