#!/bin/bash

# This script generates a CSV file with the given number of users.
# Usage:
#   ./generate_users.sh <number_of_users> [output_file]
# Example:
#   ./generate_users.sh 2 users.csv
#
# The CSV file will have the following format:
# username,givenname,emailaddress
# user1,john,john@test.com
# user2,jake,jake@test.com

# Function to display usage instructions
usage() {
    echo "Usage: $0 <number_of_users> [output_file]"
    echo "Example: $0 10 users.csv"
    exit 1
}

OUTPUT_FILE="users.csv"

# Check if at least one argument is provided
if [ $# -lt 1 ]; then
    echo "Error: Number of users not specified."
    usage
fi

# Validate that the first argument is a positive integer
if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Number of users must be a positive integer."
    usage
fi

NUMBER_OF_USERS=$1
OUTPUT_FILE=${2:-users.csv}  # Default to users.csv if no output file is specified

# Array of sample given names
GIVEN_NAMES=(
    "John" "Jane" "Alice" "Bob" "Charlie" "Diana" "Eve" "Frank"
    "Grace" "Hank" "Ivy" "Jack" "Karen" "Leo" "Mona" "Nate"
    "Olivia" "Paul" "Quincy" "Rachel" "Steve" "Tina" "Uma" "Victor"
    "Wendy" "Xander" "Yara" "Zack"
)

# Function to generate a random given name from the array
get_random_name() {
    local array_length=${#GIVEN_NAMES[@]}
    local random_index=$(( RANDOM % array_length ))
    echo "${GIVEN_NAMES[$random_index]}"
}

# Create or overwrite the output CSV file and add the header
echo "username,givenname" > "$OUTPUT_FILE"

start_index=200

# Generate user data
for (( i=start_index; i<=NUMBER_OF_USERS+start_index-1; i++ ))
do
    USERNAME="temps$i"
    GIVEN_NAME=$(get_random_name)
    EMAIL_ADDRESS="${USERNAME}@test.com"
    echo "$EMAIL_ADDRESS,$GIVEN_NAME" >> "$OUTPUT_FILE"
done

echo "Successfully generated $NUMBER_OF_USERS users in '$OUTPUT_FILE'."
