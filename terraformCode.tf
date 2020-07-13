provider "aws" {
	profile ="Asish"
	region ="ap-south-1"
}

resource "aws_security_group" "task2_sg" {
  name        = "task2_sg"
  description = "Allow port 80"
  vpc_id      = "vpc-df9489b7"

  ingress {
    description = "PORT 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
  ingress{
      description= "NFS"
       from_port= 2049
        to_port= 2049
        protocol="tcp"
        cidr_blocks = ["0.0.0.0/0"]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow port 80"
  }
}


resource "tls_private_key"  "mytask2key"{
	algorithm= "RSA"
}


resource  "aws_key_pair"   "generated_key"{
	key_name= "mytask2key"
	public_key= "${tls_private_key.mytask2key.public_key_openssh}"
	
	depends_on = [
		tls_private_key.mytask2key
		]
}


resource "local_file"  "store_key_value"{
	content= "${tls_private_key.mytask2key.private_key_pem}"
 	filename= "mytask2key.pem"
	
	depends_on = [
		tls_private_key.mytask2key
	]
}

resource "aws_efs_file_system"  "allow-nfs"{
	creation_token="allow-nfs"
  tags={
       Name= "allow-nfs"
 }
}

resource "aws_efs_mount_target"  "efs_mount"{
  file_system_id= "${aws_efs_file_system.allow-nfs.id}"
  subnet_id= "subnet-24ebd14c"
   security_groups= [aws_security_group.task2_sg.id]
}



resource "aws_instance" "task2os" {
  	ami  = "ami-0447a12f28fddb066"
 	 instance_type = "t2.micro"
 	 key_name = "mytask2key"
  	security_groups= ["task2_sg"]

  connection {
    type     = "ssh"
    user     = "ec2-user"
   private_key= "${tls_private_key.mytask2key.private_key_pem}"
    host     = "${aws_instance.task2os.public_ip}"
  }


  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd   git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "task2os"
  }
}

output "myos_ip" {
  value = aws_instance.task2os.public_ip
}




resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  aws_instance.task2os.public_ip > publicip.txt"
  	}
}


resource "null_resource" "nullremote3"  {

depends_on = [
    aws_efs_mount_target.efs_mount,
  ]
 connection {
    type     = "ssh"
    user     = "ec2-user"
     private_key = "${tls_private_key.mytask2key.private_key_pem}"
    host     = "${aws_instance.task2os.public_ip}"
}


provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Pheonix-reaper/Task2_Cloud.git    /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "task2_bucket" {
  bucket = "task2cloud-bucket-asish-007-s3bucket"
  acl="public-read"
 force_destroy=true


tags = {
    Name = "My bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "aws_public_access" {
  bucket = "${aws_s3_bucket.task2_bucket.id}"


 block_public_acls   = false
  block_public_policy = false
}

resource "aws_cloudfront_distribution" "imgcloudfront" {
    origin {
        domain_name = "asishpatnaik_task2_bucket.s3.amazonaws.com"
        origin_id = "S3-asishpatnaik_task2_bucket" 


          custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true




    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-asishpatnaik_task2_bucket"



     forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            
            restriction_type = "none"
        }
    }


# SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}



     