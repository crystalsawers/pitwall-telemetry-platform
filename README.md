# Pitwall Telemetry Platform

The **Pitwall Telemetry Platform** is a cloud-native telemetry and data platform inspired by **Formula 1 systems**, built on **Google Cloud** using modern DevOps, infrastructure-as-code, and microservices architecture principles.

_Project timeframe: 9 May 2026 - Present_

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
## ☁️ Infrastructure

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
- Cron jobs for scheduled tasks and maintenance

### Base Operating Environment
- Ubuntu Server (headless Linux environment)
- Docker runtime for container execution

---

## ⚠️ Free Tier Constraints

This project is designed within Google Cloud free-tier limitations.

Key constraints include:
- Limited compute usage on VM and GKE resources
- Strict control over cluster sizing and uptime
- Storage and logging growth management
- Avoiding unnecessary always-on services

To manage this:
- Resources are kept minimal and modular
- Services are scaled down when not in use
- Automation is used to prevent idle resource costs

---

## Development Phases

This project is broken down into several phases, documented as a blog series. This was initially planned as a 3-part series, but has been extended to 4 parts, with a potential 5th depending on time and remaining Google Cloud credits.

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

📘 Docs: (coming soon)
📝 Blog: (coming soon)


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

📘 Docs: (coming soon)
📝 Blog: (coming soon)

#### Phase 6 - CI/CD Automation

* Google Cloud Build pipelines
* GitHub integration
* Automated container builds and deployments
* Continuous delivery workflows



#### Phase 7 - Container Registry & Orchestration

* Artifact Registry for container image management
* Image versioning and lifecycle handling
* Cloud Run for serverless container deployment of application services
* Cloud SQL for managed database services and production database hosting
* Google Kubernetes Engine (GKE) introduction
* Kubernetes deployments, services, and scaling concepts
* Transition from container builds → orchestrated cluster deployment



#### Phase 8 - Infrastructure as Code

* Terraform-based infrastructure provisioning
* Reusable environment definitions
* Fully reproducible cloud setups
* Standardised infrastructure deployment workflows

---

### Part 4 - Reliability & Advanced Security (Phase 9-10)

📘 Docs: (coming soon)
📝 Blog: (coming soon)



#### Phase 9 - Reliability Engineering & High Availability

* Load balancing strategies
* Rolling updates and deployment strategies
* Autoscaling concepts
* Health checks and self-healing systems
* Backup and disaster recovery testing



#### Phase 10 - Advanced Security & DevSecOps

* Container vulnerability scanning
* IAM hardening practices
* Workload Identity concepts
* Network policy enforcement
* Secret rotation strategies
* CI/CD security integration

---

### Part 5 - Event-Driven Systems & Data Engineering (Phase 11+)

📘 Docs: (coming soon)
📝 Blog: (coming soon)


#### Phase 11 - Event-Driven Telemetry Systems

* Pub/Sub-based architecture
* Asynchronous processing pipelines
* Queue-based worker systems
* Real-time telemetry ingestion


#### Phase 12 - Data Analytics & Telemetry Platforms

* BigQuery for telemetry storage
* ETL pipelines for data processing
* Historical performance analysis
* Analytics dashboards


#### Phase 13 - Site Reliability Engineering & Operations

* Alerting systems and SLIs/SLOs
* Incident response workflows
* Synthetic monitoring
* Chaos engineering experiments
* Operational runbooks

---

## Current Status

**Phase 5:**  Managed Application Services (Design & Migration Planning), in progress

**Next Phase:** Phase 6 - CI/CD Integration