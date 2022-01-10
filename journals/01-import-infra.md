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
  * Do I dare `apply` right now, the day before my Xmas vacation starts? Probably not

### Update scripts
* Added scripts to install/update Terraform and plan a deployment
  * As of this writing, the plan updates the EC2 instance and boot volumes in place, and creates a new Route53 zone with an A record

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

## 2022-01-04: Welcome back to work
### Prep thoughts after winter break
* Current infra updates EC2 instance and boot volumes in place, creates new Route53 zone with A record
* Sounds pretty good to me at this point, especially as I still have the updates of the actual site
* #TODO: set up backup script that dumps DB and WP PHP files and sends files to S3
  * Not elegant but that's fine for now
* Today:
  * Write script to do `terraform apply` with the necessary flags, test the apply
  * Test plan/apply
  * Write backup/dump and restore scripts
  * Figure out how to implement backup and restore scripts as part of automated process that *isn't* part of the cloud infra

### Planning and implementing the restore script
* Confirmed that plan/apply do work to preserve the existing state of the website (i.e. resources have been successfully imported)
  * However, this infra isn't very useful for redeploying the entire thing
  * Can use TF's [`file`](https://www.terraform.io/language/resources/provisioners/file) and [`remote-exec`](https://www.terraform.io/language/resources/provisioners/remote-exec) provisioners to run a post-install script
    * "Provisioners should only be used as a last resort" says the doc and refers you to [the main Provisioners page](https://www.terraform.io/language/resources/provisioners) for more info, but doesn't explain why
    * Probably the issue is the state of the machine's config is not trackable this way, so Terraform's strength is useless here
      * #TODO: refactor this using Ansible or Puppet in future phase of project
* Wrote `restore-website.sh` anyway, with the above limitations in mind
  * Need to make sure that the script, if run in place, doesn't *append* any data when re-injecting it into the appropriate places, just *overwrites* it
  * Changed the AMI from the ancient Ubuntu one to the most updated one; why?
    * I need the most recent Ubuntu for the packages to support the software I want
    * Upgrading Ubuntu requires a system restart and I expect this to cause a timeout if I `remote exec` this as part of provisioning the EC2 instance
    * Per the [Ubuntu Amazon EC2 AMI locator](https://cloud-images.ubuntu.com/locator/ec2/), I should be using `ami-078278691222aee06` or `ami-0892d3c7ee96c0bf7` for my region for 20.04 LTS
      * This will force instance destruction and re-creation
      * Goodbye, ancient cloud instance!
* Ran into this problem when pushing the backups zip (manually):
  ```bash
  remote: error: Trace: 4fab61c08909b9bfb49e66b6e1b12e89aeacae6b641844327dde2800c2ab9ab1
  remote: error: See http://git.io/iEPt8g for more information.
  remote: error: File backups/omnomnomica.zip is 659.85 MB; this exceeds GitHub's file size limit of 100.00 MB
  remote: error: GH001: Large files detected. You may want to try Git Large File Storage - https://git-lfs.github.com.
  To github.com:vanastassiou/omnomnomica.git
  ! [remote rejected] import-existing-infra -> import-existing-infra (pre-receive hook declined)
  error: failed to push some refs to 'git@github.com:vanastassiou/omnomnomica.git'
  ```
  * I can get around this by breaking the zip down into multiple different directories, but I'm not going to, because:
    * Tedious
    * Prone to human error in creating, uploading, extracting processes
    * Don't get to learn anything new
  * [Git LFS](https://git-lfs.github.com/) to the rescue:
    ```bash
    # See doc at https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-migrate.1.ronn
    sudo apt install git-lfs
    git lfs install
    git lfs migrate info
    git lfs migrate import --include="*.zip"
    ```
### Planning and implementing backup script
* Typical way to do it is `cron` job with `rsync` (consult [tutorial](https://www.jveweb.net/en/archives/2011/02/using-rsync-and-cron-to-automate-incremental-backups.html))
* Can't `rsync` directly to an S3 bucket, but can use an IAM user with RW access to S3 plus AWS CLI on the EC2 instance ([reference](https://serverfault.com/questions/754690/rsync-to-aws-s3-bucket))
* I'm using `zip` to compress/archive to minimize storage and retrieval costs for S3, but I notice most advice to avoid zipping an absolute path is to manipulate the directory stack
  * #TODO: see if other compression/archive utilities do this more gracefully 

### Misc notes, gotchas, questions, and follow-up intentions
* TIL [`ronn`](https://rtomayko.github.io/ronn/ronn.1.html)
* Using constants/variables/other names in scripts and config vs hard-coded values really does make it a lot easier to understand what the script/conf is trying to do

## 2022-01-05: Test backup and restore, then `apply`
* Need to implement automatically retrieving latest backup from S3 during `apply.sh`, then test backup and apply/restore
* Next phase should add support for different deployment environments -- currently only using `vars.tfvars`
* Testing restore script
  * Set up passwordless auth for MySQL using `~/my.cnf`; using `-p` CLI option exposes the password in cleartext to any utilities that examine running processes (`proc`, `ps`)
  * I kept getting the help text when I ran commands using `mysql -e -u root <COMMANDS>;`, meaning MySQL didn't like the syntax
    * I got around this by using a heredoc ([source](https://gist.github.com/Wieljer/1b7a0573fd37abdef3c105deb306db62#file-setup_drupal-bash-L30)), which is tidier and DRYer
    * #TODO: find out why `mysql -e -u root <COMMANDS>;` is invalid MySQL syntax
* Testing backup script
  * Need a way to verify backups
    * Verify file transfer to S3: compare sizes of local file to the one AWS received
    * Verify integrity of dump and zip?
  * #TODO: Enhancement ideas for daily `cron` backup job:
    * Implement diff between filesizes and proceed with S3 upload only if different
      * Compare today's local files vs file sizes on s3
        * This is already done, so make it a function
    * Implement local cleanup of `/tmp` after verifying S3 upload
    * Implement backup and restore logging
    * Implement backups rotation schedule
* Now to automate deployment
  * Let's get this started with [GitHub Actions](https://docs.github.com/en/actions/learn-github-actions/workflow-syntax-for-github-actions#env)
  * #TODO: during improvement phase, migrate to a CI/CD provider people actually use
* Ended up creating `dev`, `test`, and `stage`, branches, and renamed my feature branch to prepend `feature/`
* Wrapped up the day by doing a big rebase to group trivial changes together and make commit messages more meaningful

### Misc notes, gotchas, questions, and follow-up intentions
* I don't understand this behaviour:
  ```bash
  $ cd ${VHOST_FILE_LOCATION}
  $ ls -la | grep ${WEBSITE_DOMAIN}
  -rw-r--r-- 1 root root  724 May 16  2018 omnomnomi.ca.conf
  -rw-r--r-- 1 root root  625 Jan  4 20:18 omnomnomi.ca-le-ssl.conf
  $ zip -u "${TEMP_DIR}/${SITEFILES_ZIP}" "./${WEBSITE_DOMAIN}*"
          zip warning: name not matched: ./omnomnomi.ca*
  $ for name in "${WEBSITE_DOMAIN}*"; do zip -u "${TEMP_DIR}/${SITEFILES_ZIP}" $name; done
    adding: omnomnomi.ca.conf (deflated 60%)
    adding: omnomnomi.ca-le-ssl.conf (deflated 51%)
  ```
* I had to go back and rebase a commit because I grouped unrelated changes; [here's how I did it](https://stackoverflow.com/questions/1186535/how-to-modify-a-specified-commit/29950959#29950959)
* I ran into [this issue with AWS CLI S3 file transfers over 500 MB getting a `Killed` message](https://github.com/aws/aws-cli/issues/1775); I worked around it by removing a couple of unnecessary large files, but the issue seems to be ongoing 
  * I didn't want to lose focus and troubleshoot this, but this is a note in case it happens again in the future

## 2022-01-06: OK, `apply` for real, this time
* Tested backup and restore scripts on the command line of existing instance, and took backups to S3 as well as having local copies, so let's try an `apply` now
* On `apply.sh`, got the following as a result of the EBS attachment needing to be replaced due to the instance re-creation:
  ```bash
  → ./apply.sh 
  aws_volume_attachment.ebs_attachment: Destroying... [id=vai-2330037030]
  ╷
  │ Error: Failed to detach Volume ([REDACTED]) from Instance ([REDACTED]): IncorrectState: Unable to detach root volume '[REDACTED]' from instance '[REDACTED]'
  │       status code: 400, request id: [REDACTED]
  ```
* Looks like [this issue here](https://github.com/hashicorp/terraform/issues/2957) might be related -- shutting down the EC2 instance as suggested helped
* Next bump: forgot to add [provisioner connection details for the EC2 instance](https://www.terraform.io/language/resources/provisioners/connection)
  * For development purposes only, I'm using a `data.local_file` resource reading the contents of a private keyfile
    * #TODO: once this works, refactor to use `local-exec` with AWS CLI `ec2-instance-connect` to [send a temporary public key for this connection](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2-instance-connect/send-ssh-public-key.html)
* This problem now:
  ```bash
  │ Error: file provisioner error
  │ 
  │   with aws_instance.web,
  │   on compute.tf line 21, in resource "aws_instance" "web":
  │   21:   provisioner "file" {
  │ 
  │ timeout - last error: dial tcp 18.237.16.124:22: i/o timeout
  ╵
  ```
  * Looks like [this error](https://stackoverflow.com/questions/66462599/terraform-file-provisioner-cant-connect-ec2-over-ssh-timeout-last-error-dia), where the problem appeared to be a missing security group
  * Fixed by importing the existing security groups, running `plan.sh`, and updating config blogs based on the resulting diffs
* Now: `CannotDelete: the specified group: "sg-2b18b54d" name: "default" cannot be deleted by a user`
  * Solution: don't change the attribute that forces deletion
* Ran into `Package 'zip' has no installation candidate` when running restore script
  * Apparently this is a known issue on AWS machines?
  * Suggested solution: "the list of the package sources in AWS is populated by cloud-init, which takes...around 3-5 seconds so you can't notice it when doing stuff manually, but if there’s some automation, and the first thing it does is apt-get update, you can get in trouble. The solution is simple: wait for cloud init to finish. It’s got a helpful `cloud-init status --wait` command just for that." ([source](https://forum.gitlab.com/t/install-zip-unzip/13471/9))
* Troubleshot `restore-website.sh` and got it to a point where Apache loads the site correctly, but I noticed I can't browse to the domain
  * Turns out I hadn't imported the DNS zone and Terraform had created a second one of the same name (didn't know AWS allowed that)
  * I just deleted the old one 
    * That was dumb
    * I should have imported it and deleted the new one
      * Now my nameservers have changed and I have to update them with my domain registrar, and DNS propagation is annoying to wait for (I don't remember it taking more than a few minutes before)

### Misc notes, gotchas, questions, and follow-up intentions
* TIL [`terraform plan` output is not readable text by design](https://discuss.hashicorp.com/t/terraform-plan-write-out-is-not-readable-text/7568)
  * Get around this by using `terraform show planname.plan` or `terraform show -no-color plans/2022-01-06_12-01-17.plan > plan.txt` to save to a file without weird `Esc` characters
* `terraform import` followed by `terraform plan` and checking the diff is a great way to be told exactly which attributes are needed in your resource configuration

## 2022-01-07: It's not DNS/There's no way it could be DNS/It was DNS
* Turns out that my domain registrar hadn't actually saved my name server modifications (!?) so hopefully there isn't much of a propagation delay now
  * Name servers are updated with registrar
    ```bash
    → whois omnomnomi.ca | grep "Name Server"
    Name Server: ns-1298.awsdns-34.org
    Name Server: ns-1597.awsdns-07.co.uk
    Name Server: ns-194.awsdns-24.com
    Name Server: ns-660.awsdns-18.net
    ```
  * Doesn't seem to have propagated though:
    ```
    → nslookup omnomnomi.ca
    Server:         172.27.176.1
    Address:        172.27.176.1#53
    ** server can't find omnomnomi.ca: SERVFAIL
    ```
  * I've updated my hosts file in the meantime to test server functionality
* Browsing to https://omnomnomi.ca doesn't work; server error
  * Commented out the HTTP -> HTTPS redirect in the virtual host conf, restarted Apache; nothing
  * Added `index.html` in document root just in case; it's reachable, meaning there's a problem with Wordpress, not the server's accessibility
  * I deleted `index.html` and browsing to my domain got me a message from WordPress telling me `php-mysql` was missing
    * Installed `libapache2-mod-php php-mysql`
      * TADA! Site is fully restored and browsable
* `dig` shows the A record has been updated in global DNS as well, so hooray for that as well
* Now to upload backup script and add it to crontab
  * My MySQL `root` user doesn't seem to have login privileges either interactively or relying on `~/.my.cnf`
    * I tried `ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '[REDACTED]';` but this locked me out so I had to regain entry with:
    ```bash
    $ cat > mysql.txt << EOF
    GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
    EOF

    $ service mysql restart --init-file mysql.txt
    ```
    * I can log in interactively now, but passwordless auth isn't working yet
      * You know what, I don't actually need to do this...I'll just `sudo mysql` and work with that
* Problems to fix:
  * I'm still running into problems with where I extract files during `restore-website.sh`
  * Let's Encrypt won't work on a freshly created instance because it needs to wait for global DNS to propagate; I can either:
    * Write a `cron` job to `dig omnomnomi.ca` every few minutes and then run this only if a valid result is obtained:
      ```bash
      # Set up SSL/TLS certs with Let's Encrypt, redirect HTTP -> HTTPS
      sudo apt install -y certbot python3-certbot-apache
      sudo certbot --non-interactive --agree-tos -m vanastassiou+letsencrypt@gmail.com --apache -d "${WEBSITE_DOMAIN}" --keep-until-expiring --redirect # Avoid requesting new cert needlessly to prevent rate limiting
      ```
    * Switch to ACM, which is against the spirit of this phase of work

### Misc notes, gotchas, questions, and follow-up intentions
* What's the difference between `crontab` and `cron.daily`, `cron.weekly`, etc.? ([reference](https://devconnected.com/cron-jobs-and-crontab-on-linux-explained/))
  1. `cron.service` runs in the background and runs the `cron.d` daemon every minute
  1. `cron.d` checks the contents of `/etc/cron.*/`  for scripts that may need to be run
    * How to define cron jobs?
      * Interactively as a user: use `crontab -e` to edit your own jobs
        * The edits are all to a single file that is stored in `/var/spool/cron/crontabs/<YOUR_USERNAME>` (privileged access only)
      * Systemwide as `root` or another defined user:
        1. For each job, create a file in `/etc/cron.d/` containing the env vars you want to use and an expression in cron syntax for the command or script to run; e.g.:
          ```bash
          $ cat ../cron.d/popularity-contest 
          SHELL=/bin/sh
          PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
          7 18 * * *   root    test -x /etc/cron.daily/popularity-contest && /etc/cron.daily/popularity-contest --crond
          ```
        1. If Step 1 involves executing a script, place the script in the appropriate `/etc/cron.hourly` (or `.daily`, `.weekly`, etc.) directory with `root:root` ownership and `755` permissions
          * This location is by convention
          * You can point to any script in any location in your cron job definition and it will run as long as it has the right permissions
* Is comparing zipfile and dump sizes an adequate way of determining whether the website has changed since last backup?

## 2022-01-10: Unattended installation
* Right now I have the choice between:
  * Improving logging for my scripts, since  `echo` is totally useless for unattended installations
  * Making the GitHub Action workflow to deploy the infra work, since `echo` probably _won't_ be useless if Actions is like other CI/CD tools and logs STDOUT for each run
    * This one sounds like a better use of my time today
* My GitHub repo is set up with the `S3_USER_AWS_ACCESS_KEY_ID` and `S3_USER_AWS_SECRET_ACCESS_KEY` secrets for the `dev` environment, so that's a good start
