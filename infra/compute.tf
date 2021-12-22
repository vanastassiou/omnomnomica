resource "aws_instance" "web" {
}

resource "aws_ebs_volume" "web_boot" {
}

resource "aws_eip" "server_ip" {
  instance = aws_instance.web.id
  vpc      = true
}