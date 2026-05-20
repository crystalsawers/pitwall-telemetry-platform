# The Art of Google Cloud (Part 2): Monitoring, Security, and Managed Cloud Services

*Project Timeframe: 9 May 2026 – present (trial ends 8 August 2026)*

*Link to this post:* [Part 2](https://loglapandover.co.nz/projects/devops/rUzNh2L9nTWgyQQjpVf3)

---

## Intro

This second part of the project focuses on improving the platform through observability, security, and managed Google Cloud services.

In Part 1, the system was deployed onto a Compute Engine VM using Docker, FastAPI, and PostgreSQL, alongside infrastructure automation using the `gcloud` CLI and startup scripts. Part 3 extends on this by adding more containers for monitoring and visualising the data. This also involves some more scripting and automation on top of this too, including a mega script that can fully set up this environment of the F1 Telemetry Dashboards. This post also covers learning a little bit more on the security and networking side of Google Cloud, and migrating the data to be used in some special APIs.

You may notice I have changed my plans around a bit for the phases here. I found that Kubernetes involved a lot of admin you need to do around the Artifact Registry first before you deploy your apps to it, so I ended up moving that to phase 7 instead, so it will be in Part 3. Rather than immediately moving into Kubernetes, this stage focuses on strengthening the existing architecture using monitoring stacks, access control systems, managed services, and cloud-native operational tooling.

---
## Phases of the Project

This project is broken down into several phases, documented as a blog series. This was initially going to be a 3-part series, but I have extended it to a 4 part series, potentially even 5 if I have time and credit left. So this is the **updated** phases of the project, ignore the one from the Part 1 post.

* **[Part 1](https://loglapandover.co.nz/projects/devops/P9McSw1XKxtBUFpzdg4g)** covers **Phase 1 and Phase 2**, focusing on the initial working system and core infrastructure setup.

  * **Phase 1 (Core system build):** Google Cloud Console (Compute Engine, VPC networking, firewall rules), Ubuntu Server, SSH, Docker, Docker Compose, FastAPI, PostgreSQL
  * **Phase 2 (Infrastructure automation):** Google Cloud Console + Cloud Shell, `gcloud` CLI, startup scripts, instance templates, Docker, Docker Compose, also getting some real F1 data to use.

* **Part 2** covers **Phase 3, Phase 4, and Phase 5**, focusing on managed services, observability, and security in Google Cloud.

  * **Phase 3 (Observability & monitoring):** Prometheus, Grafana, Loki, uptime checks, dashboards.
  * **Phase 4 (Security & access control):** IAM, VPC firewall policies, Secret Manager, service accounts
  * **Phase 5 (Managed application services – design & migration planning):** Understanding migration from VM-based Docker Compose to managed services, identifying stateless vs stateful components, preparing for Cloud Run readiness, and designing future Cloud SQL integration.

* **Part 3** covers **Phase 6, Phase 7, and Phase 8**, focusing on orchestration, automation, and production infrastructure.

  * **Phase 6 (CI/CD automation):** Cloud Build, GitHub integration, automated container builds and deployments
  * **Phase 7 (Container orchestration & managed deployment):** Artifact Registry, Cloud Run, Cloud SQL, Kubernetes deployments and scaling
  * **Phase 8 (Infrastructure as Code):** Terraform, reusable infrastructure provisioning, automated environment setup

* **Part 4** covers **Phase 9 and Phase 10**, focusing on production reliability, advanced security, and operational engineering.

  * **Phase 9 (Reliability engineering & high availability):** Load balancing, rolling updates, autoscaling, health checks, self-healing services, backup and restore testing, disaster recovery simulations
  * **Phase 10 (Advanced security & DevSecOps):** Container vulnerability scanning, Kubernetes RBAC, Binary Authorization, Workload Identity, network policies, private clusters, CI/CD security scanning, secret rotation

* **Part 5** covers **Phase 11 and beyond**, focusing on cloud-native architecture, event-driven systems, and data engineering.

  * **Phase 11 (Event-driven telemetry systems):** Pub/Sub, Cloud Functions, asynchronous processing, telemetry ingestion pipelines, queue workers, real-time event processing
  * **Phase 12 (Data analytics & telemetry platforms):** BigQuery, telemetry warehousing, scheduled ETL pipelines, analytics dashboards, historical performance analysis
  * **Phase 13 (Site Reliability Engineering & operations):** Alerting systems, SLIs/SLOs, incident response workflows, synthetic monitoring, chaos engineering, operational runbooks



---

## Phase 3: Observability & Monitoring

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/loki-logs.png)

<br>

Phase 3 introduces a dedicated observability stack using the following tools:

* **Prometheus** for metrics collection
* **Grafana** for dashboards and visualisation
* **Loki** for centralised log aggregation

A lot of this task was involving the scripting and automation part anyway, but I didn't start off fully automated. I made sure certain features were working properly first **manually** before fully refining the script with the full dashboard and get all the data working properly beforehand. Another major thing was what kind of data should be monitored with Prometheus and displayed in Grafana. With both Prometheus and Grafana I had to enable some ports in the firewall to make sure I can use it in the browser using the **external IP address Google Cloud gives you** when the VM is created. I also ended up making a few tweaks into the python code so I can get the data I actually want displayed properly. Grafana was a process of just playing around with how things are displayed, and that took a few days to figure it all out. 

<br>

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/f1-data-dashboard-1.png)

