#!/usr/bin/env bash
#
# Script to recursively download all files and folders from an S3 path.
#
# Usage:
#     ./download_s3.sh s3://bucket-name/path/to/download [--output-dir ./output]

set -euo pipefail

# Default values
OUTPUT_DIR="./output"
QUIET=false
PROFILE=""
REGION=""
S3_PATH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print error message
error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Print info message
info() {
    if [[ "$QUIET" == false ]]; then
        echo -e "${GREEN}$1${NC}"
    fi
}

# Print warning message
warning() {
    if [[ "$QUIET" == false ]]; then
        echo -e "${YELLOW}Warning: $1${NC}" >&2
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 <s3_path> [OPTIONS]

Recursively download all files and folders from an S3 path.

Arguments:
    s3_path                 S3 path to download from (e.g., s3://bucket-name/path/to/download)

Options:
    -o, --output-dir DIR    Output directory to save downloaded files (default: ./output)
    -p, --profile PROFILE   AWS profile to use (supports SSO profiles)
    -r, --region REGION     AWS region
    -q, --quiet             Suppress progress output
    -h, --help              Show this help message

Examples:
    $0 s3://my-bucket/data/
    $0 s3://my-bucket/data/ --output-dir ./output
    $0 s3://my-bucket/ --output-dir ./my-bucket-backup
    $0 s3://my-bucket/data/ --profile my-sso-profile
    $0 s3://my-bucket/data/ --profile my-profile --region us-west-2

EOF
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first:"
        echo "  macOS: brew install awscli"
        echo "  Linux: See https://aws.amazon.com/cli/"
        exit 1
    fi
}

# Check if profile uses SSO
check_sso_profile() {
    local profile_name="$1"
    local aws_config="$HOME/.aws/config"
    
    if [[ ! -f "$aws_config" ]]; then
        return 1
    fi
    
    local profile_section
    if [[ -n "$profile_name" && "$profile_name" != "default" ]]; then
        profile_section="profile $profile_name"
    else
        profile_section="default"
    fi
    
    # Check if profile section exists and contains SSO configuration
    if grep -A 20 "\[$profile_section\]" "$aws_config" 2>/dev/null | grep -q "sso_start_url\|sso_account_id"; then
        return 0
    fi
    
    return 1
}

# Validate S3 path
validate_s3_path() {
    local path="$1"
    
    if [[ ! "$path" =~ ^s3:// ]]; then
        error "S3 path must start with 's3://'"
        return 1
    fi
    
    return 0
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$S3_PATH" ]]; then
                    S3_PATH="$1"
                else
                    error "Unexpected argument: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$S3_PATH" ]]; then
        error "S3 path is required"
        usage
        exit 1
    fi
}

# Build AWS CLI command with profile and region
build_aws_cmd() {
    local cmd="aws"
    
    if [[ -n "$PROFILE" ]]; then
        cmd="$cmd --profile $PROFILE"
    fi
    
    if [[ -n "$REGION" ]]; then
        cmd="$cmd --region $REGION"
    fi
    
    echo "$cmd"
}

# Test AWS credentials
test_credentials() {
    local aws_cmd="$1"
    local bucket="$2"
    
    # Extract bucket name from S3 path
    local bucket_name="${bucket#s3://}"
    bucket_name="${bucket_name%%/*}"
    
    # Capture both stdout and stderr
    local error_output
    if ! error_output=$($aws_cmd s3 ls "s3://$bucket_name" 2>&1); then
        local exit_code=$?
        
        if echo "$error_output" | grep -qi "Unable to locate credentials"; then
            error "AWS credentials not found."
            if check_sso_profile "$PROFILE"; then
                echo ""
                error "SSO profile '$PROFILE' detected but credentials are missing."
                echo "Please log in with: aws sso login --profile $PROFILE"
            else
                echo "Please configure AWS credentials using:"
                echo "  - AWS CLI: aws configure"
                echo "  - AWS SSO: aws sso login --profile <profile-name>"
                echo "  - Environment variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
            fi
            exit 1
        elif echo "$error_output" | grep -qi "token\|sso\|expired"; then
            error "AWS SSO token may have expired."
            if check_sso_profile "$PROFILE"; then
                echo "Please refresh your SSO session with: aws sso login --profile $PROFILE"
            else
                echo "Please log in with: aws sso login --profile <profile-name>"
            fi
            exit 1
        elif echo "$error_output" | grep -qi "NoSuchBucket"; then
            error "Bucket '$bucket_name' does not exist."
            exit 1
        elif echo "$error_output" | grep -qi "AccessDenied\|403"; then
            error "Access denied to bucket '$bucket_name'."
            if check_sso_profile "$PROFILE"; then
                echo "Your SSO session may have expired. Try: aws sso login --profile $PROFILE"
            else
                echo "Check your AWS credentials and permissions."
            fi
            exit 1
        else
            error "Failed to access S3: $error_output"
            exit 1
        fi
    fi
}

# Main download function
download_s3() {
    local aws_cmd="$1"
    local s3_path="$2"
    local output_dir="$3"
    
    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Build sync command
    local sync_cmd="$aws_cmd s3 sync"
    
    if [[ "$QUIET" == true ]]; then
        sync_cmd="$sync_cmd --quiet"
    else
        sync_cmd="$sync_cmd"
    fi
    
    sync_cmd="$sync_cmd \"$s3_path\" \"$output_dir\""
    
    # Show info
    if [[ "$QUIET" == false ]]; then
        info "Downloading from: $s3_path"
        info "Output directory: $output_dir"
        echo ""
    fi
    
    # Execute sync command
    # Capture stderr to check for SSO errors, but let stdout through for progress
    local sync_stderr_file
    sync_stderr_file=$(mktemp)
    
    if eval "$sync_cmd" 2> "$sync_stderr_file"; then
        if [[ "$QUIET" == false ]]; then
            echo ""
            info "Download complete!"
        fi
        rm -f "$sync_stderr_file"
        return 0
    else
        local exit_code=$?
        local sync_stderr
        sync_stderr=$(cat "$sync_stderr_file")
        rm -f "$sync_stderr_file"
        
        if [[ "$QUIET" == false ]]; then
            echo ""
        fi
        error "Download failed"
        
        # Check for SSO-related errors
        if echo "$sync_stderr" | grep -qi "token\|sso\|expired"; then
            error "AWS SSO token may have expired."
            if check_sso_profile "$PROFILE"; then
                echo "Please refresh your SSO session with: aws sso login --profile $PROFILE"
            else
                echo "Please log in with: aws sso login --profile <profile-name>"
            fi
        fi
        
        exit $exit_code
    fi
}

# Main function
main() {
    # Check AWS CLI
    check_aws_cli
    
    # Parse arguments
    parse_args "$@"
    
    # Validate S3 path
    if ! validate_s3_path "$S3_PATH"; then
        exit 1
    fi
    
    # Check if profile uses SSO
    if [[ -n "$PROFILE" ]] && check_sso_profile "$PROFILE"; then
        if [[ "$QUIET" == false ]]; then
            info "Using AWS SSO profile: $PROFILE"
        fi
    fi
    
    # Build AWS command
    AWS_CMD=$(build_aws_cmd)
    
    # Test credentials
    test_credentials "$AWS_CMD" "$S3_PATH"
    
    # Download files
    download_s3 "$AWS_CMD" "$S3_PATH" "$OUTPUT_DIR"
}

# Run main function
main "$@"

