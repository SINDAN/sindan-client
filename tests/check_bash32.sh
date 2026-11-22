#!/bin/bash
# check_bash32.sh - Look for bash 4+ constructs in the scripts that run on
# macOS, which ships bash 3.2.
#
# Usage: tests/check_bash32.sh
#
# This is a grep-based heuristic, not a parser. Comment lines are ignored.

here=$(cd "$(dirname "$0")" && pwd) || exit 2
cd "$here/.." || exit 2

# pattern<TAB>description
patterns='\$\{[A-Za-z_0-9]+(,,|,|\^\^|\^)}	case conversion expansion
\$\{[A-Za-z_0-9]+@[A-Za-z]}	parameter transformation
(^|[;&|[:space:]])(mapfile|readarray)([[:space:]]|$)	mapfile/readarray
declare[[:space:]]+-[a-zA-Z]*A	associative array
(^|[;&|[:space:]])wait[[:space:]]+-n	wait -n
&>>	&>> redirection
\|&	|& pipe
BASHPID	BASHPID
(^|[;&|[:space:]])coproc[[:space:]]	coproc
;;&|;&	case fallthrough
(^|[;&|[:space:]])(source)[[:space:]]	source (use ".")
\$EPOCHSECONDS|\$EPOCHREALTIME	EPOCHSECONDS/EPOCHREALTIME
\$SRANDOM	SRANDOM'

# bash 3.2 runs everything under common/ and macos/.
files=$(find common macos -name '*.sh' -o -name 'sindan.conf.example' | sort)

status=0
while IFS="$(printf '\t')" read -r pattern desc; do
  [ -n "$pattern" ] || continue
  # shellcheck disable=SC2086
  hits=$(grep -nE -- "$pattern" $files 2> /dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#')
  if [ -n "$hits" ]; then
    echo "bash 4+ construct ($desc):"
    echo "$hits" | sed 's/^/  /'
    status=1
  fi
done <<EOF2
$patterns
EOF2

if [ "$status" -eq 0 ]; then
  echo "No bash 4+ constructs found."
fi
exit "$status"
