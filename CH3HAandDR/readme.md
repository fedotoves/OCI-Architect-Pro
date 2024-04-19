Best way to use this sample is to go through OCI architect course for Exam 1Z0-997-23: 
Oracle Cloud Infrastructure 2023 Architect Professional
located here: https://mylearn.oracle.com/ou/course/oracle-cloud-infrastructure-architect-professional/122659/
Go step by step adding resources as necessary.

There are four folders, CH3HAandDR for High availability, 
CH3FSDR and CH3FSDRSecondRegion for full stack disaster recovery 
and FSDRPlan folder inside CH3FSDRSecondRegion folder to deal with circular dependencies
while creating replication

There is no video / instructions in this chapter on how to create web server for word press
and separate database server. So I'm creating custom ones myself. This is multistep process:
Step 1 - create 2 separate compute instances with Ubuntu - web and db
Step 2 - Using instructions install WordPress engine on first and MySql on second
Step 3 - connect WordPress and MySql so that they can run
Step 4 - convert configured instances to custom images - so I can delete/create them any time
(don't want to waste resources when I'm not working on this lesson)
Step 5 - update terraform here with custom images deployment

it is done in ha-dr-resources/main.tf file

This solution is not using "Always free" tier from OCI (may be refactored later)
and some resources and not free including domain name, security certs, OCI resources etc., 
so some expenses are required.

However, if you want to deploy the entire infrastructure at once, you need following manual steps
( after step one all others can be done in any order, just do them):
1. Create OCI account
2. Install terraform from hashicorp.com
3. Add your user to OCI_Administrators group
4. Fill variables file in the root of this chapter by your values, including generated ssh key
5. Generate ssh key for servers and paste public key to OCIArchitectCH3ServersKey.key.pub. 
Run chmod 400 <PRIVATE_KEY_FILE>
6. Steps to install WordPress and MySql to Ubuntu machines (described in details in ha-dr-resources/main.tf)
Find resource "oci_core_public_ip" "web_server_public_ip" in ha-dr-resources/main.tf and uncomment line
private_ip_id = data.oci_core_private_ips.webserver_private_ips.private_ips[0].id before running 
terraform apply if you are applying for a first time. You need to comment this line later, 
after creating load balancer. Also check comments in ha-dr-resources/main.tf for more details 
about creating instances and configuring them. Description is right after resource 
"oci_core_public_ip" "web_server_public_ip". 
7. Create security certificate (you can find my suggestion in comments if you search for "SSL Cert") in networking/main.tf 
8. Manually subscribe to second region besides your home region (for this chapter I'm using US West - San Jose)
seems that volume replication is not allowed by default between continents, so I cannot use Germany Central - Frankfurt (as in chapter 2)
as I'm getting │ Error: 400-InvalidParameter, Destination region eu-frankfurt-1 is not valid, Select a valid region and retry.
Refer to the Volume Replica documentation for the list of valid destination regions for each region.
So I'm using San Jose (USA) as my home region is Ashburn (USA)
I don't want to research it too much or pay extra for cross continent replication,
replicate volume across the USA is enough for my studying purposes
9. When applying terraform code in CH3FSDR folder, you need to apply it twice, as for the first time it will fail
with following message
Error: During creation, Terraform expected the resource to reach state(s): SUCCEEDED, but the service reported unexpected state: FAILED.
Not sure if it is my error or issue in OCI, but applying it for second time works fine.

