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

## System Architecture

The platform is designed as a distributed system rather than a monolithic application.

### Core Design Principles
- Microservices-based architecture
- Event-driven communication patterns
- Cloud-native deployment model
- Infrastructure defined as code
- Observability-first design

---

## ☁️ Infrastructure

The system is built around a Kubernetes-based core running on **Google Kubernetes Engine (GKE)**, with supporting cloud services.

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
- Cloud Storage (backups and long-term data storage)
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

This project is split into a structured 3-part progression, documented as a blog series covering infrastructure setup, automation, scaling, and production-grade DevOps practices.

---

### Part 1 - Core System & Initial Automation (Phase 1-2)

📘 Docs: [/docs/phase 1-2.md](../docs/phase 1-2.md)
📝 Blog: (coming soon)

#### Phase 1 - Core System Build

* Google Cloud Console (Compute Engine)
* VPC networking and firewall configuration
* Ubuntu Server setup
* SSH access configuration
* Docker + Docker Compose
* FastAPI microservice
* PostgreSQL database
* Initial containerised application deployment

**Outcome:** A fully working VM running a containerised API + database stack.

---

#### Phase 2 - Infrastructure Automation

* Google Cloud Console + Cloud Shell
* `gcloud` CLI automation
* Startup scripts for instance bootstrapping
* Instance templates for repeatable deployment
* Docker + Docker Compose automation
* Integration of real Formula 1 telemetry/data sources (initial ingestion experiments)

**Outcome:** Repeatable infrastructure setup with scripted deployment instead of manual configuration. But you have to actually understand the manual configuration first. 

---

### Part 2 - Scaling, Observability & Security (Phase 3-5)

📘 Docs: (coming soon)  
📝 Blog: (coming soon)

**Focus:** Moving from a single VM system to a managed, scalable cloud-native architecture.

#### Phase 3 - Kubernetes Orchestration

* Google Kubernetes Engine (GKE)
* Container orchestration and service deployment
* Scaling microservices architecture

#### Phase 4 - Observability Stack

* Google Cloud Operations Suite

  * Cloud Monitoring
  * Cloud Logging
* System metrics, logs, and dashboards
* Service health visibility

#### Phase 5 - Security & Access Control

* IAM roles and permissions
* VPC firewall policy refinement
* Secret Manager for credential handling

**Outcome:** A scalable, observable, and security-hardened cloud-native system.

---

### Part 3 - Production Automation & IaC (Phase 6-7)

📘 Docs: (coming soon)  
📝 Blog: (coming soon)

**Focus:** Full production-style automation and infrastructure management.

#### Phase 6 - CI/CD Pipelines

* Google Cloud Build
* Automated testing and deployment pipelines
* Continuous delivery of containerised services

#### Phase 7 - Infrastructure as Code

* Artifact Registry (container management)
* Terraform for infrastructure provisioning (optional but recommended)
* Fully reproducible cloud environments

**Outcome:** End-to-end automated deployment pipeline with infrastructure defined as code.

---

## Current Status

**Phase 1 & 2:** Initial working system (single-node deployment with containerised API + database), Done

**Phase 1** is the experiment of using Compute Engine inside the Console, while **Phase 2** involves using a script to set everything up.

**Next:** Phase 3 - Kubernetes Orchestration

---

## Goal

To build a production-style cloud-native telemetry platform that demonstrates real-world skills in:

- Distributed systems design
- Google Cloud architecture
- Kubernetes operations
- DevOps automation
- Infrastructure as Code

All within a constrained free-tier environment to simulate real-world engineering trade-offs.