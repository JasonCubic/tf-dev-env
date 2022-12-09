# Azure Dev Environment Using Terraform

[Learn Terraform with Azure by Building a Dev Environment]Any missing videos (Like the VM setup) can currently be found here: <https://courses.morethancertified.com/p/rfp-terraform-azure>

To get logged in Azure account info: `az account show`

Terraform commands

- terraform version - see the version info
- terraform fmt - formate the .tf files in the folder
- terraform init - populates the .terraform dependency folder and build the lock file .terraform.lock.hcl
- terraform plan - shows what is going to be changed when an apply is done
- terraform apply - makes the changes in the plan and generates terraform.tfstate
- terraform apply -auto-approve - same as apply with no confirmation
- terraform state list - an easy way to list all of the resources we have
- terraform state show <`one of the resources`> - view just one of the specific resources
- terraform apply -destroy - removes everything that is in the terraform files
- terraform plan -destroy - preview what is going to be destroyed
- terraform apply -replace <`one of the resources`> - will destroy and re-apply the resource
- terraform apply -refresh-only -auto-approve - does not change anything but updates the terraform.tfstate (useful when adding data-sources or outputs)
- terraform output - gets the outputs from the terraform.tfstate file
- terraform output <`one of the outputs`> - gets the output from the terraform.tfstate file
- terraform console - provides an interactive console for evaluating expressions
- terraform console -var="host_os=linux" - how to define variables on the command line
- terraform console -var-file="osx.tfvars" - how to define variables in a specific tfvars file

The general syntax for terraform:

```terraform
resource "<PROVIDER>_<TYPE>" "<NAME>" {
  [CONFIG ...]
}
```

- PROVIDER is the name of a provider (e.g., aws),
- TYPE is the type of resource to create in that provider (e.g., instance),
- NAME is an identifier you can use throughout the Terraform code to refer to this resource (e.g., my_instance), and
- CONFIG consists of one or more arguments that are specific to that resource.

---

To get a graph.svg of the terraform plan

- Note: requires [Graphviz](https://graphviz.org/) to be installed

<https://developer.hashicorp.com/terraform/cli/commands/graph>

```bash
terraform graph | dot -Tsvg > graph.svg
```

---

VM prices by size https://azureprice.net/?sortField=linuxPrice&sortOrder=true

to list all locations: `az account list-locations --query "sort_by([].{DisplayName:displayName, Name:name}, &Name)" --output table`

To check if a vm size is in a location

```bash
az vm list-skus --location westus2 --size Standard_A --all --output table
az vm list-skus --location westus2 --resource-type virtualMachines --zone --all --output table
az vm list-skus --size Standard_B1s --all --output table
az vm list-skus --location eastus --size Standard_B1s --all --output table
```

---

## how the ssh keypair was made

1. `ssh-keygen -t rsa`
2. save to `C:\Users\jacubic\.ssh\mtcazurekey`
3. skipped passphrase
4. to verify the files `mtcazurekey` and `mtcazurekey.pub` were created, run: `ls -al ~/.ssh`

---

## ssh into the linux box running in Azure

get the public IP address from the vm

1. get the list of state items: `terraform state list`
2. show the VM details: `terraform state show azurerm_linux_virtual_machine.mtc-vm`
3. find the public IP address
4. ssh into it (replace the IP with the real IP): `ssh -i ~/.ssh/mtcazurekey adminuser@123.123.123.123`
5. get the release info `cat /etc/*release` or `lsb_release -a`

---

https://developer.hashicorp.com/terraform/language/data-sources
