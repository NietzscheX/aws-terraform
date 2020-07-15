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
  target_group_arns   = [aws_lb_target_group.asg.arn]
  health_check_type   = "ELB"

  tag{
    key 		= "Name"
    value     		= "terraform-asg-example"
    propagate_at_launch = true
  }
}

##ALB
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets	     = data.aws_subnet_ids.default.ids
  
  #to use secruity_groups for lb
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http"{
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type  = "text/plain"
      message_body  = "404: page not found"
      status_code   = 404
    }
  }
}

resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  #inbound
  ingress {
    from_port = 80
    to_port   = 80 
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #outbound
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "asg" {
  name		= "terraform-asg-example"
  port		= var.server_port
  protocol	= "HTTP"
  vpc_id	= data.aws_vpc.default.id

  health_check {
    path	= "/"
    protocol	= "HTTP"
    matcher	= "200"
    interval	= 15
    timeout	= 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn  = aws_lb_listener.http.arn
  priority      = 100
  condition {
    field  = "path-pattern"
    values = ["*"]
  }

  action {
    type	     = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "the domain name of the load balancer"
}


## tell ec2 instance to use the security group
## use terraform expressions
## so i need add vpc_security_group_ids to  aws_instance example
## for DRY i need a variable => description type default
## use it by => var.<variable_name>
## single point is not acceptable so cluster is needed
## cluster use aws_launch_configuration most same as aws_instance
## ALB ELB
## note: ASG auto scaling group

