#!/bin/sh
# Undoes every change listed in changes.log, newest first.
#
#   sh /Users/kartik/Sites/tv-detox-thomson/undo.sh                 uses the TV at 10.209.76.22
#   sh /Users/kartik/Sites/tv-detox-thomson/undo.sh 192.168.1.50     if the TV's IP has changed
#
# USB debugging must be ON on the TV. Apps that were uninstalled are reinstalled from
# apk-backup/ (their old logins/data are not restored). Restart the TV when it finishes.
cd "$(dirname "$0")" || exit 1
TV=${1:-10.209.76.22}
case "$TV" in *:*) ;; *) TV=$TV:5555 ;; esac
adb connect "$TV" >/dev/null 2>&1
if [ "$(adb -s "$TV" get-state 2>/dev/null)" != device ]; then
  echo "Can't reach the TV at $TV. Turn on USB debugging, press Allow on the TV, and try again." >&2
  exit 1
fi
tv() { adb -s "$TV" shell "$@" </dev/null; }

# Each line: <date> <time> <ACTION> <args...>
awk '{ l[NR] = $0 } END { for (i = NR; i > 0; i--) print l[i] }' changes.log |
while read -r _d _t action a b c; do
  case "$action" in
    DISABLE)   echo "Turning back on: $a"; tv pm enable "$a" ;;
    UNINSTALL) echo "Reinstalling: $a"; adb -s "$TV" install-multiple -r "$b"/*.apk </dev/null ;;
    SETTING)   echo "Restoring setting: $a $b = $c"
               if [ "$c" = null ]; then tv settings delete "$a" "$b"; else tv settings put "$a" "$b" "$c"; fi ;;
    HOME)      echo "Restoring Home: $a"; tv cmd package set-home-activity "$a" ;;
    INSTALL)   echo "Removing: $a"; adb -s "$TV" uninstall "$a" </dev/null ;;
    PUSH)      echo "Deleting copied file: $a"; tv rm -f "'$a'" ;;
    MKDIR)     echo "Removing folder if empty: $a"; tv rmdir "'$a'" 2>/dev/null ;;
  esac
done
echo "Done. Restart the TV: adb -s $TV reboot"
