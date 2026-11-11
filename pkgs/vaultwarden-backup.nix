{ pkgs, username, ... }:

pkgs.writeShellScriptBin "vaultwarden-backup" ''
  BACKUP_DIR="/home/${username}/Backups/vaultwarden"
  SERVER_URL="https://jonsvault.jonnydeates.com"
  DEFAULT_EMAIL="jond7337@gmail.com"
  LOG_FILE="/tmp/vaultwarden-backup.log"
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_FILE="$BACKUP_DIR/vault_backup_$TIMESTAMP.json"

  # Logging function
  log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
  }

  log "=== Starting Vaultwarden Backup ==="

  # Ensure backup directory exists
  mkdir -p "$BACKUP_DIR"
  log "Backup directory: $BACKUP_DIR"

  # Configure server first
  ${pkgs.bitwarden-cli}/bin/bw config server "$SERVER_URL" >> "$LOG_FILE" 2>&1 || true

  # Get current vault status
  STATUS_JSON=$(${pkgs.bitwarden-cli}/bin/bw status 2>> "$LOG_FILE" || echo '{"status":"error"}')
  STATUS=$(echo "$STATUS_JSON" | ${pkgs.jq}/bin/jq -r '.status' 2>/dev/null || echo "error")
  log "Vault status: $STATUS"

  if [ "$STATUS" = "unauthenticated" ]; then
    log "Need to login"

    # Need to login - prompt for email and password
    CREDS=$(${pkgs.yad}/bin/yad --title="Vaultwarden Login" \
      --form \
      --field="Email:" "$DEFAULT_EMAIL" \
      --field="Master Password:":H "" \
      --button="Cancel:1" --button="Login:0" \
      --width=400 --center 2>> "$LOG_FILE")

    if [ $? -ne 0 ]; then
      notify-send -u normal "Vaultwarden Backup" "Backup cancelled by user"
      log "Cancelled by user"
      exit 1
    fi

    EMAIL=$(echo "$CREDS" | cut -d'|' -f1)
    PASSWORD=$(echo "$CREDS" | cut -d'|' -f2)

    if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
      notify-send -u critical "Vaultwarden Backup" "Email and password are required"
      log "Missing credentials"
      exit 1
    fi

    log "Attempting login for $EMAIL"

    # Login to vault
    LOGIN_RESULT=$(${pkgs.bitwarden-cli}/bin/bw login "$EMAIL" "$PASSWORD" --raw 2>&1) || true
    log "Login result length: ''${#LOGIN_RESULT}"

    if [ -z "$LOGIN_RESULT" ] || [[ "$LOGIN_RESULT" == *"error"* ]] || [[ "$LOGIN_RESULT" == *"Invalid"* ]]; then
      notify-send -u critical "Vaultwarden Backup" "Login failed: $LOGIN_RESULT"
      log "Login failed: $LOGIN_RESULT"
      exit 1
    fi

    export BW_SESSION="$LOGIN_RESULT"
    log "Login successful"

  elif [ "$STATUS" = "locked" ]; then
    log "Vault is locked, need to unlock"

    # Vault is locked - prompt for password only
    PASSWORD=$(${pkgs.yad}/bin/yad --title="Unlock Vaultwarden" \
      --entry \
      --entry-label="Master Password:" \
      --hide-text \
      --button="Cancel:1" --button="Unlock:0" \
      --width=400 --center 2>> "$LOG_FILE")

    if [ $? -ne 0 ]; then
      notify-send -u normal "Vaultwarden Backup" "Backup cancelled by user"
      log "Cancelled by user"
      exit 1
    fi

    if [ -z "$PASSWORD" ]; then
      notify-send -u critical "Vaultwarden Backup" "Password is required"
      log "Missing password"
      exit 1
    fi

    log "Attempting unlock"

    # Unlock vault
    UNLOCK_RESULT=$(${pkgs.bitwarden-cli}/bin/bw unlock "$PASSWORD" --raw 2>&1) || true
    log "Unlock result length: ''${#UNLOCK_RESULT}"

    if [ -z "$UNLOCK_RESULT" ] || [[ "$UNLOCK_RESULT" == *"error"* ]] || [[ "$UNLOCK_RESULT" == *"Invalid"* ]]; then
      notify-send -u critical "Vaultwarden Backup" "Unlock failed: $UNLOCK_RESULT"
      log "Unlock failed: $UNLOCK_RESULT"
      exit 1
    fi

    export BW_SESSION="$UNLOCK_RESULT"
    log "Unlock successful"

  elif [ "$STATUS" = "unlocked" ]; then
    log "Vault already unlocked, syncing"
    ${pkgs.bitwarden-cli}/bin/bw sync >> "$LOG_FILE" 2>&1 || true
  else
    notify-send -u critical "Vaultwarden Backup" "Unknown vault status: $STATUS\nCheck log: $LOG_FILE"
    log "Unknown status: $STATUS"
    exit 1
  fi

  log "Starting export to $BACKUP_FILE"

  # Export encrypted backup
  EXPORT_RESULT=$(${pkgs.bitwarden-cli}/bin/bw export --format encrypted_json --output "$BACKUP_FILE" 2>&1) || true
  log "Export result: $EXPORT_RESULT"

  if [ ! -f "$BACKUP_FILE" ]; then
    notify-send -u critical "Vaultwarden Backup" "Export failed: $EXPORT_RESULT\nCheck log: $LOG_FILE"
    log "Export failed - file not created"
    ${pkgs.bitwarden-cli}/bin/bw lock >> "$LOG_FILE" 2>&1 || true
    exit 1
  fi

  # Lock vault for security
  ${pkgs.bitwarden-cli}/bin/bw lock >> "$LOG_FILE" 2>&1 || true
  log "Vault locked"

  # Get file size for notification
  FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  notify-send -u normal "Vaultwarden Backup" "Backup successful!\nFile: $BACKUP_FILE\nSize: $FILE_SIZE"
  log "Backup successful: $BACKUP_FILE ($FILE_SIZE)"
''
