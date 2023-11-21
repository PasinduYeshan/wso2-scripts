#!/bin/bash
SUPER_ORG_PATH="t/carbon.super"
WSO2_TENANT_PATH="t/wso2.com"
SUB_ORG_PATH="o/4fa83369-05df-4d64-88af-d2346c61c57a"

SUPER_BASIC_AUTH="YWRtaW46YWRtaW4="
WSO2_TENANT_BASIC_AUTH="a2ltOmtpbTEyMw==" # kim kim123
SUB_BASIC_AUTH="YWRtaW5AMTAwODRhOGQtMTEzZi00MjExLWEwZDUtZWZlMzZiMDgyMjExOmFkbWlu"

ORG_PATH=$WSO2_TENANT_PATH
BASIC_AUTH=$WSO2_TENANT_BASIC_AUTH

USERS_URL="https://localhost:9443/$ORG_PATH/scim2/Users"
DELETE_URL="https://localhost:9443/$ORG_PATH/scim2/Bulk"

# Define an array of usernames to ignore.
IGNORE_USERS=("admin" "admin1" "kim")

# Convert the array into a jq-friendly string format.
JQ_IGNORE_USERS=$(printf ",\"%s\"" "${IGNORE_USERS[@]}")
JQ_IGNORE_USERS=[${JQ_IGNORE_USERS:1}]

while true; do
    # Fetch the users
    RESPONSE=$(curl -k --location "$USERS_URL" --header "Authorization: Basic $BASIC_AUTH")

    # Extract all user IDs where the user name is not in the ignore list
    USER_IDS=$(echo $RESPONSE | jq -r --argjson ignore "$JQ_IGNORE_USERS" '.Resources[] | select(.userName as $u | $ignore | index($u) | not) | .id')
   
    # Check if there are no more users
    if [[ -z "$USER_IDS" || "$USER_IDS" == "null" ]]; then
        echo "No more users left."
        break
    fi

    # Construct the bulk delete operations array from the user IDs
    DELETE_OPERATIONS=""
    for ID in $USER_IDS; do
        DELETE_OPERATIONS="$DELETE_OPERATIONS,{\"method\": \"DELETE\", \"path\": \"/Users/$ID\"}"
    done
    # Remove leading comma
    DELETE_OPERATIONS=${DELETE_OPERATIONS:1}

    # Construct the bulk delete payload
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

    # Send the bulk delete request
    curl -k --location "$DELETE_URL" \
         --header 'Content-Type: application/json' \
         --header "Authorization: Basic $BASIC_AUTH" \
         --data "$DELETE_PAYLOAD"
         
    # Sleep for a short duration to avoid hammering the server
    sleep 2

done
