# Terraform Setup commands

## Apply infrastructure

Upload the Terraform folder into the Cloud Shell, then use following commands to build your infrastructure:

```bash
cd terraform
terraform validate
terraform init
export TF_VAR_db_username="your-db-username"
export TF_VAR_db_password="your-db-password"
export TF_VAR_grafana_password="your-grafana-password"
terraform plan
terraform apply
``` 

Type 'yes' for the prompt when applying.

**Note:** If you don't explicitly state the variables, It will prompt you to enter the database and Grafana credentials (password and username) first and a value for your consent to apply it. Simply just type in the credentials you had for the database and then type 'yes'. That's why I suggest you use the export commands. 

**Alternative** command for inserting environment variables (and likely the better method): `terraform plan -var 'TF_VAR_db_username="your-db-username"' -var 'TF_VAR_db_password="your-db-password"' -var 'your-grafana-password"'`

**Alternative method #2:** create a file called `terraform.tfvars`, and apply your variables like this:

```
db_password      = "your-password"
db_username      = "your-username"
grafana_password = "your-grafana-password"
```
It automatically loads the variables when running `terraform plan` or `terraform apply`.


---

## Get rid of the infrastructure

If you want to get rid of the entire infrastructure and remove the files, follow these steps.

```bash
gcloud run services delete f1-telemetry-api --region=australia-southeast1 --quiet
terraform destroy
terraform destroy # again if not everything got deleted the first time
terraform state list
terraform state rm <state-name> # there's unlikely to be one but only do this if there is.
cd ..
rm -rf terraform
```

**Note:** It may or may not prompt you to enter the database and Grafana credentials (password and username) first and a value for your consent to destroy it. Simply just type in the credentials you had for the database and type 'yes'.


---

## Troubleshooting Notes:

- If you get this error:

```
╷
│ Error: cannot destroy service without setting deletion_protection=false and running `terraform apply`
│ 
│ 
╵
```

This command will get rid of it: `gcloud run services delete f1-telemetry-api --region=australia-southeast1 --quiet`

- If you get this error:

```
╷
│ Error: Error when reading or editing Firewall: Delete "https://compute.googleapis.com/compute/v1/projects/project-1f40dd62-739c-473a-b20/global/firewalls/allow-https?alt=json": dial tcp 172.217.194.95:443: connect: connection refused
│ 
│ 
╵
```

Try `terraform destroy` again. Maybe even try another time if the firewall error seems really stubborn.