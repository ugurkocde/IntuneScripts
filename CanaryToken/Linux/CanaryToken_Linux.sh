#!/bin/bash

# Fill in your domain, factory_auth and flock_id here
DOMAIN=".canary.tools" # Example: "ABS123.canary.tools"
FACTORY_AUTH="" # Example: "1234567890abcdef1234567890abcdef"
FLOCK_ID="flock:" # Example: "flock:1234567890abcdef1234567890abcdef"

# Check for jq and curl
if ! command -v jq &> /dev/null; then
    echo "jq is not installed, installing now..."
    sudo apt-get update && sudo apt-get install -y jq
fi

if ! command -v curl &> /dev/null; then
    echo "curl is not installed, installing now..."
    sudo apt-get update && sudo apt-get install -y curl
fi

# Uncomment the line below and comment the TOKEN_SELECTION line for a specific token type.
# TOKEN_SELECTION='aws'
TOKEN_SELECTION=("aws" "azure" "wireguard" "msword-macro" "pdf-acrobat-reader")

# Randomly select a token
TOKEN=${TOKEN_SELECTION[$RANDOM % ${#TOKEN_SELECTION[@]}]}

# Define token options
declare -A TOKEN_OPTIONS=(
    ["aws,TargetDirectory"]="/opt"
    ["aws,TokenType"]="aws-id"
    ["aws,TokenFilename"]="credentials"

    ["azure,TargetDirectory"]="/opt"
    ["azure,TokenType"]="azure-id"
    ["azure,TokenFilename"]="azure_cert.zip"

    ["wireguard,TargetDirectory"]="/opt"
    ["wireguard,TokenType"]="wireguard"
    ["wireguard,TokenFilename"]="wireguard.conf"

    ["msword-macro,TargetDirectory"]="/opt"
    ["msword-macro,TokenType"]="msword-macro"
    ["msword-macro,TokenFilename"]="test.docm"

    ["pdf-acrobat-reader,TargetDirectory"]="/opt"
    ["pdf-acrobat-reader,TokenType"]="pdf-acrobat-reader"
    ["pdf-acrobat-reader,TokenFilename"]="test.pdf"
)

TOKEN_TYPE=${TOKEN_OPTIONS["$TOKEN,TokenType"]}
TOKEN_FILENAME=${TOKEN_OPTIONS["$TOKEN,TokenFilename"]}
TARGET_DIRECTORY=${TOKEN_OPTIONS["$TOKEN,TargetDirectory"]}

# Check if parameters are set
if [[ -z $FACTORY_AUTH || -z $TOKEN_TYPE || -z $FLOCK_ID ]]; then
    echo "Missing parameters."
    exit 1
fi

# Create target directory if not exist
if [[ ! -d $TARGET_DIRECTORY ]]; then
    mkdir -p $TARGET_DIRECTORY
fi

# Check if token file already exists
OUTPUT_FILENAME="$TARGET_DIRECTORY/$TOKEN_FILENAME"
if [[ -f $OUTPUT_FILENAME ]]; then
    echo "File already exists: $OUTPUT_FILENAME"
    exit 1
fi

# Create token on Console
TOKEN_NAME=$OUTPUT_FILENAME
# Common data for all tokens
POST_DATA="factory_auth=$FACTORY_AUTH&kind=$TOKEN_TYPE&flock_id=$FLOCK_ID&memo=$(hostname)-$TOKEN_NAME"

# If the token is 'azure', append the azure_id_cert_file_name to the POST_DATA
if [[ $TOKEN == "azure" ]]; then
    POST_DATA="$POST_DATA&azure_id_cert_file_name=finance_az_prod.pem"
fi


MAX_RETRY_COUNT=3
RETRY_COUNT=0

while [[ $RETRY_COUNT -lt $MAX_RETRY_COUNT ]]; do
    RESPONSE=$(curl -s -X POST "https://$DOMAIN/api/v1/canarytoken/factory/create" -d $POST_DATA)
    RESULT=$(echo $RESPONSE | jq -r '.result')
    if [[ $RESULT == "success" ]]; then
        TOKEN_ID=$(echo $RESPONSE | jq -r '.canarytoken.canarytoken')
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT+1))
    sleep $((2 * RETRY_COUNT))
done

# Check API response
if [[ $RESULT != "success" ]]; then
    echo "Token creation failed."
    exit 1
fi

# Download the token
curl -s -L -X GET "https://$DOMAIN/api/v1/canarytoken/factory/download?factory_auth=$FACTORY_AUTH&canarytoken=$TOKEN_ID" -o "$OUTPUT_FILENAME"

echo "Token written to: $OUTPUT_FILENAME"