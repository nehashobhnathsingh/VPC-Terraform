#VPC
resource "aws_vpc" "MyVPC" {
  #cidr_block       = "10.0.0.0/16" (this is correct but we have written this in variable file)
  #instance_tenancy = "default"

  cidr_block = var.CIDR #another way to write CUDR which is called from variable file
  tags = {
    Name = "My-VPC"
  }
}

#subnet1 (order of lines should be same)
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.MyVPC.id #use above vpc id 
  cidr_block              = var.sub1-CIDR    #Refer CIDR from var      
  availability_zone       = "ap-south-1a"    #az
  map_public_ip_on_launch = "true"           #give public ip true
}

#subnet2 (order of lines should be same)
resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.MyVPC.id #use above vpc id 
  cidr_block              = var.sub2-CIDR    #Refer CIDR from var      
  availability_zone       = "ap-south-1b"    #az
  map_public_ip_on_launch = "true"           #give public ip true
}

#create internet gateway for internet access to subnets
resource "aws_internet_gateway" "IGW-MyVPC" {
  vpc_id = aws_vpc.MyVPC.id
  tags = {
    Name = "IGW"
  }
}

#create route table allow all traffic to the local internet gateway
resource "aws_route_table" "RT-MyVPC" {
  vpc_id = aws_vpc.MyVPC.id

  #Route table creation inside subnet allow all traffic to igw
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW-MyVPC.id
  }
}

#subnet association (associate route table to public subnet)
resource "aws_route_table_association" "RTassociatesub1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT-MyVPC.id
}

resource "aws_route_table_association" "RTassociatesub2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT-MyVPC.id
}

#create security group for ELB and EC2
resource "aws_security_group" "MySG" {
  name        = "My-SG"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.MyVPC.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block] no need of IPV6
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block] no need of IPV6
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "My_SG"
  }
}

#s3 Bucket creation
/*resource "aws_s3_bucket" "MyS3" {
  bucket = "neha-s3bucket-08-01-24"

  tags = {
    Name        = "My bucket"
  }
    acl= "public-read"   #public access to bucket
}*/

resource "aws_s3_bucket" "MyS3" {
  bucket = "neha-s3bucket-08-01-24"
}

resource "aws_s3_bucket_ownership_controls" "MyS3-owner-control" {
  bucket = aws_s3_bucket.MyS3.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "MyS3-access" {
  bucket = aws_s3_bucket.MyS3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "MyS3-ACL" {
  depends_on = [
    aws_s3_bucket_ownership_controls.MyS3-owner-control,
    aws_s3_bucket_public_access_block.MyS3-access,
  ]

  bucket = aws_s3_bucket.MyS3.id
  acl    = "public-read"
}

#Instance creation
resource "aws_instance" "My-Instance1" {
  ami                    = "ami-0a0f1259dd1c90938"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.MySG.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = "file(userdata1.sh)"

  tags = {
    Name = "My-Server1"
  }

}

resource "aws_instance" "My-Instance2" {
  ami                    = "ami-0a0f1259dd1c90938"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.MySG.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = "file(userdata2.sh)"

  tags = {
    Name = "My-Server2"
  }

}

#ALB creation 
resource "aws_alb" "My-ALB" {
  name               = "My-App-Loa-Balancer"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.MySG.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

}

#create target group
resource "aws_lb_target_group" "tg" {
  name     = "MyTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.MyVPC.id

  #target group will have health check
  health_check {
    path = "/"
    port = "traffic-port"

  }

}

#attach the target group to the instance as a target
resource "aws_lb_target_group_attachment" "TG-attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.My-Instance1.id
  port             = 80

}

#create a listener
resource "aws_lb_listener" "My-Listner" {
  load_balancer_arn = aws_alb.My-ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }

}


