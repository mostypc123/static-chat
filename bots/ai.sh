#!/bin/sh
## - name(chat) ##

jq -n --arg m "$ARG" '{model:"command-a-03-2025",messages:[{role:"user",content:$m}]}' |
curl -s https://api.cohere.com/v2/chat \
  -H "Authorization: Bearer $COHERE_KEY" \
  -H "Content-Type: application/json" \
  -d @- |
jq -r '.message.content[0].text // .message // "error"'