<br>
The dashboard part itself was split into two dashboards, one for the actual F1 data, the other for the overall system of the telemetry. For both dashboards, I split multiple sections so the most important information could be seen immediately at the top. I'll go through the **F1 Telemetry Data** dashboard first. The first section focused on quick overview statistics, including the current session information (which at the time of setup, the last race that took place was the Miami Grand Prix), the name of the driver with the fastest lap along with their lap time using the clock (s) unit format (it was the closest I could get to the real F1 style timing format), and the fastest team based on average lap time. Though the API endpoint does calculate it for all of the teams, this chooses the quickest one. These panels mainly used Prometheus metrics and Grafana stat panels to display "live" telemetry values in a simple format. Because the OpenF1 API requires a subscription for actual live data, I persisted with the latest information from the race. 

The middle section focused more on comparative data visualisation. This included team average lap times (in seconds this time, so it would display something like 98.5 seconds) displayed using bar gauges and gauges for the overall average lap time (in the clock (s) format). A lot of experimentation went into deciding which Grafana panel types actually made sense for motorsport telemetry data, since some visualisations looked good visually but were difficult to read properly in practice. But at the same time I wanted a bit of variety in the dashboard, because it's going to look boring with the same panel types.

<br>

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/f1-data-dashboard-2.png)

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/f1-data-dashboard-3.png)


<br>

The bottom section focused on structured table data pulled directly from the FastAPI endpoints using the Infinity datasource plugin. This included the live race leaderboard, driver championship standings, and constructor championship standings. These tables required a lot more manual formatting work than expected, including renaming fields, reorganising columns, adjusting widths, and making sure the API responses matched the layout Grafana expected. The race leaderboard was its own row, and it's not perfect, as it doesn't account for post-race penalty positions (e.g. Charles Leclerc finished P8 with his penalty in Miami, but the leaderboard says he finished P6, not quite accurate). It includes the position, driver's name and number, the team they drive for, the lap time in seconds (as in 93.5 seconds), and Lap Number (how many laps they did). It also doesn't account for whether they didn't fully finish the race either, or even start, so that could be a future improvement, but really this is a project to experiment with Google Cloud itself, not so much the content of monitoring. Lastly, there's two tables of the Drivers and Constructors Championships, which I discovered they have their own endpoints in beta for the API. There's more accuracy in those two tables here.

<br>

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/f1-system-dashboard-1.png)

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/f1-system-dashboard-2.png)


<br>

