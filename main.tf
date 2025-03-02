#creating vpc
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr
}

#creating subnet1
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

#creating subnet1
resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

#creating internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

#creating  route table
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

#associating rta
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

#associating rta
resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

#creating security group
resource "aws_security_group" "sg1" {
  tags = {
    Name = "allow_http_ssh"
  }
  name        = "sg1"
  description = "sg attached"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#creating s3 bucket
resource "aws_s3_bucket" "example1" {
  bucket = "tf-ft-dt-bct"
}

resource "aws_s3_bucket_ownership_controls" "example2" {
  bucket = aws_s3_bucket.example1.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example3" {
  bucket = aws_s3_bucket.example1.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example4" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example2,
    aws_s3_bucket_public_access_block.example3,
  ]

  bucket = aws_s3_bucket.example1.id
  acl    = "public-read"
}

#creating ec2 instance number1
resource "aws_instance" "ec2_server" {
  ami                    = "ami-0d682f26195e9ec0f"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg1.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))

}

#creating ec2 instance number2
resource "aws_instance" "ec2_server2" {
  ami                    = "ami-0d682f26195e9ec0f"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg1.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata2.sh"))

}

#creating load balancer.
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg1.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Environment = "production"
  }
}

#creating load balancer target group.
resource "aws_lb_target_group" "lb_tg" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}


resource "aws_lb_target_group_attachment" "tg_attachment1" {
  target_id        = aws_instance.ec2_server.id
  target_group_arn = aws_lb_target_group.lb_tg.arn
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg_attachment2" {
  target_id        = aws_instance.ec2_server2.id
  target_group_arn = aws_lb_target_group.lb_tg.arn
  port             = 80
}

resource "aws_lb_listener" "listener1" {
  load_balancer_arn = aws_lb.test.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lb_tg.arn
    type             = "forward"
  }
}
output "loadbalancerdns" {
  value = aws_lb.test.dns_name
}



