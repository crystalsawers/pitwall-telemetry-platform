# The Art of Google Cloud (Part 3): Kubernetes, Continuous Integration and Deployment

*Project Timeframe: 9 May 2026 – 8 August 2026*

*Link to Part 3 post:* [Part 3](https://loglapandover.co.nz/projects/devops/8RA0vlrnQM9lmk8gUg8t)

**Link to previous posts**: 

_- [Part 1](https://loglapandover.co.nz/projects/devops/P9McSw1XKxtBUFpzdg4g)_

_- [Part 2](https://loglapandover.co.nz/projects/devops/rUzNh2L9nTWgyQQjpVf3)_

---

## Intro

In this third part of the project, the focus shifts from building and scaling the system to simulating a production-grade cloud environment.

At this stage, the system was still running on a **VM-based Docker Compose setup**, with observability and security layers already in place. The goal now is to gradually remove manual processes and introduce automation, deployment pipelines, and infrastructure reproducibility.

This is where the project transitions from cloud architecture into more operational engineering. It also delves into a common DevOps platform I've never really used before, Kubernetes. And you can definitely tell from this post that my understanding of it is very limited right now, and I don't fully understand how it all works. But at the same time, it's right out of my comfort zone, and I problem solve practically with loads of errors at hand, which is frustrating at times but it's how I tend to learn things normally.

---
## Dashboard Update

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780026963528-dash-update.png?alt=media&token=9017986b-6ba1-4b4a-98fa-7d1c73387a69)

<br>

After the Canadian Grand Prix I decided to tweak a couple of things after keeping an eye on this during the race weekend (at the time of the project, it was the Canadian Grand Prix). I fixed the race time on the session info panel, because it showed the wrong day initially. The Fastest Lap panels were a little bit messy right after the race, but that may be more the case of the OpenF1 API itself sorting its data out, as later in the week it had sorted itself out. But I'm not gonna spend too much time on the technical F1 data, this is more about testing various different Google Cloud features.

I've also noticed that there is a both a built-in monitoring feature and a logging feature for the VM itself, but in the context of my project, I wanted to actually monitor more the API data and the system of the services, rather than the actual Virtual Machine itself, so that's why I didn't really go too deep on it. 

---

## Phases of the Project

This project is broken down into several phases, documented as a blog series. This was initially going to be a 3-part series, but I have extended it to a 4 part series, potentially even 5 if I have time and credit left. So this is the **updated** phases of the project, ignore the one from the previous parts.

* **[Part 1](https://loglapandover.co.nz/projects/devops/P9McSw1XKxtBUFpzdg4g)** covers **Phase 1 and Phase 2**, focusing on the initial working system and core infrastructure setup.

  * **Phase 1 (Core system build):** Google Cloud Console (Compute Engine, VPC networking, firewall rules), Ubuntu Server, SSH, Docker, Docker Compose, FastAPI, PostgreSQL
  * **Phase 2 (Infrastructure automation):** Google Cloud Console + Cloud Shell, `gcloud` CLI, startup scripts, instance templates, Docker, Docker Compose, also getting some real F1 data to use.


* **[Part 2](https://loglapandover.co.nz/projects/devops/rUzNh2L9nTWgyQQjpVf3)** covers **Phase 3, Phase 4, and Phase 5**, focusing on managed services, observability, and security in Google Cloud.

  * **Phase 3 (Observability & monitoring):** Prometheus, Grafana, Loki, uptime checks, dashboards.
  * **Phase 4 (Security & access control):** IAM, VPC firewall policies, Secret Manager, service accounts
  * **Phase 5 (Managed application services – design & migration planning):** Understanding migration from VM-based Docker Compose to managed services, identifying stateless vs stateful components, preparing for Cloud Run readiness, and designing future Cloud SQL integration.


* **Part 3** covers **Phase 6, Phase 7, Phase 8, and Phase 9**, focusing on CI/CD automation, managed deployment, container orchestration, and infrastructure reliability foundations.

  * **Phase 6 (CI/CD Automation):** Cloud Build, GitHub integration, and automated container builds with **Google Artifact Registry as the central image store**
  * **Phase 7 (Managed Deployment):** Cloud Run and Cloud SQL for running containerised applications using images from Artifact Registry.
  * **Phase 8 (Container Orchestration): Kubernetes with GKE:** Introduction to Kubernetes using Google Kubernetes Engine, deploying containerised workloads as pods and services, scaling, rolling updates, and understanding cluster architecture
  * **Phase 9 (Infrastructure as Code & Reliability Foundations):** Terraform-based infrastructure provisioning for Cloud Run, Cloud SQL, and GKE, environment reproducibility (dev/staging/prod), plus monitoring, logging, health checks, and basic backup/restore strategies


* **Part 3** covers **Phase 6, Phase 7, and Phase 8**, focusing on CI/CD automation, managed deployment, and container orchestration.

  * **Phase 6 (CI/CD Automation):** Cloud Build, GitHub integration, and automated container builds with **Google Artifact Registry as the central image store**
  * **Phase 7 (Managed Deployment):** Cloud Run and Cloud SQL for running containerised applications using images from Artifact Registry.
  * **Phase 8 (Container Orchestration: Kubernetes with GKE):** Introduction to Kubernetes using Google Kubernetes Engine, deploying containerised workloads as pods and services, scaling, rolling updates, and understanding cluster architecture



* **Part 4** covers **Phase 9, Phase 10, and Phase 11**, focusing on independent experimentation with Google Cloud services outside of the main system.

  * **Phase 9 (AI Agent):** Experimental build of an AI agent to explore general capabilities such as natural language interaction, reasoning workflows, and tool use (not tied to any production system)
  * **Phase 10 (BigQuery Data Exploration):** Standalone experimentation with BigQuery for learning data querying, analytics workflows, and dataset handling using sample or test data
  * **Phase 11 (Google Cloud Experiments):** Exploration of additional Google Cloud APIs and tools such as Google Maps Platform and Agent Platform, used purely for testing and learning


* **Part 5** covers **Phase 12**, focusing on infrastructure as code and full environment reproducibility.

  * **Phase 12 (Infrastructure as Code, Using Terraform):** Terraform-based provisioning of GKE, Cloud Run, Cloud SQL, IAM, and networking to enable fully reproducible cloud environments


---

## Phase 6: CI/CD Automation (Cloud Build + Artifact Registry)

Phase 6 introduces a fully automated build pipeline and a centralised container image storage system using **Google Cloud Build and Artifact Registry**. This phase marks the transition from manually building and managing Docker images on a VM to a structured CI workflow where every code change produces a versioned, traceable container image.

A key shift in this phase is the introduction of **Artifact Registry as the single source of truth for container images**. Instead of relying on local Docker images or ad-hoc tagging on a single machine, all application builds are stored in a managed, cloud-hosted registry. This allows consistent versioning, secure storage, and seamless integration with future deployment services such as Cloud Run and Kubernetes.



### 6.1: Artifact Registry (Container Image Management Layer)

Artifact Registry is the foundation of the CI/CD pipeline in this phase. It provides a centralised location for storing, versioning, and managing Docker images for the system.

### Core components:

* Google Artifact Registry for Docker image storage
* Private container repositories per service
* Versioned image tagging using commit hashes
* Secure, IAM-controlled access to images
* Integration point between build and deployment stages

First of all, the Artifact Registry is not exactly the easiest feature to find without the search button, so just take that in mind. That being said, this part is important to do for future phases of this project. I need to actually register my Docker images and containers and use them with Kubernetes, the Cloud Build Pipeline, and Terraform. I will do this the manual way first, and it's quite easy to do this in a bash script, because there's equivalent gcloud commands to this too!

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780030705408-ARW-grant.png?alt=media&token=4a06988d-3724-4e4f-ad05-c5dee92a6778)

<br>

Firstly, I created the repository and mostly left the default settings. The important thing I needed to do to make this workis actually **grant some permissions to the Compute Service Account as an Artifact Registry Writer**, and then in the VM settings allow full access to all Cloud APIs (for now). Once I have done that, The one image I'm concerning in this part is the f1-telemetry-api image I created earlier on, so I used the docker tag and docker push commands to push them to the artifact registry repository I created. Then I wrote two scripts to automate this process, one that is run outside the VM either locally or in the Cloud Shell, and one that handles authenticating the API docker image into the registry. Both scripts are in the scripts folder in my repository.

Once both scripts have been verified to work, I would get this in my Artifact Registry console:

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780030705408-ARW-grant.png?alt=media&token=4a06988d-3724-4e4f-ad05-c5dee92a6778)

<br>

### 6.2: Cloud Build Pipeline

Cloud Build is responsible for automating the container build process whenever changes are pushed to the source repository.

### Core components:

* Cloud Build for automated Docker builds
* GitHub repository integration
* Build triggers based on branch commits
* `cloudbuild.yaml` pipeline definition
* Standardised build environment in Google Cloud



First off, I had a look at the Cloud Build Triggers page, and I created a separate GitHub repository for the [F1 telemetry app](https://github.com/crystalsawers/f1-telemetry-app) to connect to the trigger, and I'm **not** migrating the monitoring part of it, just the actual FastAPI part, then configure the CI/CD Pipeline from there.

When I did configure the build trigger, I had these following settings:

- **Name:** f1-telemetry-build
- **Region:** Global
- **Configuration:** I selected the **Cloud Build configuration file (yaml or json)** option, with the file (_cloudbuild.yaml_) location being in the root directory of the repo I connected it to.
- **Service Account:** I used the **compute service account** I added in earlier to add permissions to the Artifact Registry.

**Note:** I also had to add more permissions to the compute service account to add these roles, "Logs Writer", "Logs Viewer", "Logs View Accessor", as it kept coming up with a warning that it hadn't been permitted.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780036850217-cloud-builds.png?alt=media&token=258c17ff-cba4-419e-ae69-c8c34c6916fb)

<br>

I did have a failed build initially, but that was because I had to add a specific logging setting to the YAML file, which was this:

```yaml
options:
  logging: CLOUD_LOGGING_ONLY
```


<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780036859638-working-build.png?alt=media&token=aa6e6a62-0ace-45ec-aa84-58741cad16bc)

<br>

From there it was working, but I had to push again for the permissions to apply, and the logs appeared in the build summary.

---

## Phase 7: Deployment & Managed Services (Cloud Run + Cloud SQL)

Phase 7 introduces the deployment of containerised applications using **Google Cloud Run and Cloud SQL**. This phase transitions the system from build automation (Phase 6) into runtime infrastructure, where pre-built container images stored in **Artifact Registry** are deployed into managed production services.

A key principle in this phase is the separation between **build artifacts and runtime services**. Container images are built once in Cloud Build (Phase 6), stored in Artifact Registry, and then deployed to Cloud Run as immutable versions. Each deployment creates a new revision, allowing controlled updates, rollbacks, and versioned service management.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780111451441-7.1-cloud-sql.jpg?alt=media&token=3f78a3a0-c4dd-4bfd-bf53-1b0f8cee5ff1)

<br>

### 7.1: Cloud SQL (Managed Database Layer)

Cloud SQL replaces the self-managed PostgreSQL container with a fully managed relational database service. It provides persistence, backups, and maintenance without manual database administration.

### Core components:

* Managed PostgreSQL database service
* Automated backups and maintenance
* Secure connectivity from Cloud Run services
* Separation of stateless application and stateful database layers
* Production-grade persistence layer

I am setting up the database first because the FastAPI app requires a database connection to connect to in the python code. We are creating this so we can connect the database to our Cloud Run app in 7.2. I will be using the PostgreSQL option, specifically version 18, because it's already used in the app. For this task, both the **Compute Engine** and the **Cloud SQL Admin** APIs need to be enabled. I chose the Enterprise Plus option in this case while creating it, along with some other settings:

- It lets you generate a strong password for this instance, which I chose this option for added security.
- I chose the development preset for lower costs, and single zone availability.
- As for customising the machine, I left everything as it was set before I got to this, so really I didn't customise anything, but you could tweak things like storage, backups, Public/Private IP.

Now that the database is ready, I need to create a database and a user for the app's data to be put into an environment variable for the Cloud Run, the Database URL. I will call the database _"telemetry_db"_, and the user just "fastapi-postgres", with a strong password, using the built-in authentication. Next you need to retrieve the Public IP address from the Cloud SQL instance, the port number (5432). And that's pretty much it! All we need to do is to connect it to our app.

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780111642026-7.2-cloud-run.jpg?alt=media&token=7c3e2b23-f7c7-4b84-9f9d-720ea5bd1903)

