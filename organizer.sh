#!/usr/bin/env bash
set -euo pipefail

WATCH_DIR="$HOME/Downloads"
DRY_RUN=false
CODE_EXTS=(
    py js ts jsx tsx html css scss c cpp cxx h hpp hxx
    rs go rb sh bash zsh java kt swift php pl pm lua r
    sql json yaml yml toml xml ps1 bat)

organize_file()
{
    local file="$1"
    local filename dirname basename ext ext_lower

    [ -f "$file" ] || return

    fuser -s "$file" 2>/dev/null && return

    filename="$(basename "$file")"
    dirname="$(dirname "$file")"
    basename="${filename%.*}"
    ext="${filename##*.}"

    [ "$basename" = "$filename" ] && ext=""
    ext_lower="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"

    for code_ext in "${CODE_EXTS[@]}"; do
        if [ "$ext_lower" = "$code_ext" ]; then
            return
        fi
    done

    local dest=""

    case "$ext_lower" in
        jpg|jpeg|png|webp)
            local picname
            picname="$(echo "$basename" | tr '[:upper:]' '[:lower:]')"

            if [[ "$picname" == screenshot* ]]; then
                dest="$HOME/Pictures/Screenshots"
            elif [[ "$basename" =~ ^[a-zA-Z0-9]{60,64}$ ]]; then
                dest="$HOME/Pictures/Unnamed"
            else
                dest="$HOME/Pictures/Named"
            fi
            ;;
    esac

    if [ -z "$dest" ]; then
        case "$ext_lower" in
            pdf)    dest="$HOME/Documents/PDFs" ;;
            txt)    dest="$HOME/Documents/TXTs" ;;
            md)     dest="$HOME/Documents/MDs" ;;
            docx)   dest="$HOME/Documents/DOCX" ;;
            ppt|pptx) dest="$HOME/Documents/PPTs" ;;
            xls|xlsx) dest="$HOME/Documents/XL" ;;
            zip|tar|gz|tgz|rar|7z|AppImage) dest="$HOME/Documents/Zipped" ;;
            mp3|wav|flac|aac|ogg|m4a|wma) dest="$HOME/Music" ;;
            mp4|mkv|avi|mov|wmv|webm|flv) dest="$HOME/Videos" ;;
            gif|bmp|svg) dest="$HOME/Pictures" ;;
            *)      dest="$HOME/Misc" ;;
        esac
    fi

    [ -d "$dest" ] || mkdir -p "$dest"

    local target="$dest/$filename"
    if [ -f "$target" ]; then
        local name_no_ext="${filename%.*}"
        local timestamp
        timestamp="$(date +%s)"
        target="$dest/${name_no_ext}_${timestamp}.$ext"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $file -> $dest/"
    else
        mv "$file" "$target"
        echo "Moved: $file -> $target"
    fi
}

scan_directory()
{
    local dir="$1"
    [ -d "$dir" ] || return
    find "$dir" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' file; do
        organize_file "$file"
    done
}

main()
{
    local target="$WATCH_DIR"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=true ;;
            --source)  shift; target="$1" ;;
            --help)
                echo "Usage: $0 [--dry-run] [--source DIR]"
                exit 0
                ;;
            *) target="$1" ;;
        esac
        shift
    done

    scan_directory "$target"
}
main "$@"
