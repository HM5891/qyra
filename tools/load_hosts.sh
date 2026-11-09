#!/data/data/com.termux/files/usr/bin/bash
# Load a hosts backup (qyra-starter-backup*.zip or qyra-admin-backup*.zip from Downloads) straight into
# your private qyra-admin repo. Close the Qyra Admin app first.   Run:  bash ~/qyra/tools/load_hosts.sh
REPO="HM5891/qyra-admin"; T="$HOME/.qyra-load"
Z=$(ls -t ~/storage/downloads/qyra-starter-backup*.zip ~/storage/downloads/qyra-admin-backup*.zip 2>/dev/null | head -1)
[ -n "$Z" ] || { echo "No qyra-starter-backup or qyra-admin-backup zip found in Downloads"; exit 1; }
echo "Using: $Z"
rm -rf "$T" && mkdir -p "$T" && unzip -oq "$Z" -d "$T" || { echo "Could not open the zip"; exit 1; }
[ -s "$T/backup.json" ] || { echo "That zip has no backup.json"; rm -rf "$T"; exit 1; }
if ls "$T"/photos/*.jpg >/dev/null 2>&1; then echo "This backup has photos: use Restore backup in Chrome admin instead (it uploads photos)."; rm -rf "$T"; exit 1; fi
SHA=$(gh api "repos/$REPO/contents/admin.json" -q .sha 2>/dev/null); [[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || SHA=
{ printf '{"message":"Load hosts from %s","content":"%s"' "$(basename "$Z")" "$(base64 -w0 "$T/backup.json")"; [ -n "$SHA" ] && printf ',"sha":"%s"' "$SHA"; printf '}'; } > "$T/body.json"
if gh api -X PUT "repos/$REPO/contents/admin.json" --input "$T/body.json" -q .commit.sha >/dev/null; then
  echo "LOADED $(grep -c '"prompts"' "$T/backup.json") HOSTS. Open Qyra Admin now."
else echo "GitHub refused the upload. Check: gh auth status"; fi
rm -rf "$T"
