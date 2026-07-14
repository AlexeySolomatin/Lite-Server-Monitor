#!/bin/bash
TOKEN="8955383624:AAH27c-j5gUobyMgJ4swofJTrFizMvDkIAY"
CHAT_ID="57731894"
HOST=$(hostname)
MESSAGE="⚠️ [$HOST]: $1"

curl -s -X POST "https://telegram.org" \
    -d chat_id="$CHAT_ID" \
    -d text="$MESSAGE" \
    -d parse_mode="Markdown" > /dev/null
