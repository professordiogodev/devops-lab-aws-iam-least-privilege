#!/usr/bin/env bash
# Proves the AWS resources of this lab are gone. Run with: ./teardown-check.sh
# Needs the AWS CLI with your normal ADMIN credentials (or run it in AWS CloudShell).
set -uo pipefail
command -v aws >/dev/null || { echo "The AWS CLI is not installed. Run this in AWS CloudShell (the >_ icon in the console)." >&2; exit 1; }
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || { echo "No working AWS credentials. Use your admin profile, or AWS CloudShell." >&2; exit 1; }
echo "Checking account $ACCOUNT"
pass=0; failn=0
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
no_user()   { ! aws iam get-user --user-name "$1" >/dev/null 2>&1; }
no_group()  { ! aws iam get-group --group-name "$1" >/dev/null 2>&1; }
no_policy() { [ -z "$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$1'].PolicyName" --output text)" ]; }
no_buckets_with_prefix() { [ -z "$(aws s3api list-buckets --query "Buckets[?starts_with(Name, \`$1\`)].Name" --output text)" ]; }
no_budget() { ! aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$1" >/dev/null 2>&1; }

check "IAM user sam-intern is deleted" no_user sam-intern
check "IAM group Clipstr-Developers is deleted" no_group Clipstr-Developers
check "customer managed policy ClipstrDeveloperPolicy is deleted" no_policy ClipstrDeveloperPolicy
check "no S3 bucket named clipstr-uploads-* is left" no_buckets_with_prefix clipstr-uploads-
check "no S3 bucket named clipstr-finance-* is left" no_buckets_with_prefix clipstr-finance-

echo
if [ "$failn" -eq 0 ]; then echo "TEARDOWN VERIFIED ($pass/$pass) in account $ACCOUNT"; else echo "NOT CLEAN: $failn leftover(s). Delete them (console or CLI) and run this again."; fi
exit "$failn"
