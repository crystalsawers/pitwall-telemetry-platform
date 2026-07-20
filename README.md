# Google Cloud Free Trial Project: Pitwall Telemetry Platform

The **Pitwall Telemetry Platform** is a cloud-native telemetry and data platform inspired by **Formula 1 systems**, built on **Google Cloud** using modern DevOps, infrastructure-as-code, and microservices architecture principles.

_Project timeframe: 9 May 2026 - 20 July 2026 (Free Trial ended 8 August 2026)_

---

## Project Overview

The **Pitwall Telemetry Platform** simulates a real-world Formula 1-style data infrastructure, focusing on how race telemetry, automation, and operational systems could be designed in a cloud-native environment.

The project is intentionally constrained to **Google Cloud free-tier resources** with 90s days to complete and $510 (NZD) worth of credit, so this requires careful architecture decisions around cost, scalability, and resource management.

The goal is to demonstrate practical skills in:
- Cloud engineering (Google Cloud Platform)
- Infrastructure as Code (Terraform)
- Kubernetes orchestration
- DevOps automation
- Observability and system design

---
## Infrastructure

The system is currently built on the **Google Compute Engine**, otherwise known as the Virtual Machine. There weill be further developments on this, potentially migrating to Kubernetes later.

### Application Layer
- Multiple FastAPI microservices
- Containerised using Docker
- Independently deployable services for:
  - Telemetry-style data ingestion
  - Data processing
  - API access layer
  - Scheduling / automation tasks

### Data Layer
- PostgreSQL for structured relational data
- Designed for telemetry-style event storage and querying

### Monitoring and Logs
- Prometheus for metrics collection
- Grafana for visual dashboards
- Loki for log aggregation and debugging


### Cloud Infrastructure
- Google Kubernetes Engine (GKE)
- Compute Engine (supporting workloads and isolated testing)
- Terraform for infrastructure provisioning

### Automation & CI/CD
- GitHub Actions for deployment pipelines
- Bash scripting for operational automation

### Base Operating Environment
- Ubuntu Server (headless Linux environment)
- Docker runtime for container execution

---

## Free Tier Constraints

This project is designed within Google Cloud free-tier limitations.

Key constraints include:
- Limited compute usage on VM and GKE resources
- Strict control over cluster sizing and uptime
- Storage and logging growth management
- Avoiding unnecessary always-on services
- Using only Google-owned AI models in the Agent Platform (e.g. Gemini)

To manage costs:
- Resources are kept minimal and modular
- Services are scaled down when not in use
- Automation is used to prevent idle resource costs

---

## Development Phases

This project is broken down into several phases, documented as a blog series. This was initially planned as a 3-part series, but has been extended to 5 parts.

---

### Part 1 - Core System & Initial Automation (Phase 1-2)

📘 Docs: [/docs/phase 1-2.md](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/phase%201-2.md)

