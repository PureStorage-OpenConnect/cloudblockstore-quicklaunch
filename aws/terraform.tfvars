# See blog at https://davidstamen.com/2021/07/26/pure-cloud-block-store-on-aws-jump-start/ for more information on AWS Jump Start


#AWS Variables
aws_prefix = "tf-cbs-"
aws_access_key = "000-000-000"
aws_secret_key = "000-000-000"
aws_region = "us-east-1"
aws_zone = "a"
aws_ami_owner = ["amazon"]
aws_ami_name = ["amzn2-ami-hvm-2.0*"]
aws_ami_architecture = ["x86_64"]
aws_instance_type = "t2.micro"
aws_key_name = "aws_keypair"
aws_user_data = <<EOF
        #!/bin/bash
        echo "hi" > /tmp/user_data.txt
        EOF

#CBS Variables
template_url            = "https://s3.amazonaws.com/awsmp-fulfillment-cf-templates-prod/4ea2905b-7939-4ee0-a521-d5c2fcb41214/0e0ca88196014065b8ae7e5793e95999.template"
log_sender_domain       = "domain.com"
alert_recipients        = ["user@domain.com"]
purity_instance_type    = "V10AR1"
license_key             = "000-000-000"

/* Current Supported Regions for CBS Terraform Deployment
us-east-1 (N. Virginia) *
us-east-2 (Ohio)
us-west-1 (N. California)
us-west-2 (Oregon) * **
ca-central-1 (Canada Central)
eu-central-1 (Frankfurt) *
eu-west-1 (Ireland)
eu-west-2 (London)*
ap-south-1 (Mumbai)*
ap-southeast-1 (Singapore)*
ap-southeast-2 (Sydney)
ap-northest-1 (Tokyo)
ap-northeast-2 (Seoul)
us-gov-west-1 (GovCloud West)

* These regions are generally supported. However, there are some Availability Zones within these regions that do not have the required c5n.9xlarge and c5n.18xlarge instances for Cloud Block Store. These Availability Zones are different for every customer. Customers can contact AWS Support to find out which Availability Zone does not include support for c5n.9xlarge and c5n.18xlarge instances, and avoid deploying Cloud Block Store in subnets tied to these Availability Zones.

** Cloud Block Store in an ActiveCluster configuration is not supported in Oregon if using with Pure1 Mediator. Customers who want to deploy Cloud Block Store with ActiveCluster in Oregon must use the On-Premises Mediator.

*/