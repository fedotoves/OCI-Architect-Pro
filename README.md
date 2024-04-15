# OCI-Architect-Pro
This is terraform code that tries to implement manual steps
for lectures given in OCI architect course for Exam 1Z0-997-23:
Oracle Cloud Infrastructure 2023 Architect Professional wherever possible.

Course is located here: https://mylearn.oracle.com/ou/course/oracle-cloud-infrastructure-architect-professional/122659/
My process is to follow the course step by step, adding resources and instructions as necessary.

Please note that this is my own effort,  and is not a part of official documentation or guidance, so use it at your own risk.
I highly encourage you to read readme file for every folder as there are several manual steps
that cannot be automated.
Also, read comments in .tf files before executing them. I'm trying to explain my calculations,
and show my progress step by step along with explaining unexpected discrepancies between videos,
docs and real executable terraform code.

Pay attention to variables.tf files for every 'root' folder that has main.tf file,
those variables.tf MUST have your valid information to be able to connect to OCI.
I will leave some sample values there to show how values should look like.

I often use 'terraform destroy' command when studying.  
Sometimes it can give you error messages and may require manual intervention.
It is too complicated to make it work seamlessly for studying purposes,
so I need to delete one or two things manually to finish the process.

The idea of my project is to have a working solution so you can just run using 'terraform apply'
but, again, some manual steps are required as stated in readme.md files in every chapter.

I'm currently going through this course, so it is my work in progress.
I will be adding code for chapters over time, 
however I cannot guarantee deadlines or promise anything
as I'm doing it on my own free time.

Feel free to ask questions, post comments and suggestions; 
any fact-based feedback is highly appreciated and welcomed.