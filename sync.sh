#!/bin/bash

# --- Auto-Run in Background ---
if [ "$(ps -o comm= $PPID)" != "nohup" ] && [ "$1" != "--daemon" ]; then
    nohup "$0" --daemon >/dev/null 2>&1 &
    exit
fi

# --- Configuration ---
BOT_TOKEN="TELEGRAM_BOT_API_KEY"
CHAT_ID="RECIPIENT_USER_ID"
LOG_FILE="$HOME/telegram_sync.log"
DB_FILE="$HOME/uploaded_files.db"
UPLOAD_INTERVAL=3600  # Database upload interval in seconds (3600=1 hour)

# Folders to monitor
FOLDERS_TO_WATCH=(
    "/storage/emulated/0/Download"       # Downloads
    "/storage/emulated/0/Pictures"       # Pictures
    "/storage/emulated/0/Videos"         # Videos
    "/storage/emulated/0/Telegram"       # Telegram
    "/storage/emulated/0/DCIM"           # DCIM (Camera)
    "/storage/emulated/0/Movies"         # Movies
    "/storage/emulated/0/Recordings"     # Recordings
    # Add other folders...
)

# Patterns to skip
THUMBNAIL_PATTERNS=(
    ".*/\.thumbnails/.*"
    ".*/Thumbnails/.*"
    ".*THUMB_.*"
    ".*\.thumb.jpg"
    ".*[_-][0-9]+x[0-9]+.*"     # Matches 64x64, 128x128, etc (e.g., icon_64x64.png)
    ".*\.trashed-.*"            # Trashed files
    ".*/\.fs/.*"
)

# --- Global Variables ---
LAST_UPLOAD=0
CHANGES_SINCE_UPLOAD=0

# --- Function: Upload Database ---
upload_db() {
    echo "[$(date)] Uploading database (changes: $CHANGES_SINCE_UPLOAD)..." | tee -a "$LOG_FILE"
    if curl -s -F document=@"$DB_FILE" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}" >/dev/null; then
        echo "[$(date)] Database uploaded successfully!" | tee -a "$LOG_FILE"
        CHANGES_SINCE_UPLOAD=0
        LAST_UPLOAD=$(date +%s)
    else
        echo "[$(date)] Database upload failed!" | tee -a "$LOG_FILE"
    fi
    sleep 1
}

# --- Function: Cleanup Handler ---
cleanup() {
    echo "[$(date)] Script stopping..." | tee -a "$LOG_FILE"
    # Upload if pending changes
    [ $CHANGES_SINCE_UPLOAD -gt 0 ] && upload_db
    exit 0
}
trap cleanup EXIT TERM INT

# --- Core Functions ---

is_thumbnail() {
    local FILE="$1"
    for pattern in "${THUMBNAIL_PATTERNS[@]}"; do
        if [[ "$FILE" =~ $pattern ]]; then
            return 0  # File is a thumbnail
        fi
    done
    return 1  # Not a thumbnail
}

is_duplicate() {
    local FILE="$1"
    if [ -f "$FILE" ]; then
        FILE_HASH=$(md5sum "$FILE" | awk '{print $1}')
        grep -q "$FILE_HASH" "$DB_FILE"
        return $?  # 0=duplicate, 1=new
    fi
    return 1
}


process_file() {
    local FILE_PATH="$1"
    if [ -f "$FILE_PATH" ] && [[ "$FILE_PATH" != *".tmp"* && "$FILE_PATH" != *".part"* ]]; then
        if is_thumbnail "$FILE_PATH"; then
            echo "[$(date)] Skipped (thumbnail): $FILE_PATH" | tee -a "$LOG_FILE"
            return
        fi
        
        if is_duplicate "$FILE_PATH"; then
            echo "[$(date)] Skipped (duplicate): $FILE_PATH" | tee -a "$LOG_FILE"
            return
        fi
        
        FILE_EXT="${FILE_PATH##*.}"
        EXT_LOWER="${FILE_EXT,,}"
        case "$EXT_LOWER" in
            jpg|jpeg|png|webp|mp4)
                echo "[$(date)] Syncing: $FILE_PATH" | tee -a "$LOG_FILE"
                if curl -s -F document=@"$FILE_PATH" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}" >/dev/null; then
                    echo "[$(date)] Success: $FILE_PATH" | tee -a "$LOG_FILE"
                    md5sum "$FILE_PATH" | awk '{print $1}' >> "$DB_FILE"
                    ((CHANGES_SINCE_UPLOAD++))
                else
                    echo "[$(date)] Failed: $FILE_PATH" | tee -a "$LOG_FILE"
                fi
                sleep 1
                ;;
        esac
    fi
}

# --- Initial Sync ---
if [ ! -s "$DB_FILE" ]; then
    echo "[$(date)] Starting initial sync..." | tee -a "$LOG_FILE"
    for FOLDER in "${FOLDERS_TO_WATCH[@]}"; do
        find "$FOLDER" -type f -print0 | while IFS= read -r -d '' FILE; do
            process_file "$FILE"
        done
    done
    echo "[$(date)] Initial sync completed!" | tee -a "$LOG_FILE"
    # Force upload after initial sync
    CHANGES_SINCE_UPLOAD=1
    upload_db
fi

# --- Monitoring Loop ---
echo "[$(date)] Starting monitoring..." | tee -a "$LOG_FILE"
while true; do
    # Wait for filesystem events or timeout
    inotifywait -q -r -e close_write -e moved_to -t $UPLOAD_INTERVAL --format '%w%f' "${FOLDERS_TO_WATCH[@]}" |
    while read -t 10 FILE_PATH; do  # Extra timeout for batch processing
        [ -z "$FILE_PATH" ] && continue
        process_file "$FILE_PATH"
    done
    
    # Timer-based upload check
    NOW=$(date +%s)
    if [ $((NOW - LAST_UPLOAD)) -ge $UPLOAD_INTERVAL ] && [ $CHANGES_SINCE_UPLOAD -gt 0 ]; then
        upload_db
    fi
done
