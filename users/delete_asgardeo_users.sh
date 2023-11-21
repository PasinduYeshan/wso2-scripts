#!/bin/bash

TOKEN="7b23f9d6-4ce1-37a1-846b-163a98c915f3"
ORG_NAME="yeshantest"

DELETION_TOKEN=$TOKEN
BASE_URL="https://dev.api.asgardeo.io/t/$ORG_NAME"

SCIM_USER_URL="$BASE_URL/scim2/Users"
DELETE_API_URL="$BASE_URL/scim2/Bulk"

# Define an array of usernames to ignore.
IGNORE_USERS=("pasindua@wso2.com" "admin")

# Convert the array into a jq-friendly string format.
JQ_IGNORE_USERS=$(printf ",\"%s\"" "${IGNORE_USERS[@]}")
JQ_IGNORE_USERS=[${JQ_IGNORE_USERS:1}]

while true; do
    # Fetch the users.
    RESPONSE=$(curl -k --location "$SCIM_USER_URL" --header "Authorization: Bearer $TOKEN")
    # Extract all user IDs.
    USER_IDS=$(echo $RESPONSE | jq -r --argjson ignore "$JQ_IGNORE_USERS" '.Resources[] | select(.userName as $u | $ignore | index($u) | not) | .id')

    # Check if there are no more users.
    if [[ -z "$USER_IDS" || "$USER_IDS" == "null" ]]; then
        echo "No more users left."
        break
    fi

    # Check if there are no more users.
    if [[ -z "$USER_IDS" || "$USER_IDS" == "null" ]]; then
        echo "No more users left."
        break
    fi

    # Construct the bulk delete operations array from the user IDs.
    DELETE_OPERATIONS=""
    for ID in $USER_IDS; do
        DELETE_OPERATIONS="$DELETE_OPERATIONS,{\"method\": \"DELETE\", \"path\": \"/Users/$ID\"}"
    done
    # Remove leading comma.
    DELETE_OPERATIONS=${DELETE_OPERATIONS:1}

    # Construct the bulk delete payload.
    DELETE_PAYLOAD=$(cat <<EOL
{
    "failOnErrors": 0,
    "schemas": [
        "urn:ietf:params:scim:api:messages:2.0:BulkRequest"
    ],
    "Operations": [$DELETE_OPERATIONS]
}
EOL
)

    # Send the bulk delete request.
    curl -k --location "$DELETE_API_URL" \
         --header 'Content-Type: application/json' \
         --header "Authorization: Bearer $DELETION_TOKEN" \
         --data "$DELETE_PAYLOAD"
         
    # Sleep for a short duration to avoid hammering the server.
    sleep 2
done
