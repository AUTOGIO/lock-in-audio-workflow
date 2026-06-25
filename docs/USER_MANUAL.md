# User Manual

## Purpose

This workflow reduces the start-of-session audio setup to two desktop actions:

- `Lock In Headphones.app`
- `Manage Music Sources.app`

The first action prepares the listening environment. The second action manages the available music sources.

## What Happens During Lock In

When `Lock In Headphones.app` runs, it performs the following sequence:

1. Opens `Boom 3D.app`
2. Waits for Boom 3D to restore its saved local configuration
3. Verifies Bluetooth is enabled
4. Connects the configured headphones
5. Routes audio output to the headphones
6. Routes audio input to the headphones when available
7. Prompts for a music source
8. Starts the selected playlist, URL, or no-music mode

## Build and Install

From the repository root:

```bash
chmod +x ./scripts/build_desktop_apps.sh ./scripts/lock-in-headphones.sh
./scripts/build_desktop_apps.sh
```

The generated apps will appear in `dist/`.

To place them on the Desktop:

```bash
cp -R "./dist/Lock In Headphones.app" "${HOME}/Desktop/"
cp -R "./dist/Manage Music Sources.app" "${HOME}/Desktop/"
```

## Desktop Actions

### Lock In Headphones

This action presents a source picker built from `scripts/lock-in-music-sources.tsv` and two reserved options:

- `Custom URL`
- `Headphones Only`

Source behavior:

- Named playlist entry: plays in Apple Music
- URL entry: opens via the default macOS URL handler
- `Custom URL`: prompts for a URL at runtime
- `Headphones Only`: skips music startup

### Manage Music Sources

This action supports:

- `Add Source`
- `Remove Source`
- `View Sources`

#### Add Source

Use this to add either:

- an Apple Music playlist name
- a web URL such as YouTube or TuneIn

Rules:

- Source names must be unique
- Source names cannot contain tabs or newlines
- Reserved names cannot be reused:
  - `Custom URL`
  - `Headphones Only`

#### Remove Source

Removes one named source from the TSV registry.

#### View Sources

Displays all configured labels and their underlying values.

## Editing the Source Registry Manually

The file format is TSV:

```text
Label<TAB>Playlist or URL
```

Example:

```text
YouTube Playlist	https://youtube.com/playlist?list=PLieRSdP0b5KKYe02bLmr778MeMfX6HkUk&si=WfJEHKWp6brkXuts
Focus Noise	Focus Noise
```

The workflow ignores:

- blank lines
- lines starting with `#`
- malformed lines without a tab

## Customization Points

The main shell entry point is [scripts/lock-in-headphones.sh](../scripts/lock-in-headphones.sh).

Common edits:

- change headphone name: update `HEADPHONES_NAME`
- change headphone MAC: update `HEADPHONES_MAC`
- change Boom app path: update `BOOM_3D_APP`

## Dependencies

Install required CLI tools:

```bash
brew install blueutil switchaudio-osx
```

## Failure Modes

### Boom 3D missing

Symptom:

- workflow exits before Bluetooth or music steps

Fix:

- install `Boom 3D.app` in `/Applications`

### Bluetooth off

Symptom:

- script exits with a Bluetooth unavailable message

Fix:

- turn Bluetooth on in System Settings

### Headphones do not connect

Symptom:

- routing never completes

Fix:

- confirm the headset is powered on
- confirm the MAC address is correct
- confirm the device is already paired with macOS

### Music step times out

Symptom:

- headphones connect but playback does not start

Fix:

- verify Apple Music can play the named playlist
- verify the URL opens correctly
- rerun after Music finishes launching

## Operational Best Practices

- Keep Boom 3D in the preferred saved state before running the workflow.
- Use named sources for stable daily options.
- Keep ad hoc streaming links in `Custom URL`.
- Version-control `lock-in-music-sources.tsv` after meaningful source changes.
