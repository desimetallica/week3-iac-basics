# Objective

Design and deploy a private encrypted S3 bucket using IaaC, following secure-by-default and least-privilege principles.
Modelling a security requirements in a reproducible way an taking into account:
- usage/security tradeoffs
- cost implications
- operational impacts 

# Security choices & tradeoff

The best way to consider this is to operate with Terraform in a reproducible way. The S3 buckets with private access only need to satisfy those:

1. SSE-S3 instead of SSE-KMS: no key management overhead, data are protected at rest, reduced complexity, key maangement is fully handled by AWS at cost of less control on fine tuning of key usage.
2. Versioning disabled: to mantain predicatable usage, and lower storage costs, reduce security exposure, simplier managing. 
3. Deny non-TLS requests: data are protected in transit, server side enforcement, no additional cost.
4. Block Public Access: protection agains accidental exposure, enforcing private access only. Does not cover internal and private access authorization, and therefore data exfiltration by authorized identities. 

# Terraform resource used

- `aws_s3_bucket`: Creates the private S3 bucket
- `aws_s3_bucket_versioning`: Disables versioning for cost and security
- `aws_s3_bucket_ownership_controls`: Sets bucket owner ownership preference
- `aws_s3_bucket_server_side_encryption_configuration`: Enables SSE-S3 encryption
- `aws_s3_bucket_public_access_block`: Blocks all public access
- `aws_s3_bucket_policy`: Denies non-TLS requests

# Verification

It's important to verify S3 bucket security to ensure configurations like public access blocks and TLS enforcement are correctly applied, preventing data exposure.

**Manual verification:**
- Use AWS CLI: `aws s3api get-public-access-block --bucket <bucket-name>` to check public access settings.
- Use curl: Test bucket access with `curl -I https://<bucket-name>.s3.<region>.amazonaws.com/` (expect 403 for blocked access) and presigned URLs over HTTP/HTTPS to verify TLS enforcement.
- aws s3 presign s3://desimetallica-workload-bucket/index.html --region eu-south-1 --expires-in 3600  --endpoint-url https://s3.eu-south-1.amazonaws.com to obtain the link presigned
- curl it with and without https to check the TLS enforcing policy

**Automated verification:** Run the `test_s3_security.sh` script, which performs these checks automatically.

# Lesson Learned

- Careful usage of Deny with Principal: "*" to simulate “no public access” on S3.
The only way to recover or delete the bucket is to modify the bucket policies using the root account.
This typically requires opening a support ticket with AWS and having the relevant know-how:
https://repost.aws/knowledge-center/s3-accidentally-denied-access

- Things can become irreversible. In defensive security, it is essential to understand what you are about to execute before running commands.
When a situation becomes irreversible, the impact is severe.
This requires a deep understanding of control mechanisms.

- Security has real operational impact, and mistakes cannot be hidden — they accumulate and compound.

- It is critical to understand where the benefits of a security policy or rule end and where operational issues begin.
Every rule or policy must be studied in terms of its impact on development workflows and platform operations.