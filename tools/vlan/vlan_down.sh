#!/usr/bin/env bash
# Host side: remove everything vlan_up.sh made (NM connection, ufw rules it added, keys/state). See README.md.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
STATE=$STATE_HOST
teardown
