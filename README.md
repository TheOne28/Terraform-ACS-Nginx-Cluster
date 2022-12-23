# AWS Nginx ECS Cluster with Load Balancer and Fargate Launch Type and Target Tracking Autoscaling

## Author

Vincent Prasetiya Atmadja  
13520099

## How to Run

1. Clone this repository
2. Make sure you have terraform installed (You can refer to this [link](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)). This repository is tested for terraform version 0.13
3. Open Terminal on this folder
4. Make sure you have an AWS Account. Create ```aws_keys.tfvars``` and put  your credential. You can look ```aws_keys.tfvars.example``` for example.
5. Run ```terraform init```.
6. Run ```terraform plan -var-file="aws_keys.tfvars"``` to see what changes will be made.
7. Run ```terraform apply -var-file="aws_keys.tfvars"``` to apply changes.
8. You can see load_balancer url in terminal, under output.

## How To Delete Resource (after resources made)

1. Run ```terraform destroy -var-file="aws_keys.tfvars"```