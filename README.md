# GCP Multi-Region Infrastructure: Cross-Region DR & Observability

## Project Description
This project demonstrates how to build and monitor a resilient, production-ready cloud environment on Google Cloud Platform (GCP). 

The core objective is to ensure business continuity and system transparency by implementing a Cross-Region Database Disaster Recovery (DR) strategy. In this setup, if a catastrophic failure cuts off the primary cloud region, an automated backup database in a completely different geographic region is promoted to take over immediately without data loss. 

Additionally, the project integrates an Observability Stack that collects, processes, and visualizes live server metrics (such as CPU, RAM, and network loads) on an interactive dashboard, providing real-time infrastructure transparency.

---

## Tools & Technologies Used

| Tool / Technology | Purpose in Project |
| :--- | :--- |
| **Google Cloud Platform (GCP)** | The core cloud provider hosting all networking, compute, and database instances. |
| **Terraform (IaC)** | Used to provision and automate the entire infrastructure cleanly via code. |
| **Docker & Docker Compose** | Used to containerize, deploy, and manage the monitoring applications on the host server. |
| **Prometheus** | Acts as the time-series database that scrapes and stores system metrics every 15 seconds. |
| **Node Exporter** | A kernel-level agent that monitors hardware metrics directly from the Linux system. |
| **Grafana** | The visualization platform used to build interactive, live performance dashboards. |
| **PostgreSQL (Cloud SQL)** | Enterprise database service configured for cross-region asynchronous replication. |

---

## Architecture Design & Components

The automated infrastructure consists of the following foundational components:
* **Custom VPC Network (dr-vpc):** A strictly managed Virtual Private Cloud configured without automatic subnetwork creation to ensure precise IP allocation and security control.
* **Multi-Region Subnets:** 
  * `primary-subnet-us-central1` (10.0.1.0/24) hosting the core production resources.
  * `dr-subnet-us-east1` (10.0.2.0/24) reserved exclusively for Disaster Recovery.
* **Compute Engine (prod-web-server):** An Ubuntu 22.04 LTS instance serving as the application host and monitoring node.
* **Secure Private Service Connect:** Configured Private IP Allocation (private-ip-alloc) alongside VPC Peering to route internal database traffic securely without exposing endpoints to the public internet.
* **Cross-Region Cloud SQL Architecture:**
  * **Primary Database (primary-db-instance):** A PostgreSQL 15 Enterprise instance running in `us-central1` as the primary read/write cluster.
  * **Replica Database (replica-db-instance):** A cross-region read-replica deployed in `us-east1`, continuously replicating data asynchronously for hot-failover readiness.

---

## Containerized Observability Stack Workflow

To ensure proactive infrastructure management, a containerized monitoring architecture was implemented directly inside the VM using Docker Compose:

1. **Node Exporter:** Installed as a container agent to collect raw system hardware metrics (CPU load, RAM utilization, Disk I/O, Network Traffic) straight from the Linux kernel.
2. **Prometheus:** Configured to dynamically scrape metrics from the Node Exporter every 15 seconds, storing historical data for analysis.
3. **Grafana:** Connected to Prometheus as the live data source to visualize infrastructure health via professional, interactive dashboards.
4. **Security & Firewall Isolation:** Tightly restricted ingress rules through GCP Firewalls to block unauthorized external access while exposing specific management ports (3000 for Grafana, 9090 for Prometheus, and 22 for SSH).

---

## Disaster Recovery (DR) & Failover Workflow

A core objective of this project was validating business continuity by simulating a catastrophic regional outage in the primary zone (us-central1).

### The Failover Execution Lifecycle:
1. **Simulated Outage:** Ingested a failure scenario on the primary production site.
2. **Database Promotion:** Promoted the read-only cross-region `replica-db-instance` in `us-east1` into a fully standalone, writable database instance to take over traffic.
3. **Advanced State Reconstruction:** Handled real-world deployment friction by resolving Cloud SQL `deletion_protection` locks and using Terraform state manipulation commands (`terraform refresh`, `terraform state rm`, and `terraform import`) to cleanly resynchronize the infrastructure state with the code post-failover.

---

## Live Metrics Dashboard Visualizations

Here is a live look at the production dashboard tailored within Grafana, monitoring real-time system stability, CPU curves, and operational uptime:

### Infrastructure Metrics Breakdown:
* **System Load & CPU Stability:** Monitored idle states and container initializations.
* **Memory Footprint:** Continuous tracking of active RAM storage.
* **Disk Space & Availability:** Monitoring partition allocations for database log storage.

![Grafana Dashboard Live Metrics](./Screenshot%202026-06-19%20221216.png)

---

## How to Deploy This Project

### Prerequisites
* Terraform CLI installed locally.
* Google Cloud SDK (gcloud) configured with appropriate IAM permissions.
* Docker & Docker Compose setup on the remote host.

