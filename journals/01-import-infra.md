# Importing existing AWS resources

## 2021-12-22

First day of actually working on Terraforming https://omnomnomi.ca. Plan for this phase of work is to import the existing infrastructure, simple and janky as it may be. This step should include scripts to install the appropriate applications and upload the site files, database dump, and Apache configuration files to the right place so that the website deploys correctly _as is_.

What I know/remember about this site without additional discovery:
* Is a simple [Wordpress blog](https://wordpress.com/) on [LAMP stack](https://www.fdcservers.net/blog/benefits-of-lamp-as-a-web-development-platform) hosted on an always-on EC2 instance that's been steadily sucking a trickle of money from me for several years
  * Wordpress because I was already doing tech support for work and just wanted a place to keep my recipes
    * It was actually too much work to type the recipes out for publishing rather than just note them down as templated LibreOffice files in a Google Drive folder
  * AWS because I wanted to learn AWS
    * Hilariously, I just ended up recreating a traditional monolithic architecture and did nothing with it for years
      * That's what this project is for, I guess!
* DNS is via Route 53
  * Better way to learn AWS than going with my domain registrar
* Site certificates provided by an auto-renewing Let's Encrypt script
  * Something broke the script earlier this year and I haven't cared enough to fix it
    * Guess I will now

### Take backups
* Re-enabled MFA on my AWS root account, as I wanted to back its key up to my password manager 
  * It's been so long that I still had the old AWS logo (not the blue smile one, the yellow one) on my phone app for the token
* Imported EC2 instance key from backup to my dev machine
* SSHed into EC2 instance using the recommended syntax from the AWS console:
  * `ssh -i "/path/to/keyfile.key" username@my_ec2_instance_dns_name`
* Archived HTML file directory to file (used [`zip`](https://linux.die.net/man/1/zip) because I could actually remember the syntax)
* Dumped corresponding WP site DB to file ([`mysqldump`](https://linux.die.net/man/1/mysqldump))
* Transferred the following to my dev machine as backup (using [`rsync`](https://linux.die.net/man/1/rsync)):
  * HTML archive file
  * DB dump file
  * `omnomnomi.ca*.conf` files from `/etc/apache2/sites-available/`

### Inventory existing resources
* Initial exploration was the simple way via console
* Current infra consists of:
  * One [VPC](https://aws.amazon.com/vpc/) containing:
    * One [EC2](https://aws.amazon.com/ec2/) instance
  * One [Route53](https://aws.amazon.com/route53/) hosted zone with a default record set
* I've lost my patience for clickops so I'm saving the rest for doing with [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
  * Installed the CLI per [instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  * Created a new user `terraform-dev` with the default `Admin` permissions policy
    * I didn't have any such users already in existence because I was managing everything manually via SSH and console access
  * Configured my AWS CLI user profile with `aws condfigure` per [doc](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html#getting-started-quickstart-new)
  * Enabled tab completion per [doc](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html#cli-command-completion-enable)
* Queried existing infra using AWS CLI as follows:
  ```bash
  for region in `aws ec2 describe-regions --region us-east-1 --output text | cut -f4`; do echo -e "\nListing instances in region:'$region'..."; aws ec2 describe-instances --region $region; done # Get a list of all instances running in all regions, thanks to https://stackoverflow.com/questions/42086712
  aws ec2 describe-instances --region us-west-2 > ec2-instances.txt # Dump details of my only running instance
  aws route53 list-hosted-zones
  aws route53 get-hosted-zone --id "/hostedzone/Z1J4PR9A2O6EUI" > hosted-zones.txt
  aws ec2 describe-vpcs > vpc.txt
  aws ec2 describe-network-acls > acls.txt
  aws ec2 describe-security-groups > security-groups.txt
  aws route53 list-resource-record-sets --hosted-zone-id "/hostedzone/Z1J4PR9A2O6EUI" > dns-records.txt
  ```
  * I don't actually know if that's all the relevant resources, but it passes a sanity check

### Write Terraform config to prep for resource import
* Updated Terraform version to newest
  * While I'm at it, turned it into a script
* Added empty files corresponding to different resource types and necessary varfiles to avoid temptation to make one giant file

### Misc notes, gotchas, questions, and follow-up intentions
* Needed to set up `~/.ssh/config` to use passwordless keyfile authentication with `rsync`:
  ```
  Host my_ec2_instance_dns_name
  User my_username
  IdentityFile ~/.ssh/my_key_name.key
  ```
  * `rsync` daemon does **not** encrypt data in transit by default
  * To `rsync` using encryption, specify a communications protocol in your command invocation like `rsync -e ssh <SOURCE> <DESTINATION>`
* EC2 instances are created with no password auth permitted ([see discussion](https://serverfault.com/questions/334448/why-is-ssh-password-authentication-a-security-risk))
  * If you really really want to allow password auth:
    * Add new local users with `passwd`
    * Update `/etc/sshd_config` with `PasswordAuthentication yes`
      * If you want root to be able to password auth, update `PermitRootLogin` to `yes`
* I don't remember having had to do manually set up AWS CLI tab completion before
  * Was that because I was using AWS CLIv1 and this is v2?
    * Do I care enough to test?
      * Not really
* The info I got about my existing infrastructure is a lot more than I expected to get for such a simple infrastructure
  * I am coming to the uncomfortable realization that the way I did it is only feasible because I have advance knowledge of:
    * Which resources exist (thanks to having created them)
    * Which implicit or dependent resources accompany them (because I know to look for them due to prior AWS experience, including AWS-SA2 exam prep)
  * The above isn't feasible discovery in an environment I'm brand new to
  * #TODO: Find or design an AWS CLI script or first-party console utility that does what I tried to do today for discovery, but more comprehensively
* I created `terraform-dev` with programmatic access only, but I didn't check to see what's needed for the ability to switch roles in the web console

## 2021-12-23

### Write Terraform config (continued)
* Copied the infra info I queried the other day into the appropriate-looking infra config files for translation into Terraform
  * Grabbed details for `terraform-dev` IAM user since I hadn't done that yesterday
  * Didn't actually turn out to be that interesting
* Realized a no-downtime import with zero changes at all needs to be approached differently from a config that allows for a small amount of downtime
  * What do I actually _need_ saved for this phase?
    * Persist the EBS instance and ensure it remains attached to the EC2 instance
    * Maintain an A record pointing my domain name to the EC2 instance's public IP address
    * Script the Wordpress installation, DB config and import, and Let's Encrypt script, and deploy after instance is up
* I imported these and it looks like both the EC2 instance and the boot volume are just being updated in place when I run `terraform plan`: `aws_ebs_volume.web_boot` `aws_instance.web`



### Misc notes, gotchas, questions, and follow-up intentions
* Why isn't autocomplete _automatically completing_?
  * I have to run `complete -C '/usr/local/bin/aws_completer' aws` on each new shell start (added it to `~/.bashrc`)
  * Again, I don't recall having had to do that in WSL during my last project
* I really like that `Shift + Ctrl + Alt` multi-line cursor trick in VS Code
* **Big problem:** I honestly really hate this idea because no one uses AWS like this, especially not for WordPress, and I just don't believe in the goal
  * [This blog](https://www.codeinwp.com/blog/serverless-wordpress-shifter-vs-hardypress-top-headless-wordpress-hosting-options-compared/) says serverless WordPress is possible
    * You can't have dynamic content: comments, forums, membership, contact forms, search
      * I don't care at all about any of those things except the search
      * Can probably add a Google Search widget to fix it
    * Site will need to be reconverted every time there's a change made
  * [This blog](https://keita.blog/2019/06/27/serverless-wordpress-on-aws-lambda/) says serverless Wordpress is possible
* I'm still not going to give up on this exercise because the _point_ of this phase is to play around with imports, not generate a serverless blog

## 2022-01-04: TBD