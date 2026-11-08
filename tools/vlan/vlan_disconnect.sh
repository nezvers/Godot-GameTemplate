#!/usr/bin/env bash
# Guest side on Linux: remove everything vlan_connect.sh made (NM connection, ufw rules it added, keys/state). See README.md.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
STATE=$STATE_GUEST
teardown
