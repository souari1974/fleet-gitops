#!/bin/bash
# Uninstall Capture One — À compléter par Sheriff
# Executed by Fleet as root

set -uo pipefail


rm -rf "/Applications/Capture One.app"
rm -rf "/Users/*/Library/Application Support/Capture One"

exit 0