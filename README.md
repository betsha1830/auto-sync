# 📱 Android-Telegram File Sync Bot

A Bash script to automatically sync files from your Android device to Telegram. Monitors specified folders, uploads new files via a Telegram bot, and maintains a database to prevent duplicates. This script is optimized for media files (photos, videos) but can be modified for other file types.

## 📂 Monitored Locations

The script automatically monitors these default folders:

```bash
"/storage/emulated/0/Download"     # Downloads
"/storage/emulated/0/Pictures"     # Pictures
"/storage/emulated/0/Videos"       # Videos
"/storage/emulated/0/Telegram"     # Telegram
"/storage/emulated/0/DCIM"         # DCIM (Camera)
"/storage/emulated/0/Movies"       # Movies
"/storage/emulated/0/Recordings"   # Recordings
```

## 🚫 Exclusion Rules

The script automatically skips these patterns:

```regex
.*/\.thumbnails/.*        # Thumbnail directories
.*/Thumbnails/.*          # Alternative thumbnail storage
.*THUMB_.*                # Thumbnail files
.*\.thumb.jpg             # Thumbnail images
.*[_-][0-9]+x[0-9]+.*     # Dimension-based names (e.g., 64x64)
.*\.trashed-.*            # Trashed files marker
.*/\.fs/.*                # System folders
.*/\.gs_fs0/.*            # Additional protected directories
```

## ✨ Features

- 🕵️ **Auto-Sync**: Continuous monitoring of multiple folders
- 🤖 **Telegram Integration**: Direct uploads via Bot API
- 🔒 **Duplicate Prevention**: MD5 checksum verification
- 🚫 **Smart Filtering**:
  - Skips thumbnails and temporary files
  - Ignores files <1KB in size
  - Excludes system/protected directories
- ⏰ **Scheduled Backups**: Automatic hourly database backups
- 📝 **Activity Logging**: Detailed operation records
- 🔄 **Background Operation**: Persistent daemon mode

## 📋 Prerequisites

- Android 8+ with Termux
- Telegram account with:
  - Active bot from @BotFather
  - Valid bot API token
  - Destination chat/channel ID

## 🛠 Setup & Installation

### 1. Install Required Packages

```bash
pkg update && pkg upgrade
pkg install termux-api curl inotify-tools
termux-setup-storage
```

### 2. Download and Configure Script

```bash
curl -O https://example.com/auto-sync.sh
chmod +x auto-sync.sh
nano auto-sync.sh
```

### 3. Required Configuration

```bash
# ======= REQUIRED CONFIG ========
BOT_TOKEN="YOUR_BOT_TOKEN"    # From @BotFather
CHAT_ID="YOUR_CHAT_ID"        # Use /getUpdates to find
```

## 💻 Usage

### Start Synchronization

```bash
./auto-sync.sh
```

### Monitor Activities

```bash
tail -f ~/telegram_sync.log
```

### Stop the Service

```bash
pkill -f auto-sync.sh
```

### Force Full Resync

```bash
rm ~/uploaded_files.db
./auto-sync.sh
```

## ⚙ Configuration Options

Customize these variables in the script:

```bash
# File handling
UPLOAD_INTERVAL=3600        # Database backup frequency (seconds)
MIN_FILE_SIZE=1024         # 1KB minimum file size

# Path management
FOLDERS_TO_WATCH=(          # Add/remove monitored folders
    "/storage/emulated/0/DCIM"
    "/storage/emulated/0/Download"
)
```

## 🔍 Troubleshooting

### Common Issues & Solutions

#### Permission Denied

```bash
termux-setup-storage
termux-wake-lock
```

#### Files Not Uploading

```bash
# Verify API connection
curl -F document=@test.jpg "https://api.telegram.org/bot$BOT_TOKEN/sendDocument?chat_id=$CHAT_ID"
```

#### High Battery Usage

- Disable battery optimization for Termux
- Add `termux-wake-lock` to script header

## 🔒 Security Best Practices

- Store bot tokens securely
- Use private Telegram channels
- Regularly rotate backup databases
- Audit exclusion patterns periodically
- Avoid syncing sensitive unencrypted files

## 📜 License

This project is licensed under the GNU GPLv3 License
