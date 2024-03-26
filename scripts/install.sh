#!/bin/sh

BINARY_NAME="rokit"
REPOSITORY="filiptibell/rokit"

# Make sure we have prerequisites installed: curl + unzip
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: 'curl' is not installed." >&2
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "Error: 'unzip' is not installed." >&2
    exit 1
fi

# Determine OS and architecture for the current system
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
    darwin) OS="macos" ;;
    linux) OS="linux" ;;
    cygwin*|mingw*|msys*) OS="windows" ;;
    *)
        echo "Unsupported OS: $OS" >&2
        exit 1 ;;
esac
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    x86-64) ARCH="x86_64" ;;
    arm64) ARCH="aarch64" ;;
    aarch64) ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Construct file pattern for our desired zip file based on OS + arch
# NOTE: This only works for exact patterns "binary-X.Y.Z-os-arch.zip"
# and WILL break if the version contains extra metadata / pre-release
FILE_PATTERN="${BINARY_NAME}-[0-9]*\\.[0-9]*\\.[0-9]*-${OS}-${ARCH}.zip"

# GitHub API URL for the latest release
API_URL="https://api.github.com/repos/$REPOSITORY/releases/latest"

# Use curl to fetch the latest release data from GitHub API
echo "Downloading latest release..."
RELEASE_JSON_DATA=$(curl --proto '=https' --tlsv1.2 -sSf --connect-timeout 10 --max-time 30 "$API_URL")

# Check if the release was fetched successfully
if [ -z "$RELEASE_JSON_DATA" ] || echo "$RELEASE_JSON_DATA" | grep -q "Not Found"; then
    echo "Error: Latest release was not found. Please check your network connection." >&2
    exit 1
fi

# Try to extract the download URL from the response
RELEASE_DOWNLOAD_URL=$(echo "$RELEASE_JSON_DATA" | grep -o "\"browser_download_url\": \".*${FILE_PATTERN}\"" | cut -d '"' -f 4 | head -n 1)
if [ -z "$RELEASE_DOWNLOAD_URL" ]; then
    echo "Error: Failed to find zip that matches the pattern \"$FILE_PATTERN\" in the latest release." >&2
    exit 1
fi

# Download the file using curl and make sure it was successful
ZIP_FILE=$(echo "$RELEASE_DOWNLOAD_URL" | rev | cut -d '/' -f 1 | rev)
curl --proto '=https' --tlsv1.2 -L -o "$ZIP_FILE" -sSf --connect-timeout 10 --max-time 60 "$RELEASE_DOWNLOAD_URL"
if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: Failed to download the release archive '$ZIP_FILE'." >&2
    exit 1
fi

# Unzip only the specific file we want and make sure it was successful
echo "Unzipping '$ZIP_FILE'..."
unzip -o -q "$ZIP_FILE" "$BINARY_NAME" -d .
rm "$ZIP_FILE"
if [ ! -f "$BINARY_NAME" ]; then
    echo "Error: The file '$BINARY_NAME' does not exist in the archive." >&2
    exit 1
fi

# Execute the file and remove it when done
echo "Running $BINARY_NAME installation...\n"
chmod +x "$BINARY_NAME"
./"$BINARY_NAME" self-install
rm "$BINARY_NAME"