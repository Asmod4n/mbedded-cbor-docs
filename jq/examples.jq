include "example";
[ .entries[] | . as $e | specs | to_entries[] | select(.value != null) | {page: $e.qname, group: $e.group, shown: (.key == 0), message: .value.message, bytes: .value.bytes, calls: .value.calls} ]
+ [ $groups[0].console.samples[] | {page: "console", group: "console", shown: true, message: .message, bytes: null, calls: [{call: .call, result: .result}]} ]
