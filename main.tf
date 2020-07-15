provider "aws" {
  region = "us-east-2"
}


resource "aws_launch_configuration" "example" {
  image_id = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello world" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
  EOF

  ## this solve zero-downtime problom
  lifecycle {
    create_before_destroy = true
  }

}

##for security group
resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress{
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description    = "the port server will use for HTTP requests"
  type           = number
  default        = 8080
}



# datasource
# data.<provider>_<type>.<name>.<attribute>
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

##ASG
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  min_size = 2
  max_size = 10

  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  tag{
    key 		= "Name"
    value     		= "terraform-asg-example"
    propagate_at_launch = true
  }
}

## tell ec2 instance to use the security group
## use terraform expressions
## so i need add vpc_security_group_ids to  aws_instance example
## for DRY i need a variable => description type default
## use it by => var.<variable_name>
## single point is not acceptable so cluster is needed
## cluster use aws_launch_configuration most same as aws_instance
