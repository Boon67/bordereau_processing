#!/bin/bash
# ============================================
# COMMON FUNCTIONS FOR DEPLOYMENT SCRIPTS
# ============================================
# Purpose: Shared functions and utilities for deployment scripts
# Usage: source deployment/common.sh
# ============================================

# Function to get script directory with Windows path handling
get_script_dir() {
    local source_file="${BASH_SOURCE[1]}"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
        # Running in Git Bash on Windows
        local dir="$(cd "$(dirname "$source_file")" && pwd -W 2>/dev/null || pwd)"
        # Convert backslashes to forward slashes
        echo "${dir//\\//}"
    else
        # Unix/Linux/Mac
        cd "$(dirname "$source_file")" && pwd
    fi
}

# Function to normalize path for Windows
normalize_path() {
    local path="$1"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
        # Convert backslashes to forward slashes
        echo "${path//\\//}"
    else
        echo "$path"
    fi
}

# Function to convert Windows path to Unix-style for Git Bash
windows_to_unix_path() {
    local path="$1"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
        # Remove drive letter and convert backslashes
        # C:\Users\... becomes /c/Users/...
        if [[ "$path" =~ ^([A-Za-z]):(.*)$ ]]; then
            local drive="${BASH_REMATCH[1],,}"  # lowercase
            local rest="${BASH_REMATCH[2]}"
            rest="${rest//\\//}"
            echo "/$drive$rest"
        else
            echo "${path//\\//}"
        fi
    else
        echo "$path"
    fi
}

# Function to check if running on Windows
is_windows() {
    [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]
}

# Function to get absolute path
get_absolute_path() {
    local path="$1"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
        # Windows - use realpath if available, otherwise pwd -W
        if command -v realpath &> /dev/null; then
            realpath "$path" 2>/dev/null || (cd "$(dirname "$path")" && pwd -W)/$(basename "$path")
        else
            (cd "$(dirname "$path")" && pwd -W 2>/dev/null || pwd)/$(basename "$path")
        fi
    else
        # Unix/Linux/Mac
        if command -v realpath &> /dev/null; then
            realpath "$path"
        else
            # Fallback for systems without realpath
            (cd "$(dirname "$path")" && pwd)/$(basename "$path")
        fi
    fi
}

# Export functions for use in subshells
export -f normalize_path
export -f windows_to_unix_path
export -f is_windows
export -f get_absolute_path
