resource "aws_instance" "web" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  associate_public_ip_address = true

  provisioner "file" {
    source      = "scripts/restore-website.sh"
    destination = "/home/ubuntu/restore-website.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/restore-website.sh",
      "/home/ubuntu/restore-website.sh",
    ]
  }

  provisioner "file" {
    source      = "backups/"
    destination = "/home/ubuntu"
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