<br>

### 7.2: Cloud Run Deployment Layer

Cloud Run is used to deploy and run containerised FastAPI services without managing underlying infrastructure. It consumes container images directly from Artifact Registry at deployment time and manages scaling, networking, and runtime execution.

### Core components:

* Serverless container deployment using Cloud Run
* Deployment of versioned images from Artifact Registry
* Automatic scaling based on request traffic
* Managed HTTPS endpoints for API services
* Revision-based deployment model (each deploy = new revision)

 
In the Cloud Run instance, I simply added the latest working container from the Artifact Registry, and was careful not to use one of the CI/CD builds at the moment (eventually I did try the CI/CD build version once the other one was working properly). Next I added the container port as 8000 (and not the default 8080), and then used the CloudSQL connections at the bottom to use the Database.

I came across into issues with the database from the Python code where it initialises the Database, that made the Cloud Run not deploy properly, so I ended up making another registry to push another version of the FastAPI docker image, just so I can isolate the problem and leave the other ones alone. Turns out the issue was because I had to add the Database URL in an environment variable as well as the connection.

Overall I got this working with the deployed URL, and in the `/docs` endpoint it tells me all the API endpoints, so that's pretty useful. It also works with my CI/CD pipeline once I fixed a bit of the python code to make it deploy to Cloud Run properly.



