# The below is for local testing purposes only

data "local_file" "ec2_deployer_private_key" {
  filename = "${path.root}/../../../.ssh/omnomnomica-ec2-deployer"
}

data "local_file" "ec2_deployer_public_key" {
  filename = "${path.root}/../../../.ssh/omnomnomica-ec2-deployer.pub"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = data.local_file.ec2_deployer_public_key.content
}

resource "aws_vpc" "default" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_security_group" "default" {
  vpc_id = aws_vpc.default.id
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
      cidr_blocks      = []
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = true
      to_port          = 0
    }
  ]
}

resource "aws_security_group" "webserver" {
  vpc_id = aws_vpc.default.id
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
      cidr_blocks = [
        "0.0.0.0/0"
      ]
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

  provisioner "file" {
    source      = "scripts/restore-website.sh"
    destination = "/home/ubuntu/restore-website.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = data.local_file.ec2_deployer_private_key.content
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
      private_key = data.local_file.ec2_deployer_private_key.content
      host        = aws_instance.web.public_ip
    }
  }

  provisioner "file" {
    source      = "backups/"
    destination = "/home/ubuntu"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = data.local_file.ec2_deployer_private_key.content
    host        = aws_instance.web.public_ip
  }
}

resource "aws_ebs_volume" "web_boot" {
  availability_zone = "us-west-2b"
  size              = 20
}

resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sda1"
  volume_id   = aws_ebs_volume.web_boot.id
  instance_id = aws_instance.web.id
}