Now to the **F1 Telemetry System** dashboard. Unlike the F1 Telemetry Data dashboard, this one was designed more around infrastructure monitoring and system health rather than race data itself, but it does include the total drivers tracked here. The goal here was to monitor the actual cloud environment running the platform, including container performance, VM resource usage, logs, and API availability.

This dashboard included panels for the FastAPI Status, API Uptime, Prometheus Metrics Health, API Request Rate and failed requests, Logs from Loki, data ingestion, OpenF1 API response time, and tracked drivers from OpenF1 collected through Prometheus exporters. Compared to the data dashboard, this setup relied more on standard infrastructure metrics rather than heavily customised telemetry queries.

A large part of building this dashboard involved deciding what information was actually useful to monitor in a smaller cloud environment. Some metrics looked impressive visually but did not provide much practical value, while others became important during troubleshooting and script testing. This dashboard became especially useful while refining the deployment automation scripts, since it made it easier to quickly identify failed services, broken exporters, or resource issues after redeployments. This was also the time to tweak the Python app code for any endpoint errors and what kind of data it's displaying via Prometheus and Loki.

The overall manual setup process itself involved repeatedly testing Prometheus queries, checking labels, modifying Grafana transformations, and refining the exported dashboard JSON files until the automated deployment process could reliably recreate the full dashboard without additional manual fixes.


### 3.1: Scripting and Automation Add-On

Now to the scripting and automation part of the phase, it look a bit longer than expected, due to the compatibility of the grafana JSON files. Initially I actually made this a separate script called **monitoring_stack.sh**, because it's actually cleaner way to do it intitially, so that I know what I'm doing and I can solve problems from a specific part of the project, in this case the "monitoring" stage is what I was currently working on, after the FastAPI apps and database were working properly, and it's easier to isolate the problem too. The script itself was creating the required directories and configuration files for Prometheus, Grafana, Loki, provisioning, dashboard JSON exports, and Docker Compose, automatically populating those files (that took up **a lot** of lines in the script) with the required content before finally deploying the full monitoring stack containers through Docker Compose. Now I used this script in a **separate VM**, because I just didn't want to ruin the good copy I had in the other VM where I did all the manual process.

With Grafana in particular you can actually display the equivalent json code for the entire dashboard directly from the dashboard editor using the "Export" button, so that makes it much easier to be able to automate it, just copy and paste the JSON code. However, I did find with the provisioning from the script that it only works with Classic JSON (at least at the moment), and I had to be careful with the UIDs of both the dashboard ID and the datasource ID, so I had to sort out the configuration in the datasources file to just have the likes of "prom-main", "loki-main", and "infinity-main", because it kept showing no data with the json code I stole for the manual dashboard. When I eventually got this working, it showed data on all but two panels, so i had to figure out what was causing this. Turns out I had to get rid of the transformations array inside the JSON file within both the panel objects, so it can display the data exactly how it did earlier. 

Eventually when everything was working in all aspects, I combined all the scripts (the basic setup, creating the data containers, and the monitoring stack) into **one mega script** so that everything can automatically be setup with the actual VM. I actually just created another VM via the Cloud Shell script first, then uploaded the mega script to the VM (connected via SSH), and everything worked a charm, and everything was properly set up.

---

## Phase 4: Security & Access Control

This phase is more about learning the production-style security practices across identity management, networking, and secret storage. Overall it's not so much adding things to it, it's more about demonstrating my understanding of these tools.


### 4.1: IAM (Identity and Access Management)

**IAM** is used to control access across the Google Cloud environment. 

This includes:

* Defining role-based permissions
* Restricting administrative access
* Applying least-privilege principles
* Managing service account permissions between services

This helps reduce unnecessary access and improves overall platform security. In the console it comes up with my email account. In there there are a few roles listed already. 

- Organization Administrator
- Owner
- Project Mover
- Service Usage Admin

<br>

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/iam-roles-1.png)

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/iam-roles-1.png)


<br>

