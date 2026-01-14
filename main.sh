set -e

API_URL="https://discord.com/api/v10"

install_deps() {
  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y curl jq file
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y curl jq file
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm curl jq file
  elif command -v brew >/dev/null 2>&1; then
    brew install curl jq file
  else
    echo "No supported package manager found. Install curl, jq, file manually."
    exit 1
  fi
}

echo "Checking dependencies..."
install_deps

read -s -p "Enter Discord bot token: " TOKEN
echo

AUTH_HEADER="Authorization: Bot $TOKEN"

BOT_INFO=$(curl -s -H "$AUTH_HEADER" "$API_URL/users/@me")

if ! echo "$BOT_INFO" | jq -e '.id' >/dev/null 2>&1; then
  echo "Invalid token"
  exit 1
fi

BOT_ID=$(echo "$BOT_INFO" | jq -r '.id')
USERNAME=$(echo "$BOT_INFO" | jq -r '.username')
DISCRIMINATOR=$(echo "$BOT_INFO" | jq -r '.discriminator')

clear
echo "Bot information"
echo "---------------"
echo "ID           : $BOT_ID"
echo "Username     : $USERNAME"
echo "Discriminator: $DISCRIMINATOR"
echo

echo "Guilds"
echo "------"
GUILDS=$(curl -s -H "$AUTH_HEADER" "$API_URL/users/@me/guilds")

if [[ $(echo "$GUILDS" | jq length) -eq 0 ]]; then
  echo "No guilds found"
else
  echo "$GUILDS" | jq -r '.[] | "- \(.name) (ID: \(.id))"'
fi

while true; do
  echo
  echo "Actions"
  echo "1) Change bot username"
  echo "2) Change bot avatar"
  echo "3) List channels of a guild"
  echo "4) Create channel invite"
  echo "5) Leave a guild"
  echo "6) Show OAuth2 info"
  echo "7) Generate bot invite URL"
  echo "8) Delete bot (DANGER)"
  echo "9) Exit"
  read -p "Choice: " CHOICE

  case "$CHOICE" in

  1)
    read -p "New bot username: " NEW_NAME
    RESPONSE=$(curl -s -X PATCH \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$NEW_NAME\"}" \
      "$API_URL/users/@me")

    if echo "$RESPONSE" | jq -e '.username' >/dev/null; then
      echo "Username changed to $(echo "$RESPONSE" | jq -r '.username')"
    else
      echo "Failed"
      echo "$RESPONSE" | jq
    fi
    ;;

  2)
    read -p "Path to image (png/jpg): " IMAGE_PATH
    [[ ! -f "$IMAGE_PATH" ]] && echo "File not found" && continue

    MIME=$(file --mime-type -b "$IMAGE_PATH")
    B64=$(base64 -w 0 "$IMAGE_PATH")

    RESPONSE=$(curl -s -X PATCH \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "{\"avatar\":\"data:$MIME;base64,$B64\"}" \
      "$API_URL/users/@me")

    if echo "$RESPONSE" | jq -e '.avatar' >/dev/null; then
      echo "Avatar updated"
    else
      echo "Failed"
      echo "$RESPONSE" | jq
    fi
    ;;

  3)
    read -p "Guild ID: " GUILD_ID
    CHANNELS=$(curl -s -H "$AUTH_HEADER" \
      "$API_URL/guilds/$GUILD_ID/channels")

    echo "$CHANNELS" | jq -r '.[] | "- \(.name) (ID: \(.id))"'
    ;;

  4)
    read -p "Channel ID: " CHANNEL_ID
    read -p "Max uses (0 = unlimited): " MAX_USES
    read -p "Expire after seconds (0 = never): " MAX_AGE

    RESPONSE=$(curl -s -X POST \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "{
        \"max_uses\": $MAX_USES,
        \"max_age\": $MAX_AGE,
        \"temporary\": false
      }" \
      "$API_URL/channels/$CHANNEL_ID/invites")

    if echo "$RESPONSE" | jq -e '.code' >/dev/null; then
      echo "Invite created:"
      echo "https://discord.gg/$(echo "$RESPONSE" | jq -r '.code')"
    else
      echo "Failed"
      echo "$RESPONSE" | jq
    fi
    ;;

  5)
    read -p "Guild ID to leave: " GUILD_ID
    curl -s -X DELETE \
      -H "$AUTH_HEADER" \
      "$API_URL/users/@me/guilds/$GUILD_ID"
    echo "Left guild"
    ;;

  6)
    APP_INFO=$(curl -s -H "$AUTH_HEADER" \
      "$API_URL/applications/@me")
    echo "$APP_INFO" | jq '{id, name, bot_public, bot_require_code_grant}'
    ;;

  7)
    read -p "Permissions integer (ex: 8 = admin): " PERMS
    echo "Invite URL:"
    echo "https://discord.com/oauth2/authorize?client_id=$BOT_ID&permissions=$PERMS&scope=bot%20applications.commands"
    ;;

  8)
    read -p "Type DELETE to confirm: " CONFIRM
    if [[ "$CONFIRM" == "DELETE" ]]; then
      curl -s -X DELETE -H "$AUTH_HEADER" \
        "$API_URL/applications/@me"
      echo "Bot deleted"
      exit 0
    else
      echo "Cancelled"
    fi
    ;;

  9)
    exit 0
    ;;

  *)
    echo "Invalid choice"
    ;;
  esac
done
