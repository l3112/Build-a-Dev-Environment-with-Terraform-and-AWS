// the one with the dev enviroment
/* https://courses.morethancertified.com/p/rfp-terraform */
// By Derek Morgan
/* THINGS LEARNED */

//the .id at the end of certain parameters just calls the id that gets created.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

//VPC

resource "aws_vpc" "cloud_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true //implied but you may want to point it out

  tags = {
    name = "devEnviroment"
  }
}

// a subnet and referencing

resource "aws_subnet" "NTC_Pub_Sub" {
  vpc_id                  = aws_vpc.cloud_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2" //data sources to make this always correct

  tags = {
    Name = "dev_public"
  }
}

//security group
// may need to be placed lower

resource "aws_security_group" "NTC_SG" {

  name        = "allow_tls"
  description = "dev security group"
  vpc_id      = aws_vpc.cloud_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] //put in your own IP.

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"] // Open Internet
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

// IGW and Terraform fmt 
resource "aws_internet_gateway" "mainIG" {
  vpc_id = aws_vpc.cloud_vpc.id

  tags = {
    name = "mainIGW"
  }
}

// route table!
resource "aws_route_table" "mainRT" {
  vpc_id = aws_vpc.cloud_vpc.id
  tags = {
    name = "dev_publicRT"
  }
}

// the route
resource "aws_route" "def_route" {
  route_table_id         = aws_route_table.mainRT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mainIG.id
}


// a route table association
resource "aws_route_table_association" "RTA" {
  subnet_id      = aws_subnet.NTC_Pub_Sub.id
  route_table_id = aws_route_table.mainRT.id

}

/* NEW! */
//aws_ami
// see datasrc.tf
//How does it pull the information?
// probably from the terraform init.


//keypair
// file function

resource "aws_key_pair" "New_Key" {
  key_name   = "NewKey1"
  public_key = file("~/.ssh/NewKey.pub")
}

// EC2
/* NEW! */
// Userdata and Provisioners

resource "aws_instance" "Ubuntu_Server" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.Server_AMI.id
  key_name               = aws_key_pair.New_Key.id
  vpc_security_group_ids = [aws_security_group.NTC_SG.id]
  subnet_id              = aws_subnet.NTC_Pub_Sub.id
  user_data              = file("userdata.tpl")
  root_block_device {
    volume_size = 1
  }
  tags = {
    name = "Dev_Node"
  }


  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = ("~/.ssh/NewKey")
      }
    )
    interpreter = ["Powershell", "-command"]
  }
}