When I check the box that says "Include Google-provided role grants", I see my service account number (I've hidden mine for security purposes) along with all the APIs that I've enabled so far.

The following role grants are provided by Google:

- Instance Group Manager Service Agent
- Compute Engine Service Agent
- Kubernetes Engine Service Agent (I'm not up to Kubernetes yet, but the API was enabled)
- Kubernetes Engine Default Node Service Agent
- Network Connectivity Service Agent
- Artifact Registry Service Agent
- Container Registry Service Agent
- Cloud Pub/Sub Service Agent

All of them apart from the owner role have the "Advanced Security Insight". There will likely be more role grants added as I go through more of the project. 


### 4.2: Secret Manager

Sensitive values are moved into **Google Secret Manager** instead of remaining inside repositories or environment files.

This includes:

* Database credentials
* API keys
* Service configuration values
* Environment-specific secrets

Applications can retrieve secrets securely at runtime, improving both operational management and security practices.

First of all, it's found deep into the "Security" section of the console, and I enabled the API for it. A short clip is on my blog post link of creating a "test" password as an example, which I **promptly deleted** after. This was just a tester for when doing the actual thing with the environment variables later in the phase.


### 4.3: VPC Firewall Policies

Network-level security is enforced through VPC firewall rules and policies.

This includes:

* Restricting inbound traffic
* Limiting unnecessary public exposure
* Controlling which ports and protocols are accessible
* Isolating services where required

This reduces the attack surface of the environment while maintaining required connectivity.

<br>

![image](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/images/vpc-firewall.png)

<br>

Currently in my project I already have implemented a few policies, including setting the defaults upon VM creation like allowing the networking protocols of RDP (3389), SSH (22), HTTP (80), and HTTPS (443). During the project I added **two policies**, one was allowing the **FastAPI port** (8000), and the other allowing all the ports needed for the **monitoring stack** (3000 for Grafana, 3100 for Loki, and 9090 for Prometheus). By default, inbound traffic to the VPC network is denied unless it's **explicitly allowed** through firewall rules. This helps reduce unnecessary public exposure while still allowing required application and monitoring connectivity.


### 4.4: Security Automation & Scripting

Security-related configuration tasks are partially automated using Bash scripting and the `gcloud` CLI as part of the infrastructure deployment process.

Current automation already includes:

* Firewall rule deployment
* VM provisioning
* Standardised infrastructure configuration
* Repeatable environment setup

Future automation may later include:

* IAM role assignment
* Service account creation
* Secret provisioning
* Additional reusable security baselines

Automation improves consistency, reduces human error, and speeds up infrastructure deployment across environments. But like I said previously, the "automation" part of the task has a catch. You need to  actually fully understand how everything works manually beforehand before you start scripting the whole process. It's best practice to do this in separate script first so that you know which parts can work properly. Just break down the process into chunks and make sure every chunk fully works before moving onto the next.

---

## Phase 5: Managed Application Services (Design & Migration Planning)

This phase introduces the **concept** (in other words, not actually deploying anything right now, but rather planning on how to do it) of moving from self-managed infrastructure to managed Google Cloud services.

It focuses on **architecture changes rather than deployment**, including:

* Understanding how applications transition from VM-based Docker Compose to managed services
* Designing future migration from local PostgreSQL → Cloud SQL
* Identifying stateless vs stateful components in the system
* Planning container readiness for serverless environments (Cloud Run readiness concepts)
* Decoupling application logic from infrastructure dependencies

### **Phase 5 Summary (Planning Overview)**

This phase establishes the migration blueprint for the system (full planning document is in my repo):

* Current VM-based architecture is tightly coupled and infrastructure-dependent
* Target design moves toward stateless application services and managed database systems
* FastAPI is prepared for Cloud Run by removing reliance on local state
* Database layer is planned for migration into Cloud SQL
* Configuration and service connectivity are designed to be environment-driven
* Key gaps are identified, including missing registry, CI/CD, and managed authentication layers

This phase does **not yet deploy to Cloud Run or Cloud SQL**, but prepares the system for migration in later phases (likely Phase 7). In other words we're migrating this project **away** from a virtual machine.
