# Terraform-AWS
This is a set of sample Terraform scripts to deploy highly-available web server with php 7.4 support in AWS.

The Web Page is stored in separate GitHub repository: https://github.com/cepxuo/webpage
The following repository is being cloned to each EC2 instance in Web Fleet during bootstrap.

**NOTE:** The scripts will create NAT Gateways in *each* subnet, which are not part of AWS Free-Tier and you need to pay for them on hourly basis. If you plan to stay with AWS Free-Tier you can checkout to `free-tier` branch. However in such case Web Tier will be in Public zone, which is less secure.

The following diagram describes the infrastructure created by the scripts.

![Infrastructure](https://github.com/cepxuo/Terraform-AWS/blob/master/images/Terraform-AWS.png?raw=true)

The red arrows show traffic from/to Internet. The green arrows show traffic within VPC.

You can adjust the following parameters, stored in `vars.tf` file:

| Variable | Description |
| --- | --- |
| `region` | AWS Region name |
| `subnets_count` | Number of subnets you want to create |
| `ec2_max_count` | Maximal number of EC2 instances in Web Fleet |
| `cidr_base` | Base part of CIDR block for VPC. Default is `10.10` |
| `ssh_ips` | CIDR block for SSH-allowed IPs (only to Bastion Host) |
| `ssh_key` | Name of your SSH key |
| `open_ports` | Ports opened for Web Application |
| `project_tags` | Map of common project tags |

Big thanks to Denis Astahov for his Udemy courses and educational YouTube channel: https://www.youtube.com/channel/UC-sAMvDe7gTmBbub-rWljZg
