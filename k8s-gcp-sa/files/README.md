# Files Directory

This directory is intentionally empty - no key files needed!

## Why No Key Files?

This setup uses GCP's metadata API to access service accounts that are **already attached to your VM**.

## How Service Accounts Work

1. **Attach service account to VM** (done via gcloud or GCP console)
2. **GCP makes it accessible** via metadata API
3. **Our playbook accesses it** by service account email

## The Key Difference

**This approach lets you:**
- Choose **which specific** service account to use
- Work with VMs that have **multiple** service accounts
- Switch service accounts by just changing configuration

## Example: VM with Multiple Service Accounts

Your VM might have:
```
├── default@developer.gserviceaccount.com
├── devops@project.iam.gserviceaccount.com      ← You want this one
├── monitoring@project.iam.gserviceaccount.com
└── backup@project.iam.gserviceaccount.com
```

Just specify in `group_vars/all.yml`:
```yaml
gcp_service_account_email: "devops@project.iam.gserviceaccount.com"
```

No key files needed!

## If You Want to Use a Key File

If you have a service account JSON key file and prefer to use it:

1. Place it here: `files/service-account-key.json`
2. Modify the playbook to copy and use it
3. Set appropriate environment variables

However, using the VM's attached service account (this approach) is:
- ✅ More secure
- ✅ Easier to manage
- ✅ Better practice
- ✅ No key rotation needed
