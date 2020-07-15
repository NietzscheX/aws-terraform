provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  tags = {
    Name = "terraform-example"
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello world" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
  EOF

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

output "public_ip" {
  value        = aws_instance.example.public_ip
  description  = "The public ip address of web server"
}

## tell ec2 instance to use the security group
## use terraform expressions
## so i need add vpc_security_group_ids to  aws_instance example
## for DRY i need a variable => description type default
## use it by => var.<variable_name>
