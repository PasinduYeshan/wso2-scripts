export BASE_URL=https://localhost:9443
export CALL_BACK_URL=http://localhost:3000
export CLIENT_ID=
export CLIENT_SECRET=
export GRANT_TYPE=authorization_code
export SCOPE=openid+profile+email+SYSTEM
export AUTH_ENDPOINT=$BASE_URL/oauth2/authorize
export TOKEN_ENDPOINT=$BASE_URL/oauth2/token

echo "$AUTH_ENDPOINT?scope=$SCOPE&response_type=code&redirect_uri=$CALL_BACK_URL&client_id=$CLIENT_ID"

read -p 'Code : ' CODE

# Capture the response from curl into a variable
RESPONSE=$(curl -k --user $CLIENT_ID:$CLIENT_SECRET -d "grant_type=$GRANT_TYPE&scope=$SCOPE&code=$CODE&redirect_uri=$CALL_BACK_URL" $TOKEN_ENDPOINT)
echo $RESPONSE | jq .

# Extract the ID token from the RESPONSE
ID_TOKEN=$(echo "$RESPONSE" | jq -r .id_token)

if [ -n "$ID_TOKEN" ] && [ "$ID_TOKEN" != "null" ]; then
  echo "Decoding ID Token payload:"

  # Function to decode Base64 URL-encoded strings
  _decode_base64_url() {
    local len=$((${#1} % 4))
    local result="$1"
    if [ $len -eq 2 ]; then result="$1"'=='
    elif [ $len -eq 3 ]; then result="$1"'=' 
    fi
    echo "$result" | tr '_-' '/+' | base64 -d
  }

  # Function to decode JWT; either header (1) or payload (2, default)
  decode_jwt() {
    local data=$(_decode_base64_url $(echo -n $1 | cut -d "." -f ${2:-2}))
    echo "$data" | jq .
  }

  decode_jwt $ID_TOKEN 2
else
  echo "No valid ID token found in the response."
fi
