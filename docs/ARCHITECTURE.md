# 🏛️ System Architecture Specification
## Hospital Appointment Booking System — DevOps Implementation

---

## 1. Executive Summary

This document specifies the end-to-end technical architecture of the **Hospital Appointment Booking System** DevOps implementation. The project bridges modern client-side frontend development with enterprise cloud-native DevOps practices, demonstrating a pipeline spanning **Docker containerization**, **Nginx web serving**, **GitHub version control**, **Jenkins CI/CD automation**, **Kubernetes orchestration**, and **AWS cloud hosting architecture**.

---

## 2. End-to-End DevOps Architecture

```mermaid
flowchart TD
    subgraph SCM["Version Control & Trigger"]
        DEV["Developer Workstation"] -->|"git push origin main"| GITHUB["GitHub Remote Repository\n(archanadevi-bot/Hospital-appointment-Booking-)"]
        GITHUB -->|"Webhook / SCM Polling"| JENKINS["Jenkins Automation Controller\n(Host Port :8081)"]
    end

    subgraph CI_CD["Jenkins Declarative Pipeline"]
        JENKINS --> S1["1. Checkout Source"]
        S1 --> S2["2. Static Validation\n(Assets & Manifests)"]
        S2 --> S3["3. Docker Image Build\n(hospital-booking:${BUILD_NUMBER})"]
        S3 --> S4["4. Ephemeral Smoke Test\n(Test Port :8085)"]
        S4 --> S5["5. Kubernetes Deployment\n(Rolling Update)"]
        S5 --> S6["6. Post-Deployment Audit\n(Health & Readiness)"]
    end

    subgraph K8S_CLUSTER["Kubernetes Cluster (Docker Desktop / EKS)"]
        S5 -->|"kubectl apply"| K8S_SVC["Service: hospital-booking-service\nType: NodePort (:30080 -> 80)"]
        K8S_SVC --> POD1["Pod Replica 1\n(Nginx Alpine :80)"]
        K8S_SVC --> POD2["Pod Replica 2\n(Nginx Alpine :80)"]
        POD1 --- PROBE1["Probes: /healthz\n(Liveness & Readiness)"]
        POD2 --- PROBE2["Probes: /healthz\n(Liveness & Readiness)"]
    end

    subgraph STANDALONE_FALLBACK["Local Container Runtime"]
        S5 -.->|"Fallback / Compose"| DOCKER_APP["Docker Container: hospital-booking-app\nHost Port :8080"]
    end

    subgraph CLOUD["Future Cloud Infrastructure"]
        EC2["AWS EC2 Host\n(Ubuntu 22.04 LTS)"]
        ALB["Application Load Balancer\n(:80 / :443)"]
        ALB -.-> EC2
    end
```

---

## 3. Application Architecture

The application is structured as a performant, lightweight client-side Multi-Page Application (MPA):

```mermaid
flowchart LR
    A["index.html\n(Landing / Hero Banner)"] --> B["doctors.html\n(Directory & Selection)"]
    A --> C["booking.html\n(Scheduling Form)"]
    B -->|"prefillDoctor ID\nin LocalStorage"| C
    C -->|"Commit Appointment\nto LocalStorage"| D["confirmation.html\n(Management Dashboard)"]
    D -->|"Cancel / Reschedule"| C
```

### Component Details
1. **Entry Point (`index.html`)**: Landing page presenting primary actions and medical imagery (`852d3ae66e2f216bcc1e074c7e0da8da.jpg`).
2. **Catalog Page (`doctors.html`)**: Dynamically reads medical specialist profiles from `app.js` and provides single-click routing to the appointment booking page with prefilled state.
3. **Booking Form (`booking.html`)**: Validates patient details, doctor selection, and date conflicts directly against client-side browser storage.
4. **Dashboard (`confirmation.html`)**: Reads booked appointments from `localStorage`, enabling cancellation with real-time UI refresh.
5. **State Management**: State persistence is achieved through browser `localStorage` under the keys `appointments` and `prefillDoctor`.

---

## 4. Web Server & Container Architecture (Nginx Alpine)

The frontend is served using **Nginx 1.27 Alpine**, tuned for production security and low resource utilization:

```mermaid
graph TD
    CLIENT["Browser Client"] -->|"HTTP Request :80"| NGINX["Nginx 1.27 Reverse Proxy"]
    
    subgraph NGINX_FEATURES["Nginx Core Features"]
        NGINX --> GZIP["Gzip Compression Engine\n(HTML, CSS, JS, JSON)"]
        NGINX --> SEC["Security Headers\nX-Frame-Options: SAMEORIGIN\nX-Content-Type-Options: nosniff\nX-XSS-Protection"]
        NGINX --> CACHE["Static Asset Caching\n(7 Days for Images & Scripts)"]
        NGINX --> HEALTH["Zero-Log Health Probe\n(/healthz -> 200 OK)"]
    end

    GZIP --> ASSETS["Static Files (/usr/share/nginx/html)\nHTML, CSS, JS, Images"]
```

