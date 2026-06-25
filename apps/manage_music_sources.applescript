set repoRoot to "__REPO_ROOT__"
set sourcesFile to repoRoot & "/scripts/lock-in-music-sources.tsv"

on readSources(sourcesFile)
  set sourceData to do shell script "/usr/bin/python3 - " & quoted form of sourcesFile & " <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.touch(exist_ok=True)
for raw_line in path.read_text().splitlines():
    line = raw_line.strip()
    if not line or line.startswith('#') or '\t' not in line:
        continue
    label, source = line.split('\t', 1)
    label = label.strip()
    source = source.strip()
    if label and source:
        print(label + '\t' + source)
PY"
  if sourceData is "" then return {}
  return paragraphs of sourceData
end readSources

try
  set actionChoice to choose from list {"Add Source", "Remove Source", "View Sources"} with title "Music Sources" with prompt "Choose action:" default items {"Add Source"} without multiple selections allowed
  if actionChoice is false then return

  set selectedAction to item 1 of actionChoice

  if selectedAction is "Add Source" then
    set sourceLabel to text returned of (display dialog "Source name:" default answer "" buttons {"Cancel", "Next"} default button "Next")
    if sourceLabel is "" then return

    set sourceValue to text returned of (display dialog "Playlist name or music URL:" default answer "" buttons {"Cancel", "Add"} default button "Add")
    if sourceValue is "" then return

    do shell script "/usr/bin/python3 - " & quoted form of sourcesFile & " " & quoted form of sourceLabel & " " & quoted form of sourceValue & " <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
label = sys.argv[2].strip()
source = sys.argv[3].strip()

if not label or not source:
    raise SystemExit('Label and source are required.')
if '\\t' in label or '\\n' in label or '\\r' in label:
    raise SystemExit('Source name cannot contain tabs or newlines.')
if '\\t' in source or '\\n' in source or '\\r' in source:
    raise SystemExit('Source value cannot contain tabs or newlines.')
if label in {'Custom URL', 'Headphones Only'}:
    raise SystemExit('That source name is reserved.')

path.touch(exist_ok=True)
rows = []
replaced = False
for raw_line in path.read_text().splitlines():
    if not raw_line.strip() or raw_line.lstrip().startswith('#') or '\\t' not in raw_line:
        continue
    existing_label, existing_source = raw_line.split('\\t', 1)
    existing_label = existing_label.strip()
    existing_source = existing_source.strip()
    if existing_label == label:
        rows.append((label, source))
        replaced = True
    else:
        rows.append((existing_label, existing_source))

if not replaced:
    rows.append((label, source))

path.write_text(''.join(f'{row_label}\\t{row_source}\\n' for row_label, row_source in rows))
PY"
    display notification sourceLabel & " saved" with title "Music Sources"

  else if selectedAction is "Remove Source" then
    set sourceLines to readSources(sourcesFile)
    if sourceLines is {} then
      display dialog "No music sources to remove." buttons {"OK"} default button "OK"
      return
    end if

    set sourceLabels to {}
    repeat with sourceLine in sourceLines
      set AppleScript's text item delimiters to tab
      set sourceParts to text items of sourceLine
      set AppleScript's text item delimiters to ""
      if (count of sourceParts) is greater than or equal to 2 then set end of sourceLabels to item 1 of sourceParts
    end repeat

    set removeChoice to choose from list sourceLabels with title "Music Sources" with prompt "Remove source:" without multiple selections allowed
    if removeChoice is false then return

    set removeLabel to item 1 of removeChoice
    do shell script "/usr/bin/python3 - " & quoted form of sourcesFile & " " & quoted form of removeLabel & " <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
remove_label = sys.argv[2]
rows = []

for raw_line in path.read_text().splitlines():
    if not raw_line.strip() or raw_line.lstrip().startswith('#') or '\\t' not in raw_line:
        continue
    label, source = raw_line.split('\\t', 1)
    label = label.strip()
    source = source.strip()
    if label and source and label != remove_label:
        rows.append((label, source))

path.write_text(''.join(f'{label}\\t{source}\\n' for label, source in rows))
PY"
    display notification removeLabel & " removed" with title "Music Sources"

  else if selectedAction is "View Sources" then
    set sourceLines to readSources(sourcesFile)
    if sourceLines is {} then
      set sourceSummary to "No music sources configured."
    else
      set sourceSummary to ""
      repeat with sourceLine in sourceLines
        set AppleScript's text item delimiters to tab
        set sourceParts to text items of sourceLine
        set AppleScript's text item delimiters to ""
        if (count of sourceParts) is greater than or equal to 2 then
          set sourceSummary to sourceSummary & item 1 of sourceParts & " -> " & item 2 of sourceParts & return
        end if
      end repeat
    end if
    display dialog sourceSummary buttons {"OK"} default button "OK"
  end if
on error errMsg number errNum
  set AppleScript's text item delimiters to ""
  if errNum is -128 then return
  display dialog "Music source action failed:" & return & return & errMsg buttons {"OK"} default button "OK" with icon caution
end try

