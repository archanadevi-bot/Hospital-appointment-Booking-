# 🐳 Docker & Nginx Containerization Guide
## Hospital Appointment Booking System

---

## 1. Docker Fundamentals & Core Concepts

Docker is an open-source containerization platform that packages applications and their runtime dependencies into isolated, lightweight, and portable execution units called **containers**.

### Image vs. Container
| Characteristic | Docker Image | Docker Container |
|---|---|---|
| **Definition** | An immutable, read-only template with instructions and layers. | A runnable, isolated instance of an image with a writable top layer. |
| **State** | Static (stored on disk or in a registry like Docker Hub). | Dynamic (Running, Paused, Stopped, or Exited). |
| **Analogy** | A class definition in Object-Oriented Programming. | An instantiated object in memory. |
| **Lifecycle** | `docker build`, `docker pull`, `docker tag`. | `docker run`, `docker stop`, `docker start`, `docker rm`. |

---

## 2. Production Dockerfile Line-by-Line Breakdown

```dockerfile
# Base Image: Minimal Alpine Linux with official Nginx
FROM nginx:1.27-alpine

LABEL maintainer="DevOps Team" \
      project="hospital-appointment-booking" \
      version="1.0.0"

# Remove default static HTML files provided by Nginx image
RUN rm -rf /usr/share/nginx/html/*

# Copy production Nginx server configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy all application HTML, CSS, JS, and image assets
COPY index.html doctors.html booking.html confirmation.html style.css app.js 852d3ae66e2f216bcc1e074c7e0da8da.jpg /usr/share/nginx/html/

# Copy asset subdirectories to preserve relative path resolution
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/

# Set read and execute permissions for web server worker
RUN chmod -R 755 /usr/share/nginx/html

# Expose standard HTTP container port 80
EXPOSE 80

# Health check probe: queries dedicated endpoint every 30 seconds
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:80/healthz || exit 1

# Start Nginx in foreground to keep container running as PID 1
CMD ["nginx", "-g", "daemon off;"]
```

### Explanation of Directives:
1. **`FROM nginx:1.27-alpine`**: Selects Alpine Linux as the base OS. The final image size is only **21.1 MB**, drastically reducing download times and common vulnerability exposure (CVEs).
2. **`RUN rm -rf /usr/share/nginx/html/*`**: Purges default placeholder files to eliminate residual attack vectors or stale index pages.
3. **`COPY ...`**: Injects custom Nginx routing rules and all static application files into Nginx's document root.
4. **`chmod -R 755`**: Enforces the principle of least privilege, allowing Nginx workers to read assets without granting write permissions.
5. **`EXPOSE 80`**: Documents that the container process listens on TCP port 80.
6. **`HEALTHCHECK`**: Instructs the Docker engine to periodically verify the `/healthz` endpoint via BusyBox `wget`. If the check fails 3 consecutive times, Docker marks the container status as `(unhealthy)`.
7. **`CMD ["nginx", "-g", "daemon off;"]`**: In Docker, containers exit as soon as their root process (PID 1) finishes. By default, Nginx forks into a background daemon, which would immediately stop the container. Setting `daemon off;` forces Nginx to run continuously in the foreground as PID 1.

---

## 3. Production Nginx Configuration (`nginx.conf`)

Nginx operates as a high-performance reverse proxy and static file server.

### Dual-Stack Network Binding & Diagnosis
During initial testing in Alpine Linux, Alpine resolved `localhost` to IPv6 `::1` before IPv4 `127.0.0.1`. Binding only to IPv4 resulted in `wget: can't connect to remote host: Connection refused`. 

To guarantee 100% reliable local health checks across all environments, dual-stack binding and explicit loopback routing were implemented:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Gzip Compression for network efficiency
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/javascript application/xml application/json image/svg+xml;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Zero-Log Health check endpoint for Docker, K8s, and AWS ALB
    location /healthz {
        access_log off;
        default_type text/plain;
        return 200 "healthy\n";
    }

    # Static assets caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 7d;
        add_header Cache-Control "public, no-transform";
    }

    # Route all unmatched URIs to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Error pages
    error_page 404 /index.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

---

## 4. Docker Compose Orchestration (`docker-compose.yml`)

Docker Compose simplifies multi-container lifecycle management using declarative YAML:

```yaml
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
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:80/healthz || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 5s
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

### Key Parameters:
- **`ports: ["8080:80"]`**: Maps host machine port `8080` to internal container port `80`.
- **`restart: unless-stopped`**: Automatically restarts the container if it crashes or if the Docker daemon reboots, unless manually stopped.
- **`deploy.resources`**: Enforces memory and CPU limits to prevent a single container from consuming host memory.
- **`networks: hospital-network`**: Isolates container networking in a dedicated user-defined bridge network.

---

## 5. Practical Command Reference

```bash
# 1. Build Docker image
docker build -t hospital-booking:latest .

# 2. Verify image creation and size
docker images hospital-booking:latest

# 3. Run container in background mapping port 8080
docker run -d --name hospital-booking-app -p 8080:80 hospital-booking:latest

# 4. Inspect container health and runtime status
docker ps -f name=hospital-booking-app
docker inspect hospital-booking-app --format '{{json .State.Health}}'

# 5. Test HTTP endpoints
curl -I http://localhost:8080/
curl http://localhost:8080/healthz

# 6. View live container logs
docker logs -f hospital-booking-app

# 7. Start services via Docker Compose
docker compose up -d --build

# 8. Stop and clean up containers
docker stop hospital-booking-app
docker rm hospital-booking-app
docker compose down
```

---

## 6. Troubleshooting Common Docker Issues

| Symptom | Cause | Resolution |
|---|---|---|
| `failed to connect to docker API: pipe not found` | Docker Desktop daemon is stopped on Windows. | Open **Docker Desktop** from the Start Menu and wait for the "Engine running" status. |
| `port is already allocated: 8080` | Another process is occupying port 8080. | Run `Get-NetTCPConnection -LocalPort 8080` to identify the process or map to port 8082. |
| `wget: can't connect to remote host: Connection refused` | Healthcheck querying `localhost` on IPv6 `::1`. | Change healthcheck URL to `http://127.0.0.1:80/healthz` and add `listen [::]:80;` to `nginx.conf`. |
| Image build takes too long | Unnecessary files copied into build context. | Add `.git`, `*.md`, `node_modules`, and `.idea` to `.dockerignore`. |
