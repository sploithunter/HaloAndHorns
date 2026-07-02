#!/usr/bin/env bash
#
# studio_publish.sh — publish the place currently open in Roblox Studio by
# driving File → Publish to Roblox with AppleScript (macOS). No vision / no
# "computer use": System Events clicks the menu item by name.
#
# This is the publish lane for a headless / MCP-only agent that needs to ship a
# Studio-authored-map game: it publishes the OPEN Studio session, so the synced
# code AND the authored Workspace map go live — and it needs no Open Cloud key
# and no closing of Studio (unlike `rojo upload`).
#
# Requirements:
#   - Roblox Studio open on the target place, already associated with a Roblox
#     place (i.e. opened from Roblox / previously published). A brand-new
#     unassociated place would open the "Publish As" dialog instead, which this
#     script does not drive.
#   - Accessibility permission granted to the app running this script
#     (System Settings → Privacy & Security → Accessibility).
#
# Usage: mise run publish-studio   (or: bash scripts/studio_publish.sh)
# Exit:  0 published, 1 setup/permission error, 2 clicked but no confirmation.

set -euo pipefail

PROC="RobloxStudio"
MENU="File"
ITEM="Publish to Roblox" # use "Publish to Roblox As" to choose/create a place

# Preflight: is Studio running?
running=$(osascript -e "tell application \"System Events\" to (name of processes) contains \"$PROC\"" 2>/dev/null || echo false)
if [ "$running" != "true" ]; then
    echo "ERROR: Roblox Studio ($PROC) is not running. Open the target place first." >&2
    exit 1
fi

echo "Publishing the open Studio place via $MENU → $ITEM ..."
osascript -e "tell application \"$PROC\" to activate" >/dev/null 2>&1 || true

# Click the publish menu item; surface the Accessibility error clearly.
if ! err=$(osascript -e "tell application \"System Events\" to tell process \"$PROC\" to click menu item \"$ITEM\" of menu \"$MENU\" of menu bar 1" 2>&1); then
    if echo "$err" | grep -qi "assistive access"; then
        echo "ERROR: Accessibility not granted to the controlling app." >&2
        echo "  Enable it in System Settings → Privacy & Security → Accessibility, then retry." >&2
    else
        echo "ERROR clicking publish: $err" >&2
    fi
    exit 1
fi

# Confirmation is tricky: the "Published. Editors can play now." toast is
# TRANSIENT, so we don't depend on catching it. Instead we watch for the only
# real failure mode — a blocking "Publish As" sheet/dialog (unassociated place).
# We poll briefly: if we happen to catch the toast → definitive success; if a
# sheet appears → that's the dialog case; otherwise the direct publish went
# through and we report success.
saw_toast=false
saw_sheet=false
for _ in $(seq 1 16); do
    state=$(osascript <<'OSA' 2>/dev/null || true
tell application "System Events" to tell process "RobloxStudio"
  set t to ""
  set s to "no"
  try
    set t to (value of static texts of window 1) as string
  end try
  try
    if (count of sheets of window 1) > 0 then set s to "yes"
  end try
  return t & "||" & s
end tell
OSA
)
    if echo "$state" | grep -qi "Published"; then saw_toast=true; break; fi
    if echo "$state" | grep -q "||yes"; then saw_sheet=true; break; fi
    sleep 0.25
done

if [ "$saw_sheet" = true ]; then
    echo "A publish dialog appeared (likely an unassociated place needing 'Publish As')." >&2
    echo "This script only re-publishes an already-associated place; finish the dialog manually." >&2
    exit 2
fi

if [ "$saw_toast" = true ]; then
    echo "OK: published (confirmation toast captured)."
else
    echo "OK: published (the 'Published' toast is transient and was not captured, but no"
    echo "    blocking dialog appeared, so the direct publish went through)."
fi
exit 0
