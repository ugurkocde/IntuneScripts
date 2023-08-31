#!/bin/bash

# Fill in your domain, factory_auth and flock_id here
DOMAIN=".canary.tools" # Example: "ABS123.canary.tools"
FACTORY_AUTH="" # Example: "1234567890abcdef1234567890abcdef"
FLOCK_ID="flock:" # Example: "flock:1234567890abcdef1234567890abcdef"

# Checking for dependencies
command -v curl >/dev/null 2>&1 || {
    echo >&2 "curl is not installed. Attempting to install with brew."
    if ! command -v brew >/dev/null 2>&1; then
        echo >&2 "Homebrew is not installed. Installing now..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install curl
}

command -v jq >/dev/null 2>&1 || {
    echo >&2 "jq is not installed. Attempting to install with brew."
    if ! command -v brew >/dev/null 2>&1; then
        echo >&2 "Homebrew is not installed. Installing now..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install jq
}

# Uncomment the line below and comment the TOKEN_SELECTION line for a specific token type.
# TOKEN_SELECTION='aws'
TOKEN_SELECTION=('aws' 'azure' 'wireguard' 'msword-macro' 'pdf-acrobat-reader')

RANDOM_TOKEN=${TOKEN_SELECTION[$RANDOM % ${#TOKEN_SELECTION[@]}]}

case $RANDOM_TOKEN in
"aws")
    TARGET_DIRECTORY="./aws"
    TOKEN_TYPE="aws-id"
    TOKEN_FILENAME="credentials"
    ;;
"azure")
    TARGET_DIRECTORY="./azure"
    TOKEN_TYPE="azure-id"
    TOKEN_FILENAME="azure_cert.zip"
    ;;
"wireguard")
    TARGET_DIRECTORY="./wireguard"
    TOKEN_TYPE="wireguard"
    TOKEN_FILENAME="wireguard.conf"
    ;;
"msword-macro")
    TARGET_DIRECTORY="./word"
    TOKEN_TYPE="msword-macro"
    TOKEN_FILENAME="test.docm"
    ;;
"pdf-acrobat-reader")
    TARGET_DIRECTORY="./pdf"
    TOKEN_TYPE="pdf-acrobat-reader"
    TOKEN_FILENAME="test.pdf"
    ;;
*)
    echo "Invalid token type."
    exit 1
    ;;
esac

API_BASE_URL='/api/v1'

# Check Parameters
if [[ -z "$FACTORY_AUTH" || -z "$TOKEN_TYPE" || -z "$FLOCK_ID" ]]; then
    echo "One or more required parameters are missing or empty. Please check your input."
    exit 1
fi

# Check Directory
if [[ ! -d "$TARGET_DIRECTORY" ]]; then
    mkdir -p "$TARGET_DIRECTORY"
fi

OUTPUT_FILE_NAME="$TARGET_DIRECTORY/$TOKEN_FILENAME"

# If file exists, skip
if [[ -f "$OUTPUT_FILE_NAME" ]]; then
    echo "Skipping $OUTPUT_FILE_NAME, file already exists."
    exit 1
fi

# Create Token on Console
TOKEN_NAME="$OUTPUT_FILE_NAME"
POST_DATA="factory_auth=$FACTORY_AUTH&kind=$TOKEN_TYPE&flock_id=$FLOCK_ID&memo=$(hostname) - $TOKEN_NAME"

if [[ "$TOKEN_TYPE" == "azure-id" ]]; then
    POST_DATA="$POST_DATA&azure_id_cert_file_name=finance_az_prod.pem"
fi

CREATE_RESULT=$(curl -s -L -X POST "https://$DOMAIN$API_BASE_URL/canarytoken/factory/create" -d "$POST_DATA")

RESULT=$(echo "$CREATE_RESULT" | jq -r '.result')

if [[ "$RESULT" != "success" ]]; then
    echo "Creation of $TOKEN_NAME failed."
    exit 1
fi

TOKEN_ID=$(echo "$CREATE_RESULT" | jq -r '.canarytoken.canarytoken')

# Download Token
curl -s -L -X GET "https://$DOMAIN$API_BASE_URL/canarytoken/factory/download?factory_auth=$FACTORY_AUTH&canarytoken=$TOKEN_ID" -o "$OUTPUT_FILE_NAME"

if [[ $? -ne 0 ]]; then
    echo "Failed to download token."
    exit 1
fi

echo "Token Successfully written to destination: '$OUTPUT_FILE_NAME'."