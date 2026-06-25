try
  set repoRoot to "__REPO_ROOT__"
  set sourcesFile to repoRoot & "/scripts/lock-in-music-sources.tsv"
  set runnerScript to repoRoot & "/scripts/lock-in-headphones.sh"

  set sourceData to do shell script "/usr/bin/python3 - " & quoted form of sourcesFile & " <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.exists():
    raise SystemExit('Missing music sources file: ' + str(path))

for raw_line in path.read_text().splitlines():
    line = raw_line.strip()
    if not line or line.startswith('#'):
        continue
    if '\t' not in line:
        continue
    label, source = line.split('\t', 1)
    label = label.strip()
    source = source.strip()
    if label and source:
        print(label + '\t' + source)
PY"

  set sourceLines to paragraphs of sourceData
  set musicOptions to {}
  repeat with sourceLine in sourceLines
    set AppleScript's text item delimiters to tab
    set sourceParts to text items of sourceLine
    set AppleScript's text item delimiters to ""
    if (count of sourceParts) is greater than or equal to 2 then
      set end of musicOptions to item 1 of sourceParts
    end if
  end repeat

  set end of musicOptions to "Custom URL"
  set end of musicOptions to "Headphones Only"

  set selectedMusic to choose from list musicOptions with title "Lock In" with prompt "Choose music source:" default items {"Focus Noise"} without multiple selections allowed
  if selectedMusic is false then return

  set musicSource to item 1 of selectedMusic
  set selectedLabel to musicSource

  if musicSource is "Custom URL" then
    set musicSource to text returned of (display dialog "Paste music URL:" default answer "" buttons {"Cancel", "Play"} default button "Play")
    if musicSource is "" then return
    set selectedLabel to "Custom URL"
  else if musicSource is not "Headphones Only" then
    repeat with sourceLine in sourceLines
      set AppleScript's text item delimiters to tab
      set sourceParts to text items of sourceLine
      set AppleScript's text item delimiters to ""
      if (count of sourceParts) is greater than or equal to 2 then
        if item 1 of sourceParts is musicSource then
          set musicSource to item 2 of sourceParts
          exit repeat
        end if
      end if
    end repeat
  end if

  set lockInOutput to do shell script quoted form of runnerScript & " " & quoted form of musicSource & " 2>&1"
  display notification selectedLabel & " ready on beats4" with title "Lock In"
on error errMsg number errNum
  set AppleScript's text item delimiters to ""
  if errNum is -128 then return
  display dialog "Lock In failed:" & return & return & errMsg buttons {"OK"} default button "OK" with icon caution
end try

