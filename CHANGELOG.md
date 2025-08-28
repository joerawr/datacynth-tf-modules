# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- 

### Changed
- 

### Fixed
- 

### Security
- 

## [v0.1.0] - 2025-08-28
### Added
- Initial AWS VPC module for low-cost environments:
  - VPC with DNS support/hostnames and optional IPv6.
  - Public & private subnets across configurable AZ count.
  - Internet Gateway and public route table.
  - **Cost-optimized NAT instance** (`t4g.micro`) with EIP and MASQUERADE user-data.
  - Private route tables with default route through NAT instance.
  - Optional S3 Gateway Endpoint on private route tables.
  - Basic private SG with configurable allowed ports.
  - Data source for AL2023 AMI (arm64) filter.
  - Module variables for profile/region/cidrs/subnet counts/NAT toggles.

[Unreleased]: https://github.com/joerawr/datacynth-tf-modules/compare/v0.1.0...HEAD
[v0.1.0]: https://github.com/joerawr/datacynth-tf-modules/releases/tag/v0.1.0

