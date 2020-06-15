provider "aws" {
  region = "ap-south-1"
  profile = "Akarsh"
}

//-------------------------------------------------------
//key_pair
resource "tls_private_key" "webserver_key" {
    algorithm   =  "RSA"
    rsa_bits    =  4096
}
resource "local_file" "private_key" {
    content         =  tls_private_key.webserver_key.private_key_pem
    filename        =  "webserver.pem"
    file_permission =  0400
}
resource "aws_key_pair" "webserver_key" {
    key_name   = "webserver"
    public_key = tls_private_key.webserver_key.public_key_openssh
}
//-------------------------------------------------------
//security_group_allow_port_80

resource "aws_security_group" "allow_tls" {
  name        = "Akarsh_launch_wizard"
  description = "Allow inbound traffic"

  ingress {
    description = "mysecurity"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "mysecurity"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
//------------------------------------------------------
//instance create

resource "aws_instance" "Firstos" {
depends_on = [
    aws_key_pair.webserver_key
  ]
  ami           = "ami-0fe6c48156bfd54c8"
  instance_type = "t2.micro"
  key_name      = "webserver"
  security_groups = [ "Akarsh_launch_wizard" ]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.webserver_key.private_key_pem
    host     = aws_instance.Firstos.public_ip 
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "AkarshOS1"
  }
}

output "MY_public_IP" {
       value = aws_instance.Firstos.public_ip
}
//----------------------------------------------------------
//volume create
resource "aws_ebs_volume" "myvol1" {
depends_on = [
    aws_instance.Firstos
  ]
  availability_zone = aws_instance.Firstos.availability_zone
  size              = 1

  tags = {
    Name = "myebs1"
  }
}

output "MY_Volume_Id" {
       value = aws_ebs_volume.myvol1.id
}
//-----------------------------------------------------------
//volume attach
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.myvol1.id
  instance_id = aws_instance.Firstos.id
  force_detach = true
}
//-----------------------------------------------------------
resource "null_resource" "nulllocal3"  {

depends_on = [
    aws_volume_attachment.ebs_att
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.webserver_key.private_key_pem
    host     = aws_instance.Firstos.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdf",
      "sudo mount /dev/xvdf /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/AkarshAgarwal99/myimages.git /var/www/html/" 
    ]
  }
}

//---------------------------------------------------------------------------------------------
// create s3
resource "aws_s3_bucket" "yeh_meri_bucket" {
  bucket = "meri-bucket4"
  acl    = "public-read"


  tags = {
    Name        = "Akarsh"
  }
}


resource "aws_s3_bucket_object" "myimage" {
  bucket = aws_s3_bucket.yeh_meri_bucket.bucket
  key    = "photo.png"
  source = "E:\\photo.png"
  acl="public-read"
  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("E:\\photo.png")
}

//------------------------------------------------------------
//createing cloud front
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.yeh_meri_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.yeh_meri_bucket.id
  }	

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "mycloudfront"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.yeh_meri_bucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
  }
 price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "IN"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
//------------------------------------------------------------------

output "CloudFrontURL"  {
    value = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.myimage.key}"
}
//-----------------------------------------------------------------------
resource "null_resource" "nulllocal4"  {

depends_on = [
    aws_cloudfront_distribution.s3_distribution
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.webserver_key.private_key_pem
    host     = aws_instance.Firstos.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo su << EOF",
      "sudo echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.myimage.key}'>\" >> /var/www/html/index.php"
    ]
  }
}
