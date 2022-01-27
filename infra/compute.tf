resource "aws_key_pair" "deployer_public_key" {
  key_name   = "deployer-key"
  public_key = var.ec2_deployer_public_key
  tags = {
    "Name" = "terraform-managed"
  }
}

resource "aws_vpc" "default" {
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.default.id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "webserver" {
  name        = "web"
  description = "Group for web access"
  vpc_id      = aws_vpc.default.id
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]

  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "HTTP traffic"
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    },
    {
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "HTTPS traffic"
      from_port        = 443
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 443
    }
  ]
}

resource "aws_instance" "web" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${aws_security_group.webserver.id}"]
  key_name                    = aws_key_pair.deployer_public_key.key_name
  availability_zone           = "us-west-2b"
  iam_instance_profile        = aws_iam_instance_profile.backup_and_restore.name

  tags = {
    "Name" = "omnomnomi_webserv"
  }

  # Upload backup script; restore-website.sh will move it and configure the
  # appropriate cron job
  provisioner "file" {
    source      = "../scripts/back-up-website.sh"
    destination = "/home/ubuntu/back-up-website.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_deployer_private_key
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "file" {
    source      = "../scripts/lets-encrypt.sh"
    destination = "/home/ubuntu/lets-encrypt.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_deployer_private_key
      host        = aws_instance.web.public_ip
    }
  }

  # Upload and run script to install prerequisites and configure website
  provisioner "file" {
    source      = "../scripts/restore-website.sh"
    destination = "/home/ubuntu/restore-website.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_deployer_private_key
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/restore-website.sh",
      "/home/ubuntu/restore-website.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_deployer_private_key
      host        = aws_instance.web.public_ip
    }
  }
}
