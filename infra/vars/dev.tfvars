region                  = "us-west-2"
ami_id                  = "ami-0892d3c7ee96c0bf7" # us-west-2
instance_type           = "t2.micro"
base_domain_name        = "dev.omnomnomi.ca"
ec2_deployer_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWOiMWW+8FnSWAO4XuMdC6aZeHBQnWHvbhpwYjHfD5LwU8MAs7pjzAQezvmFp8RqRUnManJmR4ee5uNP34X+Hm2NgkOdt2c7uX57Zukbfh0CMKaAuKt/nHwTcUTby8wj3ojPT5enr5UqKlxR3iKP9vkDGOPjCL5598UO2j77VmMDTFTJ/QnnklySCmEQXTM8KyQ/lWUm/R7rgKjBKB9Yt/zMcRT7RNYa5JRYPDA5q/SO/NfoXEb/4/Dnk9VG4YRk/8AYoZYZJhnRBxNrWsHctI/MBLYhRw4066HWVOOIAAFS2c6B1T/L4+18BsHYSukxF7YIfJ0qYMGTPBp78grI7ZfCqC1IL89zdj22rbXT2/gXErbcp6ZcU6Np9QahBzcUnMg7xsKUVm8FhGkTcnlZM7R+7tOf7+HAdVdgHoQv334O3dzZJh1JrA07f1VQLP7fU+Vz+6NYF4RLT3l0AfB3n3dYmUrD49gmI1gkFoYEa+N+3dJ/xXRrJtW7RN8/D7UOs= terraformer@laptop"
# ec2_deployer_private_key is stored in the GitHub repo secret and exposed during the deployment workflow as TF_VAR_ec2_deployer_private_key
