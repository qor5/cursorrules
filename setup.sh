#!/bin/bash

# Get the absolute path of the script directory
SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the current directory where the user executed the script
TARGET_DIR="$(pwd)"

echo "Source directory: ${SOURCE_DIR}"
echo "Target directory: ${TARGET_DIR}"

# 1. Check if .cursor directory exists in the target directory, create if not
if [ ! -d "${TARGET_DIR}/.cursor" ]; then
  echo "Creating ${TARGET_DIR}/.cursor directory"
  mkdir -p "${TARGET_DIR}/.cursor"
else
  echo ".cursor directory already exists"
fi

# 2. Check if .cursor/rules already exists in the target directory
if [ -e "${TARGET_DIR}/.cursor/rules" ]; then
  echo "Warning: ${TARGET_DIR}/.cursor/rules already exists"
  echo "Please manually delete it before running this script: rm -rf ${TARGET_DIR}/.cursor/rules"
  exit 1
fi

# 3. Create a symbolic link from source rules directory to target directory
echo "Creating symbolic link: ${SOURCE_DIR}/.cursor/rules -> ${TARGET_DIR}/.cursor/rules"
ln -s "${SOURCE_DIR}/.cursor/rules" "${TARGET_DIR}/.cursor/rules"

# 4. Check if the target directory has a .gitignore file
if [ -f "${TARGET_DIR}/.gitignore" ]; then
  # Check if .gitignore already contains .cursor
  if grep -q "^\.cursor$" "${TARGET_DIR}/.gitignore"; then
    echo ".gitignore already contains .cursor"
  else
    echo "Adding .cursor to .gitignore"
    echo "" >> "${TARGET_DIR}/.gitignore"
    echo ".cursor" >> "${TARGET_DIR}/.gitignore"
  fi
else
  # Create .gitignore if it doesn't exist and add .cursor
  echo "Creating .gitignore and adding .cursor"
  echo ".cursor" > "${TARGET_DIR}/.gitignore"
fi

echo "Setup complete! The target directory is now linked to cursor rules from this repository." 