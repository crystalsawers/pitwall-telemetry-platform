## **Phase 5 Planning Document: Managed Application Services (Migration Design)**

This document defines the architectural planning for transitioning the system from a self-managed VM-based environment to managed Google Cloud services. Phase 5 does not involve deployment or infrastructure changes. Instead, it establishes the target design and identifies the required changes before migration.

---

## **1. Current System State (Baseline Architecture)**

At this stage, the system is fully operational but tightly coupled to a single VM-based environment.

### Current Components:

* **FastAPI** application running inside a Docker container on a Compute Engine VM
* **PostgreSQL** database running as a local Docker container on the same VM
* **Monitoring stack** (Prometheus, Grafana, Loki, Promtail) running on the same host
* All services deployed via **Docker Compose**
* Internal networking between containers handled within the VM

### Key Characteristics:

* Infrastructure-bound deployment (single host dependency)
* Database and application share the same environment
* No external managed services in use
* Scaling is manual and limited to VM capacity
* Failure domain is the entire VM

---

## **2. Target Architecture (Cloud-Native Design Goal)**

The goal of this phase is to define a transition toward managed and decoupled cloud services.

### Planned Target Components:

* FastAPI → deployed as a stateless container on Cloud Run
* PostgreSQL → migrated to Cloud SQL (managed database service)
* Container images → stored and versioned in Artifact Registry (future phase dependency)
* Observability stack → remains external initially, later optimised separately
* Configuration → managed via environment variables and externalised settings

### Key Design Principles:

* Application must be stateless (no local persistence)
* No dependency on VM filesystem or local services
* Clear separation between compute (Cloud Run) and data (Cloud SQL)
* Environment-driven configuration instead of hardcoded values
* Independent lifecycle for application and database components

---

### **Stateless vs Stateful Applications (Core Concept)**

What's the difference between a stateful application and a stateless application?

**Stateless applications:**

* Do not store any data locally between requests
* Each request is independent of previous ones
* Can be freely scaled up or down without data loss concerns
* Ideal for Cloud Run because instances can be created or destroyed at any time
* Example in this system: FastAPI service (once redesigned)

**Stateful applications:**

* Store data locally or rely on persistent internal state
* Depend on disk storage, memory persistence, or local databases
* Require careful handling during scaling or restarts
* More complex to manage in serverless environments
* Example in this system: PostgreSQL database (before migration to Cloud SQL)

---

## **3. Migration Gaps & Required Changes**

This section identifies what must be addressed before migration can occur in later phases.

### Application-Level Gaps:

* FastAPI currently assumes local service dependencies
* Database connection is tied to `localhost` configuration
* No abstraction layer for switching database endpoints
* Container is not yet validated for stateless execution

### Infrastructure Gaps:

* No container registry pipeline for managed deployments
* No separation between build time and runtime environments
* No IAM-based service-to-service authentication
* No managed database integration (Cloud SQL not yet introduced)

### Operational Gaps:

* No CI/CD pipeline connecting code changes to deployment (that's coming in Phase 6)
* No automated rollback or version control for runtime services
* No external configuration management strategy

---

## **4. Design Decisions**

To ensure compatibility with managed Google Cloud services, the following design decisions are established:

* FastAPI will remain fully stateless to support horizontal scaling
* All persistent data will be migrated to Cloud SQL
* Configuration will be externalised using environment variables
* Local Docker dependencies will be removed from runtime design
* Service communication will be decoupled from host-based networking
* Application packaging will be aligned with future container registry workflows

---

## **5. Phase Outcome**

By the end of Phase 5 planning, the system is not yet modified, but fully prepared for migration.

### Deliverables:

* Clear separation of current vs target architecture
* Identified migration blockers and dependency risks
* Defined cloud-native design principles for the application
* Prepared foundation for Cloud Run and Cloud SQL adoption in Phase 7