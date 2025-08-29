# Terraform AWS VPC Module for Low-Cost Environments

This Terraform module creates a foundational AWS Virtual Private Cloud (VPC) designed for development and small-scale project environments where cost-effectiveness is a primary concern. It provides a secure and isolated network configuration with essential networking components while minimizing expenditure.

## Key Features

- **Virtual Private Cloud (VPC):** Establishes a logically isolated section of the AWS Cloud where you can launch AWS resources.
- **Public and Private Subnets:** Segregates resources into public-facing subnets (for components like web servers or load balancers) and private subnets (for backend services, databases, and application servers) to enhance security.
- **Cost-Optimized NAT Instance:** Instead of a managed NAT Gateway, this module provisions a `t4g.micro` EC2 instance to function as a Network Address Translation (NAT) device. This allows instances in the private subnets to access the internet for updates and external services while keeping costs significantly lower than a managed NAT Gateway. The NAT instance is accessible for management via AWS Systems Manager (SSM) without requiring SSH keys.
- **Internet Gateway:** Enables communication between your VPC and the internet.
- **S3 Gateway Endpoint:** Provides reliable and efficient access to Amazon S3 from within your VPC without requiring an internet gateway or NAT device, which can help reduce data transfer costs.
- **Configurable Security:** Includes basic security groups and network ACLs to control inbound and outbound traffic.

## Use Case

This module is ideal for:

-   Development and testing environments.
-   Small personal projects.
-   Learning and experimenting with AWS networking.
-   Any scenario where a full-featured, highly available network setup is not required, and cost is a major consideration.

## Cost Considerations

The primary cost-saving feature of this module is the use of a `t4g.micro` NAT instance. While this is much cheaper than a managed NAT Gateway, it's important to be aware of the following:

-   **Single Point of Failure:** The NAT instance is a single EC2 instance and does not have the high availability of a managed NAT Gateway. If the instance fails, internet connectivity for the private subnets will be lost until it is restored.
-   **Limited Bandwidth:** The `t4g.micro` instance type has limited network bandwidth. This solution is not suitable for high-traffic applications.
-   **Data Transfer Costs:** Standard AWS data transfer costs still apply.

For production environments or applications with high availability requirements, consider using a managed NAT Gateway.
