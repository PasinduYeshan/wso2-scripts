# Check if prerequisites are met.
check_prerequisites() {
    # Check if Python 3 is installed
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: Python 3 is not installed or not found in PATH."
        exit 1
    fi

    if [ "$IS_ALREADY_UNZIPPED" != "true" ]; then
        # Check if zip is installed
        if ! command -v unzip >/dev/null 2>&1; then
            echo "Error: zip is not installed or not found in PATH."
            exit 1
        fi

        # Check if the ZIP file exists
        if [ ! -f "$ZIP_FILE_PATH" ]; then
            echo "Error: $ZIP_FILE_PATH not found."
            exit 1
        fi
    else
        # Check if the unzipped folder exists
        if [ ! -d "$UNZIPPED_IS_PATH" ]; then
            echo "Error: The folder '$UNZIPPED_IS_PATH' does not exist."
            exit 1
        fi
    fi

    # Check if docker is working.
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not installed or not running."
        exit 1
    fi
}

# Check if npm and node are installed.
check_if_node_npm_installed() {
    if ! command -v npm >/dev/null 2>&1; then
        echo "Error: npm is not installed or not found in PATH."
        exit 1
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo "Error: node is not installed or not found in PATH."
        exit 1
    fi
}

# Function to get configuration value by section and key
get_config_value() {
    local section=$1
    local key=$2
    sed -n "/^\[$section\]/, /^\[/p" "$CONFIG_FILE" | 
    grep "^$key=" | 
    cut -d'=' -f2- | 
    sed 's/#.*//' |  # Remove comments
    sed 's/^ *//; s/ *$//' |  # Trim leading and trailing spaces
    sed 's/^"//; s/"$//'  # Remove surrounding quotes
}


CHECKPOINTS_COUNT=1
checkpoint() {
    local message="$1"
    echo -e "\n================================================================================================"
    echo -e "#$CHECKPOINTS_COUNT: $message"
    echo -e "================================================================================================\n"
    CHECKPOINTS_COUNT=$((CHECKPOINTS_COUNT + 1))
}