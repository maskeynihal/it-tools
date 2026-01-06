# S3 Recursive Download Script

Scripts to recursively download all files and folders from an S3 path.

## Available Scripts

- **`download_s3.sh`** - Bash script using AWS CLI (recommended, no Python dependencies)
- **`download_s3.py`** - Python script using boto3

## Installation

### Bash Script (Recommended)

1. Install AWS CLI:
   ```bash
   # macOS
   brew install awscli
   
   # Linux - see https://aws.amazon.com/cli/
   ```

2. Make the script executable (already done):
   ```bash
   chmod +x download_s3.sh
   ```

### Python Script

1. Install Python 3.6 or higher
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Prerequisites

You need AWS credentials configured. You can do this in one of the following ways:

1. **AWS SSO** (recommended for organizations):
   ```bash
   # First, configure your SSO profile in ~/.aws/config
   # Then log in:
   aws sso login --profile your-profile-name
   
   # Use the profile with the script:
   python download_s3.py s3://bucket-name/path --profile your-profile-name
   ```

2. **AWS CLI** (traditional credentials):
   ```bash
   aws configure
   ```

3. **Environment variables**:
   ```bash
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   ```

4. **IAM role** (if running on EC2)

## Usage

### Bash Script (Recommended)

Basic usage:
```bash
./download_s3.sh s3://bucket-name/path/to/download
```

Specify output directory:
```bash
./download_s3.sh s3://bucket-name/path/to/download --output-dir ./downloads
```

Use a specific AWS profile (supports SSO profiles):
```bash
./download_s3.sh s3://bucket-name/path/to/download --profile my-profile
```

Using AWS SSO:
```bash
# First, log in to SSO (if not already logged in):
aws sso login --profile my-sso-profile

# Then use the profile:
./download_s3.sh s3://bucket-name/path/to/download --profile my-sso-profile
```

Quiet mode (suppress progress output):
```bash
./download_s3.sh s3://bucket-name/path/to/download --quiet
```

### Python Script

Basic usage:
```bash
python download_s3.py s3://bucket-name/path/to/download
```

Specify output directory:
```bash
python download_s3.py s3://bucket-name/path/to/download --output-dir ./downloads
```

Use a specific AWS profile (supports SSO profiles):
```bash
python download_s3.py s3://bucket-name/path/to/download --profile my-profile
```

## Examples

Download all files from a specific folder:
```bash
./download_s3.sh s3://my-bucket/data/
# or
python download_s3.py s3://my-bucket/data/
```

Download entire bucket:
```bash
./download_s3.sh s3://my-bucket/ --output-dir ./my-bucket-backup
# or
python download_s3.py s3://my-bucket/ --output-dir ./my-bucket-backup
```

Download with specific region:
```bash
./download_s3.sh s3://my-bucket/data/ --region us-west-2
# or
python download_s3.py s3://my-bucket/data/ --region us-west-2
```

## Options

- `s3_path`: S3 path to download from (required)
- `--output-dir`, `-o`: Output directory (default: `./downloads`)
- `--quiet`, `-q`: Suppress progress output
- `--profile`, `-p`: AWS profile to use
- `--region`, `-r`: AWS region

## Notes

- Both scripts preserve the directory structure from S3
- Empty folders (prefix markers) are skipped
- The scripts show progress by default
- All errors are handled gracefully with informative messages
- **AWS SSO support**: Both scripts automatically detect SSO profiles and provide helpful error messages if your SSO session has expired. Simply run `aws sso login --profile <profile-name>` to refresh your session.
- **Bash script advantages**: No Python dependencies, uses AWS CLI directly, faster for large downloads
- **Python script advantages**: More detailed progress information, file count and size statistics

