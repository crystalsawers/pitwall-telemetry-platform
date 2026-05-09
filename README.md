# Pitwall Telemetry Platform

A cloud-native telemetry and data platform inspired by Formula 1 systems, built on Google Cloud using modern DevOps, infrastructure-as-code, and microservices architecture principles.

_Project timeframe: May 2026 – Present_

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

The project is structured into incremental phases:

### Phase 1 – Foundation Setup
- GitHub repository initialization
- Google Cloud environment setup
- Compute Engine instance provisioning
- Ubuntu Server configuration
- Docker installation
- SSH access setup

---

### Phase 2 – Initial Application Deployment
- FastAPI microservice development
- Docker containerisation
- PostgreSQL integration
- Deployment to Compute Engine
- Basic API endpoints for telemetry-style data

---

### Phase 3+ (Planned)
- Kubernetes migration (GKE)
- Service orchestration
- Observability stack deployment
- CI/CD automation
- Security hardening
- Full system integration

---

## Current Status

**Phase 1 & 2:** Initial working system (single-node deployment with containerised API + database)

This stage validates the end-to-end flow:
Application → Container → Cloud Deployment → Database

---

## Evidence & Documentation

The project will eventually be fully documented through:
- Screen recordings of setup and deployment
- Infrastructure configuration snapshots
- GitHub commit history tracking progression
- API response validation from deployed services
- Database interaction logs

---

## Goal

To build a production-style cloud-native telemetry platform that demonstrates real-world skills in:

- Distributed systems design
- Google Cloud architecture
- Kubernetes operations
- DevOps automation
- Infrastructure as Code

All within a constrained free-tier environment to simulate real-world engineering trade-offs.