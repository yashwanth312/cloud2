provider "aws" {
	region = "ap-south-1"
	profile = "yashterra"
}

//security-group creation
resource "aws_security_group" "attach-sg" {
  name        = "webpage"
  description = "Allow 80 , 8080 ,2049 and 22 ports inbound traffic"
  vpc_id = "vpc-d4f7eabc"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "http_sg" {
	value = aws_security_group.attach-sg.id
}

//creating instance
resource "aws_instance" "web" {
  ami = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1b"
  subnet_id = "subnet-6a0c6726"
  key_name = "terraform-20200612192017563900000002"
  security_groups = ["${aws_security_group.attach-sg.id}"]
}

output "publicip" {
	value = aws_instance.web.public_ip
}

resource "aws_efs_file_system" "myefs" {
      creation_token = "foo"
} 

output "esf-id" {
	value = aws_efs_file_system.myefs.id
}

output "efs-dns-id" {
	value = aws_efs_file_system.myefs.dns_name
}

resource "aws_efs_mount_target" "alpha-1" {
  file_system_id = aws_efs_file_system.myefs.id
  subnet_id      = "subnet-6a0c6726"
  security_groups = ["${aws_security_group.attach-sg.id}"] 
}

//s3-bucket creation
variable "enter_bucket_name" {
	type = string
}

resource "aws_s3_bucket" "trailbucket" {
  bucket = var.enter_bucket_name
  acl = "public-read"
  force_destroy = "true"
  
}

resource "aws_s3_bucket_public_access_block" "bucketaccess" {
  bucket = var.enter_bucket_name
}


output "cf1" {
 	value =  aws_s3_bucket.trailbucket.bucket_domain_name
}

output "cfs3" {
	value = aws_s3_bucket.trailbucket.id
}

//cloud-front creation
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {

}

output "origin" {
	value = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.trailbucket.bucket_domain_name
    origin_id   = aws_s3_bucket.trailbucket.id
    
    custom_origin_config {
         http_port = 80
         https_port = 80
         origin_protocol_policy = "match-viewer"
         origin_ssl_protocols = ["TLSv1"  , "TLSv1.1" , "TLSv1.2"]
         }
}

  enabled             = true
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.trailbucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
  }

  

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfrontdomain" {
	value = aws_cloudfront_distribution.s3_distribution.domain_name
}


resource "null_resource" "softwares" {
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/yasu/Desktop/key1.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [ "sudo yum install docker -y", 
                    "sudo yum install httpd -y",
	  "sudo systemctl start httpd",
	  "sudo systemctl enable httpd",
	  "sudo systemctl start docker",
	  "sudo systemctl enable docker",
	  ]
  }
}
	
resource "null_resource" "jenkins" {
    depends_on = [
	      null_resource.softwares,
	      aws_efs_mount_target.alpha-1,
	]
    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/yasu/Desktop/key1.pem")
    host     = aws_instance.web.public_ip
  }

   provisioner "remote-exec" {
      inline = [
	"sudo docker pull yashwanth3/yashjenkins",
	"sudo docker run -dit --name jen1 --privileged --init -v /:/baseos -p 8080:8080  yashwanth3/yashjenkins",
	"sudo docker exec jen1 yum install git -y",
	"efs_id=${aws_efs_file_system.myefs.dns_name}",
	"sudo mount $efs_id:/ /var/www/html",
	]
  }
}



