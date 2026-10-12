#!/bin/bash
# Lint every systemd unit in this repository before it ships.
# 1. systemd-analyze verify (syntax, unknown keys, missing executables are only warnings here).
# 2. Early-boot ordering trap: a unit with DefaultDependencies=no that runs before udev coldplug or
#    sysinit must not wait for local-fs.target, a .mount, or anything else behind it. The mounts
#    there wait for their by-uuid devices, the devices wait for coldplug, and coldplug waits for the
#    unit: a deadlock systemd does not report as an ordering cycle. Every boot then hangs 90 s and
#    drops to emergency mode (linux-sp11-uki 1-2, 2026-10-12).
# Usage: tools/check-units.sh [dir]   (default: this repository; exit 1 on any finding)
set -uo pipefail
cd "${1:-$(dirname "$0")/..}" || exit 2
rc=0
while IFS= read -r -d '' u; do
  out=$(systemd-analyze verify --man=no "$u" 2>&1 | grep -v 'is not executable\|Command .* is not executable\|No such file')
  [[ -n $out ]] && { echo "$u: systemd-analyze verify:"; echo "$out" | sed 's/^/  /'; rc=1; }
  key() { grep -E "^$1=" "$u" | cut -d= -f2- | tr '\n' ' '; }
  if [[ $(key DefaultDependencies) == *no* ]]; then
    before=$(key Before) after="$(key After) $(key Requires) $(key RequiresMountsFor) $(key Wants)"
    if [[ $before =~ (systemd-udev-trigger|systemd-udevd|sysinit\.target|systemd-modules-load) ]] &&
       [[ $after =~ (local-fs\.target|\.mount|remote-fs|/home|/var|/boot) ]]; then
      echo "$u: DefaultDependencies=no unit runs before udev/sysinit but waits for mounts ($after): boot deadlock"
      rc=1
    fi
  fi
done < <(find . -path ./.git -prune -o \( -name '*.service' -o -name '*.socket' -o -name '*.mount' -o -name '*.timer' \) -not -path '*/pkg/*' -not -path '*/src/*' -print0)
(( rc )) || echo "units OK"
exit $rc
