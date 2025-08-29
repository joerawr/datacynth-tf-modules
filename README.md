# DataCynth Terraform Modules

[![GitHub tag](https://img.shields.io/github/tag/joerawr/datacynth-tf-modules.svg)](https://github.com/joerawr/datacynth-tf-modules/tags)
[![Lint](https://img.shields.io/github/actions/workflow/status/joerawr/datacynth-tf-modules/lint.yml?label=lint)](../../actions)
[![License](https://img.shields.io/github/license/joerawr/datacynth-tf-modules.svg)](LICENSE)

A collection of opinionated, reusable Terraform modules for building **cost-conscious AWS infrastructure**.  
This repo is structured to separate reusable modules from environment-specific infrastructure (`datacynth-infra`).

## Modules

| Module | Description | Example Usage |
|--------|-------------|---------------|
| [`vpc/`](./vpc) | Low-cost VPC with public/private subnets, cost-optimized NAT instance, optional S3 gateway endpoint | [Example](#usage-example) |

> More modules (IAM, ECS/Fargate, ECR, etc.) will be added as the project evolves.

---

## Usage Example

```hcl
module "vpc" {
  source = "github.com/joerawr/datacynth-tf-modules//vpc?ref=main"

  name                 = "alpha-vpc"
  aws_profile          = "alpha-admin"
  aws_region           = "us-west-2"
  vpc_cidr             = "10.0.0.0/16"
  az_count             = 1
  public_subnet_count  = 1
  private_subnet_count = 1
}
```

Run:
```bash
terraform init
terraform plan
terraform apply
```

---

## Versioning

- This repo follows [Semantic Versioning](https://semver.org/).  
- Tags are published as `vMAJOR.MINOR.PATCH`.  
- Example:  
  - `v0.1.0`: Initial release of the VPC module  
  - `v0.2.0`: Added ECS/Fargate module  
  - `v1.0.0`: Breaking variable changes

See [CHANGELOG.md](./CHANGELOG.md) for detailed release notes.

---

## Development

### Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.12.0
- [tflint](https://github.com/terraform-linters/tflint)
- [pre-commit](https://pre-commit.com/)

### Contributing
1. Fork the repo
2. Create a feature branch (`feat/my-feature`)
3. Run lint & fmt:
   ```bash
   terraform fmt -recursive
   tflint --recursive
   ```
4. Open a PR

---

## Related Repos

- [`datacynth-infra`](https://github.com/joerawr/datacynth-infra):  
  Environment-specific Terraform configs that consume these modules.

---

## License

Apache 2.0 License. See [LICENSE](./LICENSE) for details.