### Technical Highlights:
- **Image Size**: ~21.1 MB (via Alpine Linux minimal footprint).
- **Dual-Stack Network Binding**: Binds to both IPv4 (`listen 80;`) and IPv6 (`listen [::]:80;`), avoiding Alpine `localhost` lookup connection refusals.
- **Dedicated Health Probe (`/healthz`)**: Returns `200 "healthy\n"` without disk I/O, preventing access log flooding from Kubernetes liveness and readiness probes.

---

## 5. Jenkins CI/CD Automation Architecture

To prevent port conflicts with the running hospital application on port `8080`, Jenkins runs on dedicated host port `8081`:

```mermaid
flowchart LR
    subgraph HOST["Host Machine (Windows 11)"]
        subgraph APP_CONTAINER["Production Container"]
            APP["hospital-booking-app\nHost Port: 8080"]
        end

        subgraph JENKINS_CONTAINER["Jenkins Controller"]
            JNK["jenkins/jenkins:lts\nHost Port: 8081\nInternal Port: 8080"]
            VOL["jenkins_home Volume"] --- JNK
        end

        SOCK["/var/run/docker.sock\n(WSL 2 Named Pipe)"]
        JNK -->|"Mounted Socket"| SOCK
        SOCK --> DOCKER_ENGINE["Docker Daemon Engine"]
    end
```

### Pipeline Flow:
1. **Checkout**: Source code is fetched from GitHub (`origin/main`).
2. **Static Validation**: Shell assertions verify that all mandatory assets and Kubernetes manifests exist.
3. **Docker Build**: The image is packaged with the unique `${BUILD_NUMBER}` tag and latest tag.
4. **Smoke Test**: An ephemeral container starts on test port `8085` to query `/healthz`, `/index.html`, and static assets before teardown.
5. **Kubernetes Deployment**: `kubectl apply` and `kubectl set image` deploy the verified image to the cluster with zero downtime.
6. **Audit**: Queries pod state, rollout status, and service health.

---

## 6. Kubernetes Cluster Architecture

The application is deployed to a Kubernetes cluster using declarative manifests:

```mermaid
flowchart TD
    subgraph K8S["Kubernetes Cluster"]
        INGRESS["NodePort Service: hospital-booking-service\nNodePort: 30080 | TargetPort: 80"]
        
        subgraph DEPLOYMENT["Deployment: hospital-booking-deployment (Replicas: 2)"]
            subgraph POD1["Pod 1"]
                C1["Container: hospital-booking-container\nImage: hospital-booking:latest\nCPU Limit: 250m | RAM Limit: 128Mi"]
                P1["Probes: /healthz\nReadiness & Liveness"]
            end
            
            subgraph POD2["Pod 2"]
                C2["Container: hospital-booking-container\nImage: hospital-booking:latest\nCPU Limit: 250m | RAM Limit: 128Mi"]
                P2["Probes: /healthz\nReadiness & Liveness"]
            end
        end

        INGRESS --> POD1
        INGRESS --> POD2
    end
```

### Key Orchestration Properties:
- **High Availability**: 2 pod replicas distributed across nodes.
- **Zero-Downtime Rolling Update**: `maxSurge: 1`, `maxUnavailable: 0` ensures existing traffic is maintained while the new container starts.
- **Health Probing**: Traffic is routed to a pod only when `readinessProbe` succeeds. If a pod stalls, `livenessProbe` triggers automated container restart.
- **Resource Boundaries**: Strict CPU requests (`100m`) and limits (`250m`), memory requests (`64Mi`) and limits (`128Mi`) protect against cluster starvation.

---

## 7. Network & Port Allocation Table

| Service | Environment | Host / Node Port | Internal Container Port | Protocol | Purpose |
|---|---|---|---|---|---|
| **Hospital Web App (Docker)** | Local Production | `8080` | `80` | HTTP | Production access for standalone container |
| **Hospital Web App (K8s)** | Kubernetes Cluster | `30080` | `80` | HTTP | NodePort external ingress to cluster |
| **Ephemeral Test Container** | CI/CD Pipeline | `8085` | `80` | HTTP | Automated pre-deployment validation |
| **Jenkins Dashboard** | CI/CD Controller | `8081` | `8080` | HTTP | Jenkins pipeline management UI |
| **Jenkins JNLP Agent** | CI/CD Agents | `50000` | `50000` | TCP | Inbound agent connection listener |
| **AWS EC2 Production** | Cloud (Future) | `80` | `80` | HTTP | Public web access |

---

## 8. Summary of Architectural Guarantees

1. **Port Safety**: Zero collisions between application (`8080`), CI/CD (`8081`), test containers (`8085`), and Kubernetes NodePort (`30080`).
2. **Resilience**: Client-side conflict detection, Nginx dual-stack binding, and Kubernetes automated pod self-healing.
3. **Observability**: Dedicated `/healthz` endpoint with isolated monitoring and discrete pipeline verification audits.

