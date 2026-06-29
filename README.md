# Smart File Organizer

Automatically sorts files from `~/Downloads` into categorized folders by extension.
- **Linux**: systemd path watcher triggers `organizer.sh`
- **Windows**: PowerShell `FileSystemWatcher` via `organizer.ps1`

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

## Linux

### Usage

```bash
./organizer.sh                    # scan ~/Downloads
./organizer.sh --source ~/Desktop # scan another directory
./organizer.sh --dry-run          # preview without moving
```

### Service management

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

### Setup

Service files are symlinked to `~/.config/systemd/user/`. If you move the project, re-link:

```bash
ln -sf /path/to/organizer.service ~/.config/systemd/user/
ln -sf /path/to/organizer.path ~/.config/systemd/user/
systemctl --user daemon-reload
```

### Loop protection

The script uses **`flock`** and a **5-second cooldown** to prevent rapid re-triggers when moved files modify Downloads. The systemd unit has `StartLimitIntervalSec=30` / `StartLimitBurst=10`, and the path unit uses `PathChanged` (not `PathModified`) to ignore attribute-only events.

---

## Windows

### Usage

```powershell
.\organizer.ps1                    # scan ~\Downloads
.\organizer.ps1 -Source ~\Desktop  # scan another directory
.\organizer.ps1 -DryRun            # preview without moving
.\organizer.ps1 -Watch             # persistent FileSystemWatcher
```

### Auto-start on login (Task Scheduler)

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -File `"$HOME\Smart File Org\organizer.ps1`" -Watch"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "SmartFileOrganizer" -Action $action -Trigger $trigger
```

### Loop protection

Uses a **named `System.Threading.Mutex`** and a **5-second cooldown** file to prevent overlapping and rapid re-triggers.

---

## Testing (GitHub Actions)

Push changes to `organizer.ps1` and the workflow in `.github/workflows/test-organizer.yml` runs on `windows-latest`, testing:
- All 16+ file types route to correct folders
- Code files are excluded
- Name-collision dedup
- Concurrent-run lock
- In-use file skipping
- Image sub-categorization (Screenshot / Named / Unnamed)

## Files

| File | Platform | Purpose |
|---|---|---|
| `organizer.sh` | Linux | Sorting script |
| `organizer.service` | Linux | Systemd unit |
| `organizer.path` | Linux | Systemd path watcher |
| `organizer.ps1` | Windows | Sorting script with `FileSystemWatcher` |
| `.github/workflows/test-organizer.yml` | CI | Windows tests on push |
