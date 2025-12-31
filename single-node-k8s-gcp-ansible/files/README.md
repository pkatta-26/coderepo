# Service Account Key Placeholder

⚠️ **IMPORTANT**: Place your GCP service account key file here.

## How to get your service account key:

### Method 1: Download from GCP Console
1. Go to: https://console.cloud.google.com/iam-admin/serviceaccounts
2. Select your project
3. Click on the `devops` service account
4. Go to "Keys" tab
5. Click "Add Key" → "Create new key"
6. Select "JSON" format
7. Click "Create"
8. Save the downloaded file as `devops-sa-key.json` in this directory

### Method 2: Using gcloud CLI
```bash
gcloud iam service-accounts keys create devops-sa-key.json \
    --iam-account=devops@YOUR-PROJECT-ID.iam.gserviceaccount.com
```

## File permissions
After placing the file here, set proper permissions:
```bash
chmod 600 devops-sa-key.json
```

## Verify the file
Check it's valid JSON:
```bash
python3 -m json.tool devops-sa-key.json
cat devops-sa-key.json | jq '.client_email'
```

## Security Note
⚠️ **NEVER commit this file to version control!**

This file contains sensitive credentials that provide access to your GCP project.
Keep it secure and delete it when no longer needed.

The `.gitignore` file in the parent directory excludes `*.json` files to prevent
accidental commits.