📝 Blog: [The Art of Google Cloud (Part 1)](https://loglapandover.co.nz/projects/devops/P9McSw1XKxtBUFpzdg4g)

#### Phase 1 - Core System Build

* Google Cloud Compute Engine (VM provisioning)
* VPC networking and firewall configuration
* Ubuntu Server setup
* SSH access configuration
* Docker + Docker Compose
* FastAPI microservice
* PostgreSQL database
* Initial containerised application deployment



#### Phase 2 - Infrastructure Automation

* Google Cloud Console + Cloud Shell
* `gcloud` CLI automation
* Startup scripts for VM bootstrapping
* Instance templates for repeatable deployments
* Docker + Docker Compose automation
* Initial telemetry-style data ingestion experiments

---

### Part 2 - Service Expansion, Observability & Security Foundations (Phase 3-5)

📘 Docs: [/docs/phase 3-4-5.md](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/phase%203-4-5.md)

📝 Blog: [The Art of Google Cloud (Part 2)](https://loglapandover.co.nz/projects/devops/rUzNh2L9nTWgyQQjpVf3)


#### Phase 3 - Monitoring Stack & Telemetry Foundation

* Deployment of observability stack for system visibility (Prometheus, Grafana, Loki)
* Integration of monitoring tools with FastAPI-based telemetry services
* Collection of metrics, logs, and application-level signals
* Initial exposure of F1-style telemetry data into monitoring dashboards
* Structuring services to support observable, event-driven architecture
* Establishing baseline system health tracking across containers and VMs


#### Phase 4 - Security & Access Control

* IAM (Identity and Access Management)

  * Role-based access control (RBAC)
  * Service account creation and management
  * Principle of least privilege
* VPC Firewall Policies

  * Explicit allow rules for required services
  * Controlled exposure of FastAPI and monitoring ports
  * Network tagging for firewall targeting
* Secret Manager

  * Secure storage of credentials and API keys
  * Removal of sensitive data from `.env` files and repositories
* Early Security Automation

  * Bash and `gcloud`-based infrastructure scripting
  * Partial automation of provisioning and security setup


#### Phase 5 – Managed Application Services (Design & Migration Planning)

* Architectural planning for migration from VM-based Docker Compose to managed Google Cloud services
* Identification of stateless vs stateful components within the system
* Designing how FastAPI will evolve into a Cloud Run-compatible service (serverless-ready structure)
* Planning database migration from local PostgreSQL container to Cloud SQL
* Designing secure service-to-database connectivity in a managed environment (IAM-based access, connection abstraction)
* Understanding decoupling of application logic from infrastructure dependencies
* Preparation for future CI/CD-driven container deployment workflows

---

### Part 3 - CI/CD, Container Orchestration & Infrastructure (Phase 6-8)

📘 Docs: [/docs/phase 6-7-8.md](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/phase%206-7-8.md)

📝 Blog: [The Art of Google Cloud (Part 3)](https://loglapandover.co.nz/projects/devops/8RA0vlrnQM9lmk8gUg8t)

#### Phase 6 - CI/CD Automation

* Google Cloud Build pipelines
* GitHub integration
* Automated container builds and deployments
* Continuous delivery workflows
* Artifact Registry for container image management
* Separate app repo for demonstration - [f1-telemetry-app](https://github.com/crystalsawers/f1-telemetry-app)



#### Phase 7 - Cloud Run & Cloud SQL

* Image versioning and lifecycle handling
* Cloud Run for serverless container deployment of application services
* Cloud SQL for managed database services and production database hosting



#### Phase 8 - Kubernetes 

* Google Kubernetes Engine (GKE) introduction
* Kubernetes deployments, services, and scaling concepts
* Transition from container builds → orchestrated cluster deployment
* Automation with Deployments, Config Maps, Jobs, and Workloads

---

### Part 4 - Independent Google Cloud Experiments (Phase 9-12)

📘 Docs: [/docs/phase 9-12.md](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/phase%209-12.md)

📝 Blog: [The Art of Google Cloud (Part 4)](https://loglapandover.co.nz/projects/devops/kA5uQMYizopqajwZhh2E)

#### Phase 9 - AI Agent Platform

* Standalone AI agent experimentation (not tied to production systems)
* Natural language interaction capabilities
* Reasoning workflows and chain-of-thought patterns
* Tool use and function calling exploration
* Google Cloud AI/ML APIs for agent augmentation
* Independent test scenarios for agent behavior and response quality
* Agent Platform testing for conversational AI workflows

#### Phase 10 - BigQuery Data Exploration

* BigQuery setup and configuration for learning purposes
* Sample dataset loading and exploration
* Standard SQL querying for analytical workflows
* Dataset handling patterns (partitioning, clustering)
* Query performance basics and cost awareness
* Data export and visualization connections (Looker Studio, Python)

#### Phase 11 - Google Cloud Storage

* Creating a storage bucket
* Uploading files and folders into the bucket

#### Phase 12 - Pub/Sub

* Creating a Topic and Subscription
* Configure Notifications on the subscription using the Storage Bucket from Phase 11

---

### Part 5 - Infrastructure as Code with Terraform (Phase 13)

📘 Docs: [/docs/phase 13.md](https://github.com/crystalsawers/pitwall-telemetry-platform/blob/main/docs/phase%2013.md)

📝 Blog: [The Art of Google Cloud (Part 5)]()


#### Phase 13 - Terraform

* Terraform project structure and state management
* Virtual Machine (VM) provisioning on Compute Engine
* Google Kubernetes Engine (GKE) cluster deployment
* Cloud Run service configuration and deployment
* Cloud SQL instance provisioning (PostgreSQL)
* IAM roles, policies, and service accounts