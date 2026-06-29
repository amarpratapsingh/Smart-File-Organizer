param(
    [switch]$Watch,
    [switch]$DryRun,
    [string]$Source = "$HOME\Downloads"
)

$tempDir = if ($env:TEMP) { $env:TEMP } else { '/tmp' }
$CooldownFile = Join-Path $tempDir 'organizer.cooldown'
$CooldownSecs = 5
$LockFile = Join-Path $tempDir 'organizer.lock'
$CODE_EXTS = @(
    'py','js','ts','jsx','tsx','html','css','scss','c','cpp','cxx','h','hpp','hxx',
    'rs','go','rb','sh','bash','zsh','java','kt','swift','php','pl','pm','lua','r',
    'sql','json','yaml','yml','toml','xml','ps1','bat'
)

function IsFileLocked {
    param([string]$Path)
    try {
        $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $fs.Close()
        return $false
    } catch {
        return $true
    }
}

function Get-CategoryDest {
    param([string]$Ext)
    switch -Wildcard ($Ext.ToLower()) {
        'jpg'  { return 'Pictures\Named' }; 'jpeg' { return 'Pictures\Named' }
        'png'  { return 'Pictures\Named' }; 'webp' { return 'Pictures\Named' }
        'pdf'  { return 'Documents\PDFs' }
        'txt'  { return 'Documents\TXTs' }
        'md'   { return 'Documents\MDs' }
        'docx' { return 'Documents\DOCX' }
        'ppt'  { return 'Documents\PPTs' }; 'pptx' { return 'Documents\PPTs' }
        'xls'  { return 'Documents\XL' }; 'xlsx' { return 'Documents\XL' }
        'zip'  { return 'Documents\Zipped' }; 'tar'  { return 'Documents\Zipped' }
        'gz'   { return 'Documents\Zipped' }; 'tgz'  { return 'Documents\Zipped' }
        'rar'  { return 'Documents\Zipped' }; '7z'   { return 'Documents\Zipped' }
        'appimage' { return 'Documents\Zipped' }
        'mp3'  { return 'Music' }; 'wav' { return 'Music' }; 'flac' { return 'Music' }
        'aac'  { return 'Music' }; 'ogg' { return 'Music' }; 'm4a'  { return 'Music' }
        'wma'  { return 'Music' }
        'mp4'  { return 'Videos' }; 'mkv' { return 'Videos' }; 'avi' { return 'Videos' }
        'mov'  { return 'Videos' }; 'wmv' { return 'Videos' }; 'webm' { return 'Videos' }
        'flv'  { return 'Videos' }
        'gif'  { return 'Pictures' }; 'bmp' { return 'Pictures' }; 'svg' { return 'Pictures' }
        default { return 'Misc' }
    }
}

function IsCodeExt {
    param([string]$Ext)
    return $CODE_EXTS -contains $Ext.ToLower()
}

function IsScreenshot {
    param([string]$Name)
    return $Name.ToLower().StartsWith('screenshot')
}

function IsUnnamedImage {
    param([string]$Name)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    return ($base -match '^[a-zA-Z0-9]{60,64}$')
}

function Move-FileWithDedup {
    param([string]$File, [string]$DestDir)
    $name = [System.IO.Path]::GetFileName($File)
    $target = Join-Path $DestDir $name
    if (Test-Path $target) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
        $ext = [System.IO.Path]::GetExtension($name)
        $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $target = Join-Path $DestDir "${base}_${ts}${ext}"
    }
    if ($DryRun) {
        Write-Host "[DRY-RUN] $File -> $DestDir\"
    } else {
        Move-Item -LiteralPath $File -Destination $target -Force
        Write-Host "Moved: $File -> $target"
    }
}

function Organize-File {
    param([string]$File)
    if (-not (Test-Path $File -PathType Leaf)) { return }
    if (IsFileLocked $File) { return }

    $ext = [System.IO.Path]::GetExtension($File).TrimStart('.')
    if ([string]::IsNullOrEmpty($ext)) { $ext = '' }
    if (IsCodeExt $ext) { return }

    $destRel = Get-CategoryDest $ext
    $filename = [System.IO.Path]::GetFileName($File)

    if ($ext -in @('jpg','jpeg','png','webp')) {
        if (IsScreenshot $filename) {
            $destRel = 'Pictures\Screenshots'
        } elseif (IsUnnamedImage $filename) {
            $destRel = 'Pictures\Unnamed'
        } else {
            $destRel = 'Pictures\Named'
        }
    }

    $destDir = Join-Path $HOME $destRel
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Move-FileWithDedup -File $File -DestDir $destDir
}

function Scan-Directory {
    param([string]$Dir)
    if (-not (Test-Path $Dir -PathType Container)) { return }
    Get-ChildItem -Path $Dir -File | ForEach-Object {
        Organize-File $_.FullName
    }
}

function Enter-CooldownGuard {
    if (Test-Path $CooldownFile) {
        $last = Get-Content $CooldownFile -Raw
        $last = [int]$last.Trim()
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if (($now - $last) -lt $CooldownSecs) { return $false }
    }
    [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() | Out-File $CooldownFile -Force
    return $true
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\SmartFileOrganizer')
if (-not $mutex.WaitOne(0)) {
    Write-Host "Another instance is already running. Exiting."
    exit 0
}

try {
    if (-not (Enter-CooldownGuard)) { exit 0 }

    if ($Watch) {
        Write-Host "Watching $Source for new files... (Ctrl+C to stop)"
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $Source
        $watcher.IncludeSubdirectories = $false
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::Size
        $watcher.EnableRaisingEvents = $true

        $action = {
            $path = $Event.SourceEventArgs.FullPath
            if (Test-Path $path -PathType Leaf) {
                Organize-File $path
            }
        }

        Register-ObjectEvent $watcher 'Created' -Action $action | Out-Null
        Register-ObjectEvent $watcher 'Changed' -Action $action | Out-Null

        try {
            Wait-Event
        } finally {
            $watcher.EnableRaisingEvents = $false
            $watcher.Dispose()
            Get-EventSubscriber | Unregister-Event
        }
    } else {
        Scan-Directory $Source
    }
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
