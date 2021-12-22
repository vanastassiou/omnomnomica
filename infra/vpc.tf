{
    "Vpcs": [
        {
            "CidrBlock": "172.31.0.0/16",
            "DhcpOptionsId": "dopt-e360ca84",
            "State": "available",
            "VpcId": "vpc-c159d8a6",
            "OwnerId": "738685627511",
            "InstanceTenancy": "default",
            "CidrBlockAssociationSet": [
                {
                    "AssociationId": "vpc-cidr-assoc-3983e651",
                    "CidrBlock": "172.31.0.0/16",
                    "CidrBlockState": {
                        "State": "associated"
                    }
                }
            ],
            "IsDefault": true
        }
    ]
}

{
    "NetworkAcls": [
        {
            "Associations": [
                {
                    "NetworkAclAssociationId": "aclassoc-dc86f3a4",
                    "NetworkAclId": "acl-c20f5ba5",
                    "SubnetId": "subnet-13792c74"
                },
                {
                    "NetworkAclAssociationId": "aclassoc-db86f3a3",
                    "NetworkAclId": "acl-c20f5ba5",
                    "SubnetId": "subnet-21a4c27a"
                }
            ],
            "Entries": [
                {
                    "CidrBlock": "0.0.0.0/0",
                    "Egress": true,
                    "Protocol": "-1",
                    "RuleAction": "allow",
                    "RuleNumber": 100
                },
                {
                    "CidrBlock": "0.0.0.0/0",
                    "Egress": true,
                    "Protocol": "-1",
                    "RuleAction": "deny",
                    "RuleNumber": 32767
                },
                {
                    "CidrBlock": "0.0.0.0/0",
                    "Egress": false,
                    "Protocol": "-1",
                    "RuleAction": "allow",
                    "RuleNumber": 100
                },
                {
                    "CidrBlock": "0.0.0.0/0",
                    "Egress": false,
                    "Protocol": "-1",
                    "RuleAction": "deny",
                    "RuleNumber": 32767
                }
            ],
            "IsDefault": true,{
    "ResourceRecordSets": [
        {
            "Name": "pleasantjams.ca.",
            "Type": "A",
            "TTL": 300,
            "ResourceRecords": [
                {
                    "Value": "52.32.130.234"
                }
            ]
        },
        {
            "Name": "pleasantjams.ca.",
            "Type": "NS",
            "TTL": 172800,
            "ResourceRecords": [
                {
                    "Value": "ns-1529.awsdns-63.org."
                },
                {
                    "Value": "ns-792.awsdns-35.net."
                },
                {
                    "Value": "ns-507.awsdns-63.com."
                },
                {
                    "Value": "ns-1765.awsdns-28.co.uk."
                }
            ]
        },
        {
            "Name": "pleasantjams.ca.",
            "Type": "SOA",
            "TTL": 900,
            "ResourceRecords": [
                {
                    "Value": "ns-1529.awsdns-63.org. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
                }
            ]
        },
        {
            "Name": "www.pleasantjams.ca.",
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

            "NetworkAclId": "acl-c20f5ba5",
            "Tags": [],
            "VpcId": "vpc-c159d8a6",
            "OwnerId": "738685627511"
        }
    ]
}

{
    "SecurityGroups": [
        {
            "Description": "default VPC security group",
            "GroupName": "default",
            "IpPermissions": [
                {
                    "IpProtocol": "-1",
                    "IpRanges": [],
                    "Ipv6Ranges": [],
                    "PrefixListIds": [],
                    "UserIdGroupPairs": [
                        {
                            "GroupId": "sg-4d94c734",
                            "UserId": "738685627511"
                        }
                    ]
                }
            ],
            "OwnerId": "738685627511",
            "GroupId": "sg-4d94c734",
            "IpPermissionsEgress": [
                {
                    "IpProtocol": "-1",
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "Ipv6Ranges": [],
                    "PrefixListIds": [],
                    "UserIdGroupPairs": []
                }
            ],
            "VpcId": "vpc-c159d8a6"
        }
    ]
}
