# Smart File Organizer

Automatically sorts files from `~/Downloads` into categorized folders by extension. Runs as a systemd service for real-time sorting, or standalone for one-off scans.

## How it works

Systemd watches `~/Downloads` via `organizer.path`. When a new file lands, it triggers `organizer.service` which runs `organizer.sh` to sort it.

## Sorted structure

```
~/Pictures/
├── Screenshots/   # Files starting with "Screenshot" (.jpg/.png/.webp)
├── Named/         # User-named images
└── Unnamed/       # 60-64 char random filenames

~/Documents/
├── PDFs/          # .pdf
├── TXTs/          # .txt
├── MDs/           # .md
├── DOCX/          # .docx
├── PPTs/          # .ppt .pptx
├── XL/            # .xls .xlsx
└── Zipped/        # .zip .tar .gz .tgz .rar .7z .AppImage

~/Music/           # .mp3 .wav .flac .aac .ogg .m4a .wma
~/Videos/          # .mp4 .mkv .avi .mov .wmv .webm .flv
~/Misc/            # Everything else
```

Code files (`.py`, `.js`, `.ts`, `.html`, `.css`, etc.) are left untouched in Downloads for manual handling.

## Usage

```bash
# Standalone — sort a directory once
./organizer.sh
./organizer.sh --source ~/Desktop
./organizer.sh --dry-run    # preview without moving
```

## Service management

```bash
# Enable (auto-start on login)
systemctl --user enable --now organizer.path

# Status
systemctl --user status organizer.path

# Logs
journalctl --user -u organizer.service -n 20

# Stop
systemctl --user stop organizer.path

# Disable
systemctl --user disable organizer.path
```

## Setup

The service files are already symlinked to `~/.config/systemd/user/`. If you move the project, re-link:

```bash
ln -sf /path/to/organizer.service ~/.config/systemd/user/
ln -sf /path/to/organizer.path ~/.config/systemd/user/
systemctl --user daemon-reload
```

## Files

| File | Purpose |
|---|---|
| `organizer.sh` | Sorting logic |
| `organizer.service` | Systemd unit that runs the script |
| `organizer.path` | Systemd path watcher for `~/Downloads` |