---

## Phase 8: Kubernetes 

Phase 8 introduces large-scale orchestration and full infrastructure automation using **Google Kubernetes Engine (GKE) and Terraform**. This phase transitions the system from managed application deployment into distributed workload orchestration and fully reproducible infrastructure provisioning.

A key shift in this phase is the move from single-service deployments in Cloud Run to **multi-service orchestration using Kubernetes**, alongside infrastructure defined entirely through code using Terraform.


### 8.1: Kubernetes (GKE) Concepts

Kubernetes is introduced as a container orchestration system for managing multiple services, scaling workloads, and coordinating deployments across a cluster.

This task is more about actually understanding how the basics of Kubernetes works, and understanding the basic terms. I found a great source online from KodeKloud, the [Kubernetes for Beginners PDF](https://kodekloud.com/wp-content/uploads/2020/11/Kubernetes-for-Beginners.pdf), to make sure I understand the basic concepts first. I'm one of those people that like to understand the concepts by actually doing the work and making mistakes first though, but this is quite an easy read, and it even has a brief explanation on Docker and containerisation too. This is a list of the basic components and terms to familiarise yourself with.

### Core components and terms:

* **Node:** A virtual or physical machine in which Kubernetes is installed.
* **Cluster:** A set of nodes grouped together.
* **Master:** A node that manages the cluster and responsible for the actual orchestration of containers on the worker nodes.
* **Kubelet:** An agent that runs on each node in the cluster.
* **Worker:** A node where the Docker containers are hosted in.
* **Node pool:** A group of nodes within a cluster that share the same configuration, machine type, and scaling rules.
* **Pod:** The smallest deployable unit in Kubernetes, representing one or more containers that share the same network namespace and storage.
* **Deployment:** A controller that manages and maintains a specified number of identical pod replicas, handling scaling and rolling updates.
* **Scaling:** Increasing or decreasing the number of running resources (e.g. pods) to handle changes in demand. This becomes increasingly important for managing costs to run the cluster in the cloud.
* **Replica:** A copy of a pod running in the cluster, used to ensure availability and handle load.
* **Service:** A stable network address that lets other parts of the system connect to a group of pods, automatically sending traffic to healthy ones even if the pods change or restart.
* **Namespace:** A logical partition within a cluster used to isolate and organise resources between different teams, environments, or applications.
* **Fleet:** A grouping of multiple Kubernetes clusters managed together as a single unit for centralized management and policy enforcement. You may see this during the Google Cloud cluster setup.



---

### 8.2: Cluster Configuration and Manual Setup

Kubernetes clusters are configured to balance simplicity, cost, and scalability before introducing full production complexity.

As we shift from the previous phase where we used Cloud Run and Cloud SQL to deploy everything, Kubernetes allows us to fully control the infrastructure to manage applications, in this case it has the FastAPI application, a PostgreSQL database storing our app's data, and a monitoring system with Prometheus in the backend, Loki for the data's logs, and Grafana for two separate dashboards, one is for F1 Telemetry Data from the API, the other is the F1 Telemetry System to monitor **how** the system brings in data in the first place.

### Core components:

* Standard mode cluster configuration for initial setup
* Autopilot mode for fully managed node provisioning
* Node pool configuration and resource allocation
* Zonal vs regional deployment considerations
* Reduced resource configurations for cost optimisation


I can easily say that this is by far the hardest phase of this project so far, and I ran into many issues with scaling and deployment. **Kubernetes is not for the impatient**. This took a few days to wrap my head around actually creating and deploying everything manually. To make the automation step easier, I also copied all the deployment's YAML files Google provide when creating the deployments as well.

For the creation of the cluster, I decided to use the Standard Mode, so I have more control over what's going on in my cluster, and it's the more cost effective option, as opposed to Autopilot Mode, which is more expensive to run, and Google has more control over the nodes, networking, security, and monitoring. 

As far as other settings go, a Zonal cluster is more cost-effective and it's better for learning and testing, as opposed to regional, which does have higher availability and more designed for production environments. I didn't register any fleets in this case. I did however downsize the default boot disk size from 100GB to about 30GB, and that also brings down the cost slightly too. I also left the machine type the default **e2-medium**, but there's an option to go a bit smaller to save even more coin, depending on how much you need in your project. In my case, I've got a few components of my project I need to set up, so I will most likely need some extra resources. I also had to enable the AutoScaler and change the maximum number of nodes to 6, because it wouldn't let me create the cluster without getting an error to enable it. I also found if you leave the maximum number to 3 you get scaling issues later on. Everything else like node pools (default of 3 nodes), basic networking and security features I just kept as default. I also quickly grabbed the "equivalent code" to create this later in automation.

Once the cluster was created, I needed to kubectl access from my Compute Engine VM so I could interact with and manage the Kubernetes cluster from the command line. As the Kubernetes cluster has essentially created 3 "nodes", meaning 3 VMs, I still had to register these nodes with my original Pitwall VM. This also meant I had to add another permission to grant my Compute service account to give access to Kubernetes, annoyingly for it to work. The role I needed to specifically add here was **Kubernetes Engine Developer**. I also had to download and install some plugin as it came up with some critical message, then has to get credentials for the f1-telemetry-cluster, and had to install kubectl to get the nodes form the cluster I created earlier.

The next step is to **deploy everything** to each pod. I will do the Database first, then the FastAPI, because the API depends on the database first. This was a pain in the ass to set up for an impatient person, because all the workloads intially comes up with errors when they first deploy, then it does eventually deploy and the status changes to OK. I kept the database for only insternal access via port 5432, and for FastAPI I exposed port 8000 for both the port and target port. I used the CI/CD built image from the Artifact Registry again. There's a cool feature for this endpoint called `/docs` as well, which shows the Swagger UI and you can test the data it gets from each endpoint.

I did the monitoring workloads too, Prometheus, Loki, and Promtail are backend based so they can only be interally accessed, while Grafana is the frontend display of monitoring data, so it's exposed externally using port 3000. After creating the three, I had to use kubectl on Cloud Shell to make sure they can communicate with each other in the cluster. As for the dashboards, because I didn't want to spend time perfecting all my panels manually, I just imported the JSON files with the dashboard settings in place. However, the Prometheus and Loki based panels didn't show any data initially, so I had to make some tweaks to the JSON file and then investigate kubectl to actually connect Prometheus and FastAPI with some config code when deploying with YAML.

The workloads dashboard in the Kubernetes Engine should look something like this (if you're following these posts as a tutorial):

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780361082036-kubernetes-workloads.png?alt=media&token=a1eab8ac-72df-4c6b-a842-40f756b357f1)

<br>

---

### 8.3: Automated Cluster Configuration and Setup

All scripts are Cloud Shell based, and written in Bash. These are the following scripts I used in order to achieve this initially:


* Script 1 (kubernetes-cluster): Create the Kubernetes cluster ( I called this f1-automated-cluster), and verify the nodes and pods.
* Script 2 (kubernetes-deployment): Deployment of ALL the workloads (assuming the YAMLs do not exist, so they get created too).
* Script 3 (kubernetes-config): Post deployment Issues get fixed in this script.
* Script 4 (kubernetes-cleanup): Delete all the workloads and cluster



This automation process is not going to be perfect, as I am still fairly new to Kubernetes and I don't fully understand it because I haven't worked on it enough. The way I am going to automate this is going to be bash scripting, again. Although I could use PowerShell for this too, I am a bit more comfortable in Bash, and I've gotten more used to the Cloud Shell, so the scripts I designed for this are only really for the Cloud Shell, as there are some plugins involved here that are already inside the Cloud Shell anyway. So I cannot guarantee they are going to work on your local computer's terminal, in fact they are unlikely to work without having to install some plugins first. 

The first part of the automation process is creating the cluster itself. When I did the manual setup I just copied the gcloud command it comes up with when you click the "Equivalent Code" part as you create the cluster. In the script itself I added some variables that can be changed depending on who is going to use it. Say if they want to create a cluster for a project that's completely different to mine, they can just change the value of the variable to their own project ID, the zone they live in, and the name of the cluster, since they're being used a lot in the flags of the command. This takes quite a few minutes to create, I've found. 

The second part is deploying workloads and extra configurations (ConfigMap) needed for the "services" that need to be run in the cluster. In my case, there are 2 data related workloads (PostgresDB and FastAPI), and 4 monitoring ones, from the manual setup earlier. I found with the manual setup I struggled with trying to add the extra config, including adding datasources for Grafana in the monitoring backend since some Grafana data was missing, and I had to tweak a few things on the dashboard JSON files to make sure they show up almost exactly as it did in the previous part. Originally I was going to just make a separate script for just importing the Grafana Dashboard files, but I had trouble to actually use them via their dashboard import API, so I ended up doing it in the deployment script instead, but the files get created before the config maps. This worked better, but I still encountered "No data" on most of my panels. This was a pain in the ass to problem solve too, as I figured out that my PostgreSQL database wasn't even set up properly during the deployment phase, so I couldn't even get my telemetry data stored into it to display on Grafana.

The third part is the post-deployment config issues script, where I need to add the services to make all this data display properly. For those asking why this isn't in the deployment script, the main reason is because I wanted to fix some issues where certain pods didn't work as they should despite the pods running, and I didn't want to redeploy anything unnecessarily when the majority of other services like FastAPI and Grafana were working completely fine. Plus some pods do take more time to get up and running than others, since there's also the Autopilot scaling that gives off temporary errors in the process. Eventually I did just add the services into the main Deployment YAML files in the deploy script. 

There was a security concern with the FastAPI deployment and the exposure of the Database URL, fully hardcoded with its full credentials including the username, password, the name of the database too. One way to get around this is using the **Secret Manager** tool, which is in the Security section. But I will admit, my solution of this isn't really the best one in terms of automation, but as far as security goes, it's the best way to **not expose sensitive data** into it. You can do this in either the actual Secret Manager console or use the Google Cloud CLI.

The CLI would look something like this, and it would be performed **before** the deployment script, and I wouldn't put this into its own script:

```bash
# 1. Create secrets (empty containers)
gcloud secrets create postgres-user --replication-policy="automatic"
gcloud secrets create postgres-password --replication-policy="automatic"
gcloud secrets create postgres-db --replication-policy="automatic"

# 2. Add secret values (create first version)
echo -n "your-user-name" | gcloud secrets versions add postgres-user --data-file=-
echo -n "your-secure-password" | gcloud secrets versions add postgres-password --data-file=-
echo -n "your-database-name" | gcloud secrets versions add postgres-db --data-file=-

# 3. Verify secrets exist
gcloud secrets list
gcloud secrets versions list postgres-password

# 4. Test access to a secret

gcloud secrets versions access latest --secret=postgres-user
gcloud secrets versions access latest --secret=postgres-password
gcloud secrets versions access latest --secret=postgres-db

```

and in the Deployment script, you would put this before creating the deployment file:

```bash
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_USER="$(gcloud secrets versions access latest --secret=postgres-user)" \
  --from-literal=POSTGRES_PASSWORD="$(gcloud secrets versions access latest --secret=postgres-password)" \
  --from-literal=POSTGRES_DB="$(gcloud secrets versions access latest --secret=postgres-db)" \
  --dry-run=client -o yaml | kubectl apply -f -

```
The deployment file would now have to direct it to the postgres workload as the database host inside the ConfigMap, then generate the database URL in deployment, instead of ConfigMap.

I also did the same thing for the Grafana Login process, just used the same gcloud commands from earlier to create the secret, then synced it to kubernetes:

```bash
kubectl create secret generic grafana-secret \
  --from-literal=GF_SECURITY_ADMIN_USER="$(gcloud secrets versions access latest --secret=grafana-admin-user)" \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD="$(gcloud secrets versions access latest --secret=grafana-admin-password)" \
  --dry-run=client -o yaml | kubectl apply -f -

```

Now I tried running the deployment script again, and everything seemed like it was up and running, but when I check the FastAPI not all the endpoints were working properly. Basically the `/telemetry` and `/metrics/telemetry` were not working properly from the get go, and that translated with "No data" in the grafana dashboard. So I had to investigate the logs from the FastAPI service to see what's going on. Turns out there was a password mismatch from my previous deployment, and the pods had too much memory being used up. Based on investigating the logs, it was something to do with the schema not initialising the database, and I had to create a Kubernetes "Job" in between the PostgreSQL and FastAPI deployments inside the script to make the endpoints work again. When I got that going, all the F1 Telemetry Data came back and displayed properly. In the System dashboard though I had issues with the Loki Logs, as they showed "no data", particularly with the errors. I was struggling to get data out of it for so long with every query and looking at the layout of the logs, going into the logs of the deployments themselves. So unfortunately, I had to remove the Loki and Promtail deployments that were previously working in the monitoring system with the VM. This was replaced by the **Google Cloud Logging**, so I had to switch to this with this automated deployment. But that didn't work either, so I ended up just giving up and removing the 2 logging panels on Grafana, and now relying on the Google Cloud Logs Explorer instead. It's better but there's false errors in them for the FastAPI app when it's just ingesting the data. But it's the only thing I can make work. I used the following query:

```
resource.type="k8s_container"
resource.labels.cluster_name="f1-automated-cluster"
resource.labels.namespace_name="default"
resource.labels.pod_name=~"fastapi-app.*"
```

<br>

![image](https://firebasestorage.googleapis.com/v0/b/crystal-personalblog.appspot.com/o/images%2F1780624978323-google-logs-explorer.png?alt=media&token=cb3bf3b7-0ccb-45b4-b0d6-50efd73b61d8)

<br>



Once everything was sorted and displaying properly, I ended up with 3 separate scripts to create, deploy and cleanup a Kubernetes cluster in an automated sense.

- **Script 1:** `create-cluster.sh`
- **Script 2:** `deploy-workloads.sh`
- **Script 3:** `cleanup.sh`

And that's the end of Part 3. Tune in for Part 4 where I step away from the full infrastructure and go into the more experimental tools in Google Cloud.