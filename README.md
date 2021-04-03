# AWS Infra

Various bits of AWS infrastructure managed by Terraform.

## Authentication

Terraform backend authentication configured via env vars, which are loaded by
`direnv` when entering the project.

```
# .envrc
export TF_VAR_aws_access_key='AKIA***'
export TF_VAR_aws_secret_key='***'
export TF_CLI_ARGS_init="-backend-config='access_key=$TF_VAR_aws_access_key' -backend-config='secret_key=$TF_VAR_aws_secret_key'"
```
