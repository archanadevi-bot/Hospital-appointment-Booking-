# Production Dockerfile for Hospital Appointment Booking Frontend
# Base Image: Lightweight Alpine Linux with official Nginx
FROM nginx:1.27-alpine

LABEL maintainer="DevOps Team" \
      project="hospital-appointment-booking" \
      version="1.0.0" \
      description="Production Nginx container serving Hospital Appointment Booking static web app"

# Remove default nginx static html files
RUN rm -rf /usr/share/nginx/html/*

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy all static assets into Nginx html directory
COPY index.html /usr/share/nginx/html/
COPY doctors.html /usr/share/nginx/html/
COPY booking.html /usr/share/nginx/html/
COPY confirmation.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/
COPY app.js /usr/share/nginx/html/
COPY 852d3ae66e2f216bcc1e074c7e0da8da.jpg /usr/share/nginx/html/

# Copy asset subdirectories to preserve relative path resolution
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/

# Set file permissions for security (read-only for nginx worker)
RUN chmod -R 755 /usr/share/nginx/html

# Expose HTTP port 80
EXPOSE 80

# Health check to ensure the container is serving requests
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:80/healthz || exit 1

# Start Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]

