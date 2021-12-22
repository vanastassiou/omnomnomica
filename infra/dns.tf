resource "aws_route53_zone" "main" {
  name = "example.com"
}

resource "aws_route53_zone" "dev" {
  name = "dev.example.com"

  tags = {
    Environment = "dev"
  }
}

resource "aws_route53_record" "dev-ns" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "dev.example.com"
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.dev.name_servers
}

{
    "HostedZone": {
        "Id": "/hostedzone/Z2XHBKAJC40VY8",
        "Name": "omnomnomi.ca.",
        "CallerReference": "CFBB9845-1C7D-FAFD-A8A1-7AAEA910430D",
        "Config": {
            "PrivateZone": false
        },
        "ResourceRecordSetCount": 4
    },
    "DelegationSet": {
        "NameServers": [
            "ns-162.awsdns-20.com",
            "ns-582.awsdns-08.net",
            "ns-1640.awsdns-13.co.uk",
            "ns-1451.awsdns-53.org"
        ]
    }
}

{
    "ResourceRecordSets": [
        {
            "Name": "omnomnomi.ca.",
            "Type": "A",
            "TTL": 300,
            "ResourceRecords": [
                {
                    "Value": "52.32.130.234"
                }
            ]
        },
        {
            "Name": "omnomnomi.ca.",
            "Type": "NS",
            "TTL": 172800,
            "ResourceRecords": [
                {
                    "Value": "ns-162.awsdns-20.com."
                },
                {
                    "Value": "ns-582.awsdns-08.net."
                },
                {
                    "Value": "ns-1640.awsdns-13.co.uk."
                },
                {
                    "Value": "ns-1451.awsdns-53.org."
                }
            ]
        },
        {
            "Name": "omnomnomi.ca.",
            "Type": "SOA",
            "TTL": 900,
            "ResourceRecords": [
                {
                    "Value": "ns-162.awsdns-20.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
                }
            ]
        },
        {
            "Name": "www.omnomnomi.ca.",
            "Type": "A",
            "TTL": 300,
            "ResourceRecords": [
                {
                    "Value": "52.32.130.234"
                }
            ]
        }
    ]
}