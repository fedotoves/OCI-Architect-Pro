There are two folders, CH2RealWorldArchitecture and CH2RealWorldArchitectureSecondRegion.
SecondRegion folder contains terraform code for objects that are necessary for creating replications
and similar things.
Code in first folder points to US Ashburn region (home region), code in second points to Frankfurt, Germany region
which is a backup one.
You can use any pair of regions that you like, just put correct values to config files.

This solution is not using "Always free" tier from OCI (may be refactored later)
and some resources and not free including domain name, security certs, OCI resources etc., 
so some expenses are required.

However, if you want to deploy the entire infrastructure at once, you need following manual steps
( after step one all others can be done in any order, just do them):
1. Create OCI account
2. Install terraform from hashicorp.com
3. Add your user to OCI_Administrators group
4. Fill variables file in the root of this chapter by your values, including generated ssh key
5. You need to manually upload WebServer image to Bucket (you need to create bucket manually) 
in your compartment. Get server image here https://intoracleeli.objectstorage.us-sanjose-1.oci.customer-oci.com/p/nu0zlVevzC6Z9nyZL2ZmC94b5Na_B1lX9XNuSrcchjw5mOyjs2WqqshliZSYwzQW/n/intoracleeli/b/ImageBucketSJ/o/WebServer2
6. Generate key for DB and paste public key to OCIArchitectCH2DBKey.key.pub
7. Get domain name (I got mine from GoDaddy)
8. Create security certificate (you can find my suggestion in comments if you search for "SSL Cert")
in networking/main.tf
9. Manually subscribe to second region besides your home region (mine is Germany Central - Frankfurt)
10. Check FastConnect and CrossConnect limits for your second region (Frankfurt in my case) 
and request limit increase for those resources. 2 of each should be enough.