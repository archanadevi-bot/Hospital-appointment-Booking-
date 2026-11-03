# 🏥 Hospital Appointment Booking System — End-to-End DevOps Project

[![CI/CD Pipeline](https://img.shields.io/badge/Jenkins-CI%2FCD-red?logo=jenkins)](https://www.jenkins.io/)
[![Docker](https://img.shields.io/badge/Docker-Containerized-blue?logo=docker)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestration-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Nginx](https://img.shields.io/badge/Nginx-Alpine-009639?logo=nginx)](https://nginx.org/)
[![AWS EC2](https://img.shields.io/badge/AWS-EC2%20Hosting-orange?logo=amazon-aws)](https://aws.amazon.com/ec2/)

An enterprise-ready DevOps implementation for a production-grade **Hospital Appointment Booking System**. This project transforms an existing multi-page HTML5/CSS3/JavaScript web application into a fully automated, containerized, and orchestrated cloud deployment pipeline.

---

## 📑 Table of Contents

- [DevOps Architecture](#-devops-architecture)
- [Project Overview & Application Workflow](#-project-overview--application-workflow)
- [Tools & Technologies](#-tools--technologies)
- [Repository Directory Structure](#-repository-directory-structure)
- [Stage 1: Docker Containerization](#-stage-1-docker-containerization)
- [Stage 2: Docker Compose Orchestration](#-stage-2-docker-compose-orchestration)
- [Stage 3: Git & GitHub Version Control](#-stage-3-git--github-version-control)
- [Stage 4: Jenkins CI/CD Automation](#-stage-4-jenkins-cicd-automation)
- [Stage 5: Kubernetes Container Orchestration](#-stage-5-kubernetes-container-orchestration)
- [Stage 6: AWS Cloud Deployment](#-stage-6-aws-cloud-deployment)
- [Placement Interview Preparation Guide](#-placement-interview-preparation-guide)

---

## 🏗️ DevOps Architecture

```mermaid
flowchart LR
    A["Developer / Git Push"] --> B["GitHub Repository"]
    B -->|"Webhook Trigger"| C["Jenkins CI/CD Pipeline"]
    subgraph Jenkins_Pipeline["Jenkins Automation Engine"]
        C1["Stage 1: Checkout"] --> C2["Stage 2: Static Validation"]
        C2 --> C3["Stage 3: Docker Build"]
        C3 --> C4["Stage 4: Smoke & Health Test"]
        C4 --> C5["Stage 5: Deploy"]
    end
    C --> Jenkins_Pipeline
    C5 --> D["Docker Engine / Docker Compose"]
    C5 --> E["Kubernetes Cluster (Minikube / EKS)"]
    subgraph K8s["Kubernetes Cluster"]
        E1["Service (NodePort :30080)"] --> E2["Pod Replica 1 (Nginx Alpine)"]
        E1 --> E3["Pod Replica 2 (Nginx Alpine)"]
    end
    E --> K8s
    C5 --> F["AWS EC2 Production Host (:80)"]
```

---

## 🩺 Project Overview & Application Workflow

The **Hospital Appointment Booking System** is a pure client-side multi-page application (MPA) designed for outpatient scheduling:

1. **`index.html` (Landing Page)**: Hero header with medical banner image, leading users to doctor directory or booking form.
2. **`doctors.html` (Doctor Directory)**: Dynamically renders doctor cards from `app.js` (Dr. Smith, Dr. Jones, etc. across 8 specialties). Clicking "Book Appointment" saves the selected doctor ID into browser `localStorage` and routes to `booking.html`.
3. **`booking.html` (Appointment Form)**: Doctor dropdown auto-prefilled from directory selection. Features conflict detection (prevents overlapping bookings for the same doctor on the same date). Stores finalized appointments into `localStorage`.
4. **`confirmation.html` (Bookings Dashboard)**: Lists all confirmed appointments from `localStorage` with real-time cancel/delete capabilities.
5. **`style.css`**: Responsive UI styling, card layouts, form designs, and mobile breakpoints.
6. **`app.js`**: Data repository containing doctor details and specialties.

---

## 🛠️ Tools & Technologies

| Domain | Technology | Version | Purpose |
|---|---|---|---|
| **Frontend** | HTML5, CSS3, JavaScript (ES6) | Standard | Client-side application with localStorage state |
| **Web Server** | Nginx Alpine | 1.27-alpine | High-performance reverse proxy & static asset server |
| **Containerization** | Docker Engine | 29.x / Latest | Application packaging with custom non-root configs |
| **Multi-Container** | Docker Compose | v2 / 3.8 spec | Local multi-service orchestration with resource limits |
| **Version Control** | Git & GitHub | 2.x | Source control, branching, release tags, and webhooks |
| **CI/CD Automation**| Jenkins | LTS | Declarative pipeline for automated build, test & deploy |
| **Orchestration** | Kubernetes (k8s) | 1.36+ | Declarative deployments, replica sets, NodePort routing |
| **Cloud Hosting** | Amazon Web Services (AWS) | EC2 | Cloud virtual machine hosting with Security Groups |

---

## 📁 Repository Directory Structure

```text
Hospital-appointment-Booking/
├── .dockerignore                 # Excludes unnecessary files from Docker build context
├── .gitignore                    # Prevents build artifacts and OS caches from Git tracking
├── 852d3ae66e2f216bcc1e074c7e0da8da.jpg  # Hero banner background image
├── app.js                        # Doctor dataset array (Root fallback)
├── booking.html                  # Appointment scheduling page with validation
├── confirmation.html             # Confirmed appointments management page
├── css/
│   └── style.css                 # CSS stylesheet in standard directory structure
├── docker-compose.yml            # Multi-container orchestration definition
├── Dockerfile                    # Production-grade multi-stage / Alpine Nginx image
├── doctors.html                  # Dynamic doctor card listing page
├── index.html                    # Application entry point / Landing page
├── Jenkinsfile                   # Declarative Jenkins CI/CD pipeline definition
├── js/
│   └── app.js                    # JavaScript data source in standard directory structure
├── k8s/
│   ├── deployment.yaml           # Kubernetes Deployment (2 Replicas, probes, limits)
│   └── service.yaml              # Kubernetes Service (NodePort 30080)
├── nginx.conf                    # Production Nginx server configuration
├── README.md                     # Comprehensive documentation & interview guide
└── scripts/
    └── deploy-aws.sh             # Bash automation script for EC2 server bootstrap
```

---

## 🐳 Stage 1: Docker Containerization

### What is Docker?
Docker is an open-source platform that packages applications and their entire dependency tree into standardized, portable units called **containers**.

### 1. Production `Dockerfile` Explanation
```dockerfile
FROM nginx:1.27-alpine
RUN rm -rf /usr/share/nginx/html/*
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html doctors.html booking.html confirmation.html style.css app.js 852d3ae66e2f216bcc1e074c7e0da8da.jpg /usr/share/nginx/html/
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/
RUN chmod -R 755 /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:80/healthz || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

**Key Highlights:**
- **`nginx:1.27-alpine`**: Weighs ~23MB, minimizing the container attack surface and pull times.
- **`HEALTHCHECK`**: Automatically queries `/healthz` every 30 seconds; reports unhealthy status to Docker daemon if Nginx crashes.
- **`nginx -g "daemon off;"`**: Prevents Nginx from daemonizing into the background, which would cause PID 1 to exit and terminate the container.

### 2. Custom `nginx.conf` Highlights
- **Gzip Compression**: Compresses HTML, CSS, JS, and JSON on the fly, reducing bandwidth by up to 70%.
- **Security Headers**: Includes `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, and `X-XSS-Protection`.
- **`/healthz` Endpoint**: Returns `200 OK` without touching disk logs, used by Kubernetes and AWS Application Load Balancers (ALB).
- **Static Asset Caching**: 7-day browser caching with `Cache-Control: public, no-transform`.

### 3. Docker Execution Commands
```bash
# 1. Build the Docker image
docker build -t hospital-booking:latest .

# 2. Verify image was created
docker images | grep hospital-booking

# 3. Run container in detached mode mapping host port 8080 to container port 80
docker run -d --name hospital-booking-app -p 8080:80 hospital-booking:latest

# 4. Check container status
docker ps -f name=hospital-booking-app

# 5. Verify HTTP connectivity & health check
curl -I http://localhost:8080/
curl http://localhost:8080/healthz

# 6. Stop and remove container when done
docker stop hospital-booking-app
docker rm hospital-booking-app
```

---

## 🐙 Stage 2: Docker Compose Orchestration

Docker Compose simplifies multi-container environments and service definitions in declarative YAML format.

### `docker-compose.yml` Configuration
```yaml
version: '3.8'

services:
  hospital-booking-frontend:
    build:
      context: .
      dockerfile: Dockerfile
    image: hospital-booking:latest
    container_name: hospital-booking-app
    restart: unless-stopped
    ports:
      - "8080:80"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:80/healthz || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 256M
        reservations:
          cpus: '0.10'
          memory: 64M
    networks:
      - hospital-network

networks:
  hospital-network:
    driver: bridge
```

### Docker Compose Commands
```bash
# Build and start services in the background
docker compose up -d --build

# View running services
docker compose ps

# View live container logs
docker compose logs -f

# Stop and remove containers and networks
docker compose down
```

---

## 🐙 Stage 3: Git & GitHub Version Control

### 1. Initialize Git Repository
```bash
# Initialize git repository
git init

# Configure user identity
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Check status
git status

# Stage all files
git add .

# Create initial commit
git commit -m "feat: initial DevOps setup for Hospital Appointment Booking system"

# Rename default branch to main
git branch -M main
```

### 2. Push to GitHub
```bash
# Add your GitHub remote repository
git remote add origin https://github.com/<your-username>/hospital-appointment-booking.git

# Push code to main branch
git push -u origin main
```

---

## ⚙️ Stage 4: Jenkins CI/CD Automation

Jenkins automates the lifecycle from source code commit to production container roll-out.

### 1. Jenkins Architecture & Prerequisites
- **Jenkins Controller (Master)**: Manages pipelines, triggers, and credentials.
- **Required Plugins**:
  - `Pipeline` (Core pipeline plugin)
  - `Git` (SCM integration)
  - `Docker Pipeline` & `Docker plugin` (For running Docker commands within build steps)
  - `GitHub Integration Plugin` (For automated webhook triggers)
  - `AnsiColor` (Colorized console logs)

### 2. Jenkins Pipeline Workflow (`Jenkinsfile`)
1. **Checkout**: Pulls the latest commit from the GitHub repository `main` branch.
2. **Static Validation**: Verifies that essential assets (`index.html`, `doctors.html`, `style.css`, `app.js`, `nginx.conf`) exist before initiating container build.
3. **Build Docker Image**: Executes `docker build` tagging with both `${BUILD_NUMBER}` and `latest`.
4. **Smoke & Health Test**: Spins up an ephemeral container on test port `8085`, probes `/healthz` and `/index.html`, and tears it down upon verification.
5. **Deploy Container**: Performs zero-downtime container replacement on production port `8080`.

### 3. Setting Up GitHub Webhook
1. Go to your GitHub repository: **Settings** → **Webhooks** → **Add webhook**.
2. **Payload URL**: `http://<your-jenkins-ip>:8080/github-webhook/`
3. **Content type**: `application/json`
4. **Events**: Select **Just the push event**.
5. Click **Add webhook**. Now every `git push` automatically triggers the Jenkins pipeline!

---

## ☸️ Stage 5: Kubernetes Container Orchestration

Kubernetes (K8s) provides declarative container orchestration, automated healing, scaling, and rolling updates.

### 1. Deployment Specification (`k8s/deployment.yaml`)
- **`replicas: 2`**: Runs two identical pods for high availability.
- **`strategy: RollingUpdate`**: Guarantees zero downtime by spinning up the new version (`maxSurge: 1`) before removing the old version (`maxUnavailable: 0`).
- **`resources`**: Enforces strict requests (`100m` CPU, `64Mi` RAM) and limits (`250m` CPU, `128Mi` RAM) to prevent noisy-neighbor memory exhaustion.
- **`readinessProbe`**: Ensures K8s traffic is only routed to the pod when `/healthz` returns 200.
- **`livenessProbe`**: Detects hung processes and restarts the pod automatically.

### 2. Service Specification (`k8s/service.yaml`)
- **`type: NodePort`**: Exposes port `80` inside the cluster on static port `30080` across all cluster nodes.

### 3. Deployment Commands
```bash
# 1. Apply deployment manifest
kubectl apply -f k8s/deployment.yaml

# 2. Apply service manifest
kubectl apply -f k8s/service.yaml

# 3. Check deployment status
kubectl get deployments
kubectl rollout status deployment/hospital-booking-deployment

# 4. Inspect pods
kubectl get pods -l app=hospital-booking -o wide

# 5. Check service and exposed NodePort
kubectl get services hospital-booking-service

# 6. Test service locally (Minikube / Docker Desktop)
# If using Minikube:
minikube service hospital-booking-service --url

# If using Docker Desktop Kubernetes:
curl http://localhost:30080/healthz
```

---

## ☁️ Stage 6: AWS Cloud Deployment

Deploying the Hospital Booking Application on Amazon Web Services (AWS) using EC2.

### Step 1: Launch an EC2 Instance
1. Sign in to AWS Management Console → **EC2** → **Launch Instance**.
2. **Name**: `Hospital-Booking-Server`
3. **AMI**: `Ubuntu Server 22.04 LTS (HVM)` or `Amazon Linux 2023`.
4. **Instance Type**: `t2.micro` (AWS Free Tier eligible) or `t3.small`.
5. **Key Pair**: Select or create an RSA key pair (`hospital-key.pem`).

### Step 2: Configure Security Group (Firewall)
Create an EC2 Security Group with the following Inbound Rules:

| Type | Protocol | Port Range | Source | Description |
|---|---|---|---|---|
| **SSH** | TCP | 22 | `My IP` | Secure SSH management |
| **HTTP** | TCP | 80 | `0.0.0.0/0` | Public web traffic |
| **Custom TCP** | TCP | 8080 | `0.0.0.0/0` | Jenkins / Docker alternative port |
| **Custom TCP** | TCP | 30080 | `0.0.0.0/0` | Kubernetes NodePort access |

### Step 3: Connect to EC2 & Deploy
```bash
# Connect via SSH
ssh -i hospital-key.pem ubuntu@<ec2-public-ip>

# Clone repository
git clone https://github.com/<your-username>/hospital-appointment-booking.git
cd hospital-appointment-booking

# Run automated deployment script
chmod +x scripts/deploy-aws.sh
./scripts/deploy-aws.sh
```

### Step 4: Access Application
Open your browser and navigate to:
```text
http://<EC2-PUBLIC-IP>/
```

---

## 🎯 Placement Interview Preparation Guide

### Top DevOps Interview Questions for this Project

#### Q1: Why did you choose Nginx Alpine as the base image for this frontend?
> **Answer:** Alpine Linux is an ultra-lightweight Linux distribution (~5MB base). When combined with Nginx, the final image size is under 25MB compared to 150MB+ for Debian-based images. This significantly reduces security vulnerabilities (smaller attack surface), accelerates CI/CD image build and download times, and reduces cloud storage and bandwidth costs.

#### Q2: What is the difference between `readinessProbe` and `livenessProbe` in Kubernetes?
> **Answer:** 
> - **`readinessProbe`** determines if a pod is ready to accept incoming user traffic. If it fails, Kubernetes removes the pod's IP from the Service endpoints so users do not receive errors, but the container is **not** killed.
> - **`livenessProbe`** determines if the container process is still alive and functioning. If it fails, Kubernetes immediately kills and restarts the container based on the restart policy.

#### Q3: Why did you configure `/healthz` inside `nginx.conf` instead of checking `index.html`?
> **Answer:** The `/healthz` endpoint is a dedicated, lightweight endpoint that returns `200 "healthy\n"` directly from memory with `access_log off;`. Checking `index.html` involves disk I/O, loads asset contents into memory, and pollutes access logs with thousands of probe requests every hour.

#### Q4: How does zero-downtime deployment work in your Kubernetes configuration?
> **Answer:** We configured `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`. During an update, Kubernetes spins up 1 new pod with the new container image first. Traffic is only routed to the new pod once its `readinessProbe` succeeds. Only then is the old pod gracefully terminated. Thus, 100% service capacity is maintained throughout deployment.

#### Q5: How does a GitHub Webhook communicate with your Jenkins CI/CD pipeline?
> **Answer:** When a developer pushes commits to GitHub, GitHub sends an HTTP POST payload with JSON metadata to Jenkins' webhook listener URL (`http://<jenkins-url>:8080/github-webhook/`). Jenkins parses the repository URL and branch name, matches it against configured Pipeline jobs, and instantly triggers the build stages without polling.

---

## 👨‍💻 Author & Maintainer
- **Hospital Appointment Booking DevOps Project**
- Developed for production deployment and placement interview demonstrations.
