# **The Art of Google Cloud (Part 5): Infrastructure as Code with Terraform & Overall Project Reflection**

*Project Timeframe: 9 May 2026 – 20 July 2026 (Free Trial ended 8 August 2026)*

*Link to blog post:* [The Art of Google Cloud (Part 5)](https://loglapandover.co.nz/projects/devops/jKUVuRSplMJR537Fbju1)

*Links to Parts 1-4 of "The Art of Google Cloud": [Part 1](https://loglapandover.co.nz/projects/devops/P9McSw1XKxtBUFpzdg4g), [Part 2](https://loglapandover.co.nz/projects/devops/rUzNh2L9nTWgyQQjpVf3), [Part 3](https://loglapandover.co.nz/projects/devops/8RA0vlrnQM9lmk8gUg8t), [Part 4](https://loglapandover.co.nz/projects/devops/kA5uQMYizopqajwZhh2E)*


---

## Intro

In this final part of the project, the focus shifts from building and scaling the system and experiments of other cool Google Cloud tools, to simulating a production-grade cloud environment, only using a different infrastructure tool. I'm rebuilding my entire infrastructure from Parts 1-3 using a popular Infrastructure as Code tool called **Terraform**.


---
## What is Infrastructure as Code, and What is Terraform?

**Infrastructure as Code (IaC)** is the practice of defining and managing infrastructure through configuration files rather than manually clicking through a web console. Instead of creating virtual machines, networks, firewall rules, and storage services one at a time in the Google Cloud Console, these resources are described in code that can be version controlled, reviewed, shared, and deployed consistently.

**Terraform** is an open-source IaC tool developed by HashiCorp. It uses a declarative language called HashiCorp Configuration Language (HCL) where you describe the infrastructure you want, and Terraform figures out the steps to reach that state. This makes deployments repeatable, reduces manual configuration errors, and simplifies rebuilding environments from scratch. However, with all automated builds, you do need to at least have a solid understanding of how it works in the manual sense. Major things like knowing what a VPC actually does, why a subnet needs a CIDR range, how firewall rules allow or block traffic, understanding a way to not expose sensitive data for people to hack, and what IAM roles a service account needs to push an image or connect to a database. If you don't understand why Cloud Build was failing with permission denied or why a private GKE node can't reach the internet without Cloud NAT, the automation just hides problems and causes even more of a headache of problems for yourself and/or your team, rather than solving them. Terraform is used for making builds repeatable once you understand exactly what to build in the first place. 

Terraform works across multiple cloud providers beyond Google Cloud, including AWS, Azure, Kubernetes, GitHub, Datadog, and Cloudflare. It can manage DNS records, monitor dashboards, team permissions, CI/CD pipelines, and even third-party SaaS services, all from the same codebase. This means an entire project's infrastructure, from the cloud provider down to the application configuration, can be defined in one place and deployed with one command.

---

## Phase 13: **Terraform (Infrastructure as Code)**

This phase will be broken into a few different parts. I would highly recommend [this video](https://www.youtube.com/watch?v=Xni8GUcWQ_s) (officially from HashiCorp, which owns Terraform) if you're testing Terraform out with Google Cloud, as I partly followed this tutorial. All my Terraform code I used is located in the [Terraform folder in my repository](https://github.com/crystalsawers/pitwall-telemetry-platform/tree/main/terraform). 

List of things to create and deploy via Terraform:

- Custom VPC Network (to fit all of these features, rather than using the default network)
- Virtual Machine/Compute Engine
- Artifact Registry (Specifically for the custom-made Docker Image with the API)
- Cloud SQL
- Cloud Run 
- Kubernetes Cluster
- Kubernetes Deployment


### 13.1 - Initial Setup on CloudShell

I roughly followed this [GitHub documentation](https://github.com/hashicorp/terraform-getting-started-gcp-cloud-shell/blob/master/tutorial/cloudshell_tutorial.md) for this, which is from the official HashiCorp account.

Despite the documentation saying Terraform is installed in the CloudShell environment, I actually found that it wasn't on mine, so I followed the commands from this output from my `terraform version` command:

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install terraform
  bash

```

The version I was using at the time was this:

```
Terraform v1.15.8
on linux_amd64

```

Here's a table of Terraform commands that can be used here:

| Command | Description |
|---|---|
| `terraform version` | Displays the installed Terraform version. |
| `terraform init` | Initialises the Terraform working directory and downloads required providers. |
| `terraform validate` | Checks that Terraform configuration files are syntactically valid. |
| `terraform plan` | Shows the infrastructure changes Terraform will make before applying them. |
| `terraform apply` | Creates or updates infrastructure defined in Terraform configuration files. |
| `terraform destroy` | Deletes infrastructure managed by Terraform. |
| `terraform fmt` | Formats Terraform configuration files into standard formatting. |
| `terraform show` | Displays the current Terraform state and managed resources. |
| `terraform state list` | Lists resources currently tracked in the Terraform state file. |
| `terraform import` | Imports an existing cloud resource into Terraform state so it can be managed without recreating it. |


Now I'm going to create a specific Terraform folder inside the CloudShell and create a file called `main.tf` (you can also upload it if you wish), and include the following:

```terraform
# Specify the Terraform provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

# Configure the Google Cloud provider
provider "google" {
  project = "project-1f40dd62-739c-473a-b20"
  region  = "australia-southeast1"
  zone    = "australia-southeast1-a"
}
```
To activate the code above, run this command: `terraform init`.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783643298651-terraform-setup.png?alt=media&token=33d0e608-fe5a-4737-b3ea-5bfd66ec55c2)


<br>

When you initialise it, it creates a hidden folder and a lock file for the initialisation. That's why it's easier to isolate your Terraform config into its specific folder rather than have it all over the place on the main directory. 

When you use the command `terraform validate`, it should check if your configuration is valid. The one above is in my case, so we can move on to `terraform plan` to show what changes it will make before applying it to the infrastructure. You can save plans too using the -out=path flag and save it into a path file with saved plans (with either tfplan or something ending with .tfplan). The output said "No changes. Your infrastructure matches the configuration.". Now I can start adding things to this Terraform infrastructure.

### 13.2 - Build a Custom VPC Network

The next step was creating a custom VPC network to move away from using the default Google Cloud network, and isolate the project a bit more. This provides a dedicated environment where the Compute Engine VM, databases, containers, and Kubernetes resources can all communicate within the same network. I created a second Terraform file called `network.tf` to set up the network and the subnets, called "pitwall-vpc".

The `network.tf` file is what defines the foundation of the cloud networking architecture. The VPC is configured as a custom network with automatic subnet creation disabled, allowing full control over the IP ranges and network layout. A dedicated subnet is then created within the VPC to provide internal communication between resources deployed in the same environment.

While configuring the custom VPC firewall rules, access was restricted to only the services requiring external connectivity. Monitoring services such as Grafana required external access for dashboard viewing, while application, database, and observability components remained internal to the VPC to reduce unnecessary exposure.


This is what the VPC looks like when applied into action:

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783649558028-terraform-vpc.png?alt=media&token=3eff147c-ee98-49d2-8461-f8749461a3bb)

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783651487964-terraform-vpc-firewall.png?alt=media&token=5ad385ed-5641-44ce-9c81-b8f7a31af8fc)

<br>

One thing I will say, is that I've noticed that to get rid of the VPC and its firewall policies, I do have the slight annoyance of running the `terraform destroy` command twice, due to errors with the SSH and internal firewalls showing up the first time round. But it does eventually remove everything. 


### 13.3 - Create a VM (Compute Engine)

Now I'm going to create a separate file inside my Terraform folder called `compute.tf` to recreate my Pitwall VM in full. That includes using my old `install-stack.sh` copied inside my terraform folder (in a separate scripts directory) to setup all my Pitwall information as well. 

From there, you add in whatever VM config you need (if you're stuck, check out [this resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)) and go through the three steps to correctly build up your infrastructure. 

**Validate, Plan, Apply**. Use the three Terraform commands to make sure you're correctly building your infrastructure. Your messages should look something like this.

- **Validate:** Success! The configuration is valid.
- **Plan:** Should be something along the lines of 1 to add, 0 to change, etc. And a message that guilt trips you into saving your plan.
- **Apply:** It will prompt you if you want to perform these actions, so you enter a value saying "yes". Then it will come up with this message: _**Apply complete! Resources: 1 added, 0 changed, 0 destroyed.**_

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783646443399-teraform-compute-1.png?alt=media&token=be13ed88-24f8-4b2d-ae0b-13c0aae13f03)

<br>

Now let's have a look at the VM itself and connect to it. Going into the root user, we can see that the stack has already been applied, because when using the command `docker ps`, we can see the containers are up. 

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783647518084-terraform-compute-telemetry-1.png?alt=media&token=52b9d23a-98be-48f7-903d-6dcf056a7437)

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783647557249-terraform-compute-telemetry-2.png?alt=media&token=a751050e-c65d-428e-8aa2-5476c718492d)

<br>

Let's now go into the External IP it assigned itself, and port 3000 for Grafana. Looking at both Dashboards, they are successfully showing the correct and up to date data, all within just one Terraform script, no admin setups. Though I will say this, and this is an important part that I think a lot of people overlook when taking on this kind of task: understanding how your entire system and infrastructure work manually is **crucial** to automating it. You cannot effectively automate something you do not understand, and you really need to understand every single aspect of that infrastructure before trying to rebuild. IaC tools like Terraform make the process faster, more consistent, and repeatable, but they are only as good as your understanding of the infrastructure you are trying to recreate.



### 13.4 - Artifact Registry

Artifact Registry will be used as the central repository for storing and managing container images used by the application. Instead of storing Docker images locally or relying on unmanaged storage, Artifact Registry provides a secure and integrated location (a repository) where images can be pushed, versioned, and later deployed to services such as Cloud Run and Google Kubernetes Engine (GKE).

There's two parts to this, one is [creating the repository](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository), the other is pushing the existing FastAPI image from the VM, but the catch here is that you still have to **manually push the image** to the registry with Docker on the VM to that repository. I'm referencing this [documentation here](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/artifact_registry_docker_image), because this fetches information and checks what images are actually in the repository. But currently it's not in my code because there is a potential risk of breaking the other infrastructure if I don't manually push the image, especially since later on I do reference the docker image. 

I was originally going to put the creation of the repository into `compute.tf`, right on top of the VM creation. Then make another version of my stack script and edit the `install-stack-v2.sh`, to add the docker tag and push, just so it automatically does this as well as setting up your entire app. You could do a separate registry Terraform file, but you would run into problems with it unless you have a separate script inside the file to push the docker image (which is impossible to do). If you're running all the files at once when applying the infrastructure, it's not ideal to have to manually push an image right in the middle of it to make it work. I also had to enable yet another permission with this command: `gcloud services enable cloudresourcemanager.googleapis.com`, for the Terraform to apply the image in the registry. The problem here is that the image doesn't appear along with the repository even though it's created, so I had to go through with a slightly different solution using the CI/CD pipeline app I used in Phase 6 & 7. I'm just directly using the existing app this time and all its Docker build config, rather than just create a new app and new config for it, because this ends up getting too complicated and potentially running into the "manual admin" problem.

I created a new file called `build.tf` for building a new pipeline with this existing app. But first I had to of course, manually test the pipeline first to actually understand how to replicate it properly. I had to create an Artifact Registry repository for the image to be store into first before pushing anything. Then I navigated to my [F1 telemetry app](https://github.com/crystalsawers/f1-telemetry-app) repo to push the build that creates the cloud build trigger for you, make sure the Docker image is in the registry, and make sure the build passes. At first my build did fail, but that's because I had permission errors regarding the compute service account, so similar to what I had when I first set this up. With Terraform I had to make sure that permissions were being allowed along with creating the registry. I also had to import the existing cloud build trigger for this to work, rather than creating a new trigger. I'm really just activating the pipeline through Terraform this time rather than using just Github to push it manually, if that makes sense. The crucial part is to either import before planning and applying the build, or just delete everything and let Terraform create the repository and trigger, then go a quick git push to run a new build. The second option was easier and less complicated, and it worked. 



### 13.5 - Cloud SQL & Cloud Run

Cloud SQL will provide a managed relational database service for the application, replacing the need to manually maintain PostgreSQL on a Compute Engine VM. Alongside it, Cloud Run will host the containerized application, pulling the FastAPI image from Artifact Registry and connecting to Cloud SQL through environment variables. Terraform is used to provision both the SQL instance, database configuration, user accounts, and the Cloud Run service with its IAM bindings. 

With the image pipeline working, provisioning Cloud SQL and Cloud Run through Terraform was straightforward. I created a new file called `cloudrun.tf`, which handles all this. The Cloud Run service pulls the container image from Artifact Registry and connects to Cloud SQL via environment variables pointing to the instance connection name. A `roles/cloudsql.client` IAM binding lets the service account talk to the database. I'm also taking security into account regarding sensitive database credentials, with the Secret Manager, and in Terraform there is a resource to use the secret manager. One thing we will **not** do is hardcode any credentials in the Terraform file. Instead we have a `variables.tf` to define these variables, then export them as environment variables in the console **before** applying the added infrastructure. I would also recommend using the plan command beforehand to see which fields are using sensitive values. Also worth noting, when destroying the infrastructure, any sensitive values you put in as an enviornment variable will be the value you have to put when Teraform prompts you to enter it. It will be the first thing it prompts, then it will ask you whether to destroy the resources.

Example in console:

```bash
export TF_VAR_db_password="your-password"
export TF_VAR_db_username="your-username"
terraform plan
terraform apply
```

Really I wanted all this to work when all of the infrastructure is built at once, so I actually ended up destroying the infrastructure, cleaned up any cache, and re-uploaded all my terraform files to the console and re-applied them with the environment variables from there. This was a bit more simple for me, knowing that everything else was working anyway, and applying changes would be a rather unstable process of random errors due to things already existing. I acknowledge that this is not exactly the best technique for it, but it was the only way I can really guarantee a clean slate of applying everything at once. Note that the Cloud SQL database does take a few minutes to create, and Cloud Run needs a build to run on so I added the "null resources" feature to the file so that it can find the image to deploy the stack. 

Here's the final result of the Cloud SQL and Cloud Run instances (including the endpoint) based on the Terraform code.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783758478635-terraform-cloud-sql.png?alt=media&token=a73db633-aa6b-4467-8238-203b39476b3d)

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783758512798-terraform-cloud-run.png?alt=media&token=632d8bbd-51f0-4c0e-9658-e93adf6846af)

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783758546378-terraform-api.png?alt=media&token=ba1e4863-801a-48db-a453-ee0f5bf12e6a)

<br>


**Note:** If you get stuck on any errors to destroy the service here, try this command (or something similar in your own setup): `gcloud run services delete f1-telemetry-api --region=australia-southeast1 --quiet`. If it's firewall related, try `terraform destroy` again until you get the "Destroy Complete" message. 

---

### 13.6 - Kubernetes Cluster


![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1783833609047-terraform-cluster.png?alt=media&token=435b633f-8393-4b88-9086-78c8ba60b78d)

<br>

A Google Kubernetes Engine (GKE) cluster will be created to provide a container orchestration environment for deploying and managing workloads. This introduces Kubernetes-based management, allowing applications to be scaled, updated, and maintained using declarative configurations.

Terraform will manage the Kubernetes infrastructure, ensuring the cluster configuration is reproducible and version-controlled. This part only involves making the cluster itself, and we don't worry about deploying any apps into it until the next step. There is a `cluster.tf` file that handles all this.


**What does this cluster.tf file do?:**

* Creates a GKE cluster using Terraform.
* Configures cluster location and node settings.
* Configures networking with the custom VPC and subnets.
* Configures IAM permissions for cluster access.
* Connects `kubectl` to the cluster automatically, without needing some "manual admin" to set up the connection manually.

When applying the cluster to the infrastructure, you may notice that the cluster alone (not even getting to the node pools) takes at least 10 minutes to create (and also about 5 minutes to destroy it). That's unfortunately the normal process when you have a fair bit of resources to put into the cluster, as I've learned in this project. The screenshot above gives the details of the cluster made via Terraform. 

---

### 13.7 - Kubernetes Deployment

The Kubernetes deployment part of this defines how the application runs inside the GKE cluster. Instead of manually creating containers, Kubernetes manifests will describe the desired state of the application, including replicas, container images, networking, and resource requirements.

This allows the application environment to be recreated consistently and managed through configuration files.

**What does (or at least should) it do?:**

* Create Kubernetes deployment manifests/workloads.
* Configure container image references from Artifact Registry.
* Define replicas and resource limits.
* Create Kubernetes Services for application access.
* Deploy the application to GKE.

Let's remind you, the reader who's unlikely to remember what I actually deployed, what I actually deployed into the cluster the first time round. 

- **PostgreSQL database**, with only internal access for Port 5432
- **FastAPI**, Expose Port 8000 for both port and target port
- **Prometheus**, internal access only
- **Grafana**, expose port 3000

For the Terraform phase of this big task, I just re-used the dashboard JSON files from the Kubernetes step and put it into the Terraform folder where I'm building all this. I also had to take note of all the other config like Prometheus config, datasources, etc. The only major difference between ,making the deployments manually and deploying via Terraform is that the database in this case is only using the existing CloudSQL, I'm **not** creating a new deployment for the database in Terraform. 

I did struggle a little bit with getting the Grafana login to work correctly initially, because I had set a stronger password than the default password of "admin". It turns out I had somehow managed to double encode the credentials, and that's why I couldn't get to login with the default password at one point either.

Once I eventually got this working, I went to the Grafana deployment and retrieved the Public IP with the port and it comes up with the dashboards. However, I had an issue with some of the data showing, specifically the FastAPI data, but I made the mistake of forgetting to use the "LoadBalancer" option when exposing the port to get the data. But I also had issues with most of the crucial endpoints even when exposing that port properly. It turns out the experiment of trying a smaller image didn't work, so I went back to the **e2-medium** image from the other Kubernetes task so that the endpoints could actually get data properly. But that wasn't the root cause of the endpoint retrieval, it turns out I needed to add some kind of NAT routing for the nodes to actually reach the internet itself, so it can actually retrieve the API URL itself. That was why I couldn't get any data to load. The visual results are basically the same as the VM one, except the logs are not in the cluster, because I couldn't even get that working the first time round, and I re-used the dashboard JSON files from the cluster phase too. 

There was one last thing I did with the Terraform phase, and that was to destroy everything, clear the cache, re-upload the Terraform files with the correct code, initialise Terraform on it, validate the configuration syntax, plan what this is all going to do, then apply the whole thing into one. Overall this took about 10 minutes, but most of that was the Kubernetes cluster just taking forever to fully provision properly. 

---
## What did I learn in this whole Google Cloud Experience?

The Google Cloud Free Trial brings in a great opportunity into how you build a basic DevOps infrastructure. The free trial credits dictate what resources you can run and for how long. Features like Cloud Source Repositories aren't available to new accounts, which forced sticking with GitHub triggers. Some APIs need manual enabling through the console when your account lacks Service Usage Admin permissions, even if you have the "Owner" role on the project. There's also limitations to using only Google-owned AI models when using the Agent Platform, you have to pay money to use the Partner models like Claude, Deepseek, Grok, etc. 

Service accounts and IAM are really the backbone of everything. Cloud Build, Cloud Run, GKE nodes, and Cloud SQL all need explicit permissions to talk to each other. Guessing which account does what just doesn't work. You have to check the actual service account being used, find its exact email, and bind the specific role to the specific resource. For example, the Cloud Build trigger using the Compute Engine default service account instead of the Cloud Build one cost hours of debugging.

Managed services save time but don't exactly hide complexity. Cloud SQL handles most backups, but you still need to configure networking, users, and connection methods. GKE manages the control plane, but you still need to size node pools, set resource limits, and understand how pods communicate. The managed part handles maintenance, not architecture. Private GKE nodes need Cloud NAT to reach external APIs, and Cloud SQL needs a proxy sidecar when pods can't use public IPs.

Observability needs to be built in from the start. Prometheus scraping FastAPI metrics and Grafana dashboards pulling from both Prometheus and the REST API gave visibility into everything: session data, lap times, driver standings, API health, request rates, ingestion cycles, and response times. Without that, debugging the ingestion timeout or the database connection issues would have been blind. Fixed dashboard JSON files meant not starting from scratch every deploy.

AI tools can accelerate the learning curve but require verification. This goes from building an agent to vibe-coding a basic counter app to see if it can execute basic code. Creating AI slop for images, video, audio, and music, even though it's against my moral code to do so, helped me understand the eye-opening dangers of how easily accessible it is for a regular person to create all this media, and gaining some understanding in what's real and what's not when it's becoming more difficult to do so. Plus it gave me more insight on the music front too, seeing as it can't seem to prompt a song from music theory terms, but rather a concept of the song and the genre it's set to.  

Using an AI assistant was somewhat helpful to generate some Terraform code, debug errors, and explain cloud concepts made it possible to build this infrastructure without prior GCP experience. But the AI also suggested deprecated APIs like Cloud Source Repositories, hallucinated resource attributes that don't exist, and occasionally proposed solutions that didn't match the actual cloud state. Every suggestion had to be tested against the real environment. The skill isn't just prompting, it's knowing when the output is wrong.

Portability is real handy when you use open-source tools that are commonly used in the DevOps world. Terraform, Kubernetes, Prometheus, Grafana, and PostgreSQL all work the same way on Google Cloud, AWS, or Azure, therefore it's easier to adapt depending on which cloud platform you use. The provider syntax changes, the resource names change, but the architecture and the debugging approach carry over.

Terraform ties it all together into one codebase, but it's not magic. It will happily create resources in the wrong order, apply IAM bindings to repositories that don't exist yet, and fail silently if a service account doesn't have the permissions it needs. Learning to read Terraform errors, trace them back to actual cloud resources, and fix the underlying issue rather than the syntax was the biggest skill gain. Importing existing resources into state, dealing with state locks, and managing sensitive variables taught me that state management is half the battle with IaC.

---
## For My Personal Future Development

- *How did I solve the problems faced to help understand my work?*

Every failure surfaced a gap in my understanding. When Cloud Build couldn't push to Artifact Registry, I learned the service account hierarchy. When the private GKE nodes couldn't reach the internet and I couldn't access my FastAPI endpoints, I learned how Cloud NAT works. When Grafana kept crashing, I learned how to initialise and use plugins and how Kubernetes probes affect startup. Each problem forced me to read logs, trace dependencies, and understand the resource properly before automating it.

Overall, this project has trained me to treat every failure as a diagnostic signal, not a setback. I developed a systematic approach to the failures: trace the request path end to end, isolate the failing component, read the logs until the root cause is identified, fix it, and only then do I automate the solution when it works properly in the manual sense. That discipline, of refusing to paper over a problem I don't fully understand, is something I now bring to any infrastructure I touch, in fact this mindset is ideal for any IT field I could end up in. In a production environment, that's the difference between a quick patch and a reliable fix.

<br>

- *What transferable skills from this project apply to Cloud and DevOps roles, and how would they adapt to AWS or Azure?*

Infrastructure as Code with Terraform, container orchestration with Kubernetes, CI/CD pipelines with Cloud Build, managed databases with Cloud SQL, observability with Prometheus and Grafana, secret management, VPC networking, IAM, and debugging distributed systems. The concepts are the same across any cloud. The architecture stays identical: managed Kubernetes (EKS on AWS, AKS on Azure), managed Postgres (RDS, Azure Database), container registry (ECR, ACR), secrets manager (Secrets Manager, Key Vault), and the same observability stack. The Terraform provider changes, the resource names differ, but the patterns don't.

<br>

- *How would I explain the infrastructure decisions I made in a job interview?*

For the Terraform automation, I chose Cloud SQL over running Postgres as a separate deployment in the cluster because managed databases handle backups and failover. I used Cloud Run for simpler workloads and GKE where I needed Prometheus and Grafana side by side with the app. I used private nodes for security and Cloud NAT for egress. I'm also considering the security of the infrastructure because if I'm working in a big company, I would **not** want sensitive data being hacked and then leaked everywhere, that's an invasion of privacy. I used Secret Manager for this so no credentials sit in code or config files, because that can be easy access for a hacker to get into. 