#!/usr/bin/env bash
# lock-pam-stacks.sh DIR: write test PAM stacks for the lock into DIR (PLAN M8).
#
# The lock's PamContext runs these instead of /etc/pam.d/hyprlock in tests
# (tests/lock-pam.sh) and in the sandbox lock test
# (.shell-rebuild/specs/shots/M8/lock-test.sh), so nothing ever types, reads
# or checks the real password, and pam_faillock never counts a test attempt.
#
#   t-pass      Success for the test password, Failed (PAM_AUTH_ERR) for
#               anything else
#   t-slow      the same after 2 s (for "Checking…", Esc and teardown)
#   t-maxtries  MaxTries (PAM_MAXTRIES) whatever is typed
#   t-error     Error (PAM_AUTHINFO_UNAVAIL) whatever is typed
#
# pam_exec with expose_authtok prompts "Password: " and hands the answer to
# check.sh on stdin; pam_debug returns the code its argument names. Both ship
# with Linux-PAM; PamContext takes the directory as `configDirectory`.
#
# The test password is printed on stdout for the caller.
set -euo pipefail
dir=${1:?usage: lock-pam-stacks.sh DIR}
mkdir -p "$dir"
dir=$(cd "$dir" && pwd)
password='hunter2'

for m in pam_exec.so pam_debug.so pam_permit.so; do
    found=0
    for d in /usr/lib/security /lib/security /usr/lib64/security /usr/lib/x86_64-linux-gnu/security; do
        [ -f "$d/$m" ] && found=1
    done
    [ $found = 1 ] || { echo "lock-pam-stacks: $m is not installed" >&2; exit 1; }
done

cat >"$dir/check.sh" <<EOF
#!/bin/sh
# pam_exec expose_authtok: the answer on stdin, NUL-terminated.
IFS= read -r pw || true
pw=\$(printf '%s' "\$pw" | tr -d '\\000')
[ "\$pw" = '$password' ]
EOF
cat >"$dir/slow.sh" <<EOF
#!/bin/sh
IFS= read -r pw || true
sleep 2
pw=\$(printf '%s' "\$pw" | tr -d '\\000')
[ "\$pw" = '$password' ]
EOF
chmod 755 "$dir/check.sh" "$dir/slow.sh"

cat >"$dir/t-pass" <<EOF
auth [success=1 default=ignore] pam_exec.so quiet expose_authtok $dir/check.sh
auth requisite pam_debug.so auth=auth_err
auth required pam_permit.so
account required pam_permit.so
EOF
cat >"$dir/t-slow" <<EOF
auth [success=1 default=ignore] pam_exec.so quiet expose_authtok $dir/slow.sh
auth requisite pam_debug.so auth=auth_err
auth required pam_permit.so
account required pam_permit.so
EOF
cat >"$dir/t-maxtries" <<EOF
auth [success=ignore default=ignore] pam_exec.so quiet expose_authtok $dir/check.sh
auth requisite pam_debug.so auth=maxtries
EOF
cat >"$dir/t-error" <<EOF
auth [success=ignore default=ignore] pam_exec.so quiet expose_authtok $dir/check.sh
auth requisite pam_debug.so auth=authinfo_unavail
EOF

printf '%s\n' "$password"
