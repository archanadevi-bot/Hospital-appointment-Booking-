pipeline {
    agent any

    environment {
        APP_NAME        = 'hospital-appointment-booking'
        DOCKER_IMAGE    = 'hospital-booking'
        IMAGE_TAG       = "${BUILD_NUMBER}"
        CONTAINER_NAME  = 'hospital-booking-app'
        HOST_PORT       = '8080'
        TEST_PORT       = '8085'
        NODE_PORT       = '30080'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        ansiColor('xterm')
    }

    triggers {
        // Triggers automatically on GitHub push webhook, with automated SCM polling every 5 minutes
        githubPush()
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo "=========================================================="
                echo " [STAGE 1] Retrieving source code from GitHub..."
                echo "=========================================================="
                checkout scm
                script {
                    def branchName = env.GIT_BRANCH ?: 'main'
                    def commitHash = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    echo "Branch: ${branchName}"
                    echo "Commit Hash: ${commitHash}"
                    echo "Build Number: ${BUILD_NUMBER}"
                }
            }
        }

        stage('2. Static File Validation') {
            steps {
                echo "=========================================================="
                echo " [STAGE 2] Validating core application assets and configs..."
                echo "=========================================================="
                sh '''
                    echo "Checking mandatory application files..."
                    test -f index.html        || { echo "ERROR: Missing index.html"; exit 1; }
                    test -f doctors.html      || { echo "ERROR: Missing doctors.html"; exit 1; }
                    test -f booking.html      || { echo "ERROR: Missing booking.html"; exit 1; }
                    test -f confirmation.html || { echo "ERROR: Missing confirmation.html"; exit 1; }
                    test -f style.css         || { echo "ERROR: Missing style.css"; exit 1; }
                    test -f app.js            || { echo "ERROR: Missing app.js"; exit 1; }
                    test -f nginx.conf        || { echo "ERROR: Missing nginx.conf"; exit 1; }
                    test -f Dockerfile        || { echo "ERROR: Missing Dockerfile"; exit 1; }
                    test -f k8s/deployment.yaml || { echo "ERROR: Missing k8s/deployment.yaml"; exit 1; }
                    test -f k8s/service.yaml    || { echo "ERROR: Missing k8s/service.yaml"; exit 1; }
                    echo "All core files and Kubernetes manifests verified."
                '''
            }
        }

        stage('3. Docker Image Build') {
            steps {
                echo "=========================================================="
                echo " [STAGE 3] Building Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG}..."
                echo "=========================================================="
                sh '''
                    docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest

                    echo "Verifying Docker image creation..."
                    docker images | grep ${DOCKER_IMAGE} | head -n 2
                '''
            }
        }

        stage('4. Container Smoke Testing') {
            steps {
                echo "=========================================================="
                echo " [STAGE 4] Running ephemeral container smoke test on port ${TEST_PORT}..."
                echo "=========================================================="
                sh '''
                    # Clean up test container if previously existing
                    docker rm -f ${DOCKER_IMAGE}-test 2>/dev/null || true

                    # Start temporary container for validation
                    echo "Starting test container on port ${TEST_PORT}..."
                    docker run -d --name ${DOCKER_IMAGE}-test -p ${TEST_PORT}:80 ${DOCKER_IMAGE}:${IMAGE_TAG}

                    # Allow Nginx 3 seconds to initialize
                    sleep 3

                    # 1. Verify health endpoint
                    echo "Checking /healthz endpoint..."
                    curl -s -f http://localhost:${TEST_PORT}/healthz || { echo "TEST FAILED: /healthz not responding"; docker logs ${DOCKER_IMAGE}-test; docker rm -f ${DOCKER_IMAGE}-test; exit 1; }

                    # 2. Verify homepage index.html
                    echo "Checking homepage index.html..."
                    curl -s -f http://localhost:${TEST_PORT}/index.html || { echo "TEST FAILED: index.html not responding"; docker logs ${DOCKER_IMAGE}-test; docker rm -f ${DOCKER_IMAGE}-test; exit 1; }

                    # 3. Verify doctors directory
                    echo "Checking doctors.html..."
                    curl -s -f http://localhost:${TEST_PORT}/doctors.html || { echo "TEST FAILED: doctors.html not responding"; docker logs ${DOCKER_IMAGE}-test; docker rm -f ${DOCKER_IMAGE}-test; exit 1; }

                    # 4. Verify static stylesheet and script
                    echo "Checking css/style.css and js/app.js..."
                    curl -s -f http://localhost:${TEST_PORT}/css/style.css || { echo "TEST FAILED: css/style.css not responding"; docker logs ${DOCKER_IMAGE}-test; docker rm -f ${DOCKER_IMAGE}-test; exit 1; }
                    curl -s -f http://localhost:${TEST_PORT}/js/app.js || { echo "TEST FAILED: js/app.js not responding"; docker logs ${DOCKER_IMAGE}-test; docker rm -f ${DOCKER_IMAGE}-test; exit 1; }

                    # Inspect container logs
                    echo "Inspecting test container logs:"
                    docker logs --tail 15 ${DOCKER_IMAGE}-test

                    # Tear down test container safely
                    docker rm -f ${DOCKER_IMAGE}-test
                    echo "ALL AUTOMATED PRE-DEPLOYMENT TESTS PASSED!"
                '''
            }
        }

        stage('5. Kubernetes Deployment') {
            steps {
                echo "=========================================================="
                echo " [STAGE 5] Deploying updated container to Kubernetes Cluster..."
                echo "=========================================================="
                sh '''
                    # Check if kubectl has a working cluster connection
                    if kubectl cluster-info > /dev/null 2>&1; then
                        echo "Kubernetes cluster detected. Applying manifests..."
                        kubectl apply -f k8s/

                        echo "Triggering rolling update to ${DOCKER_IMAGE}:${IMAGE_TAG}..."
                        kubectl set image deployment/hospital-booking-deployment hospital-booking-container=${DOCKER_IMAGE}:${IMAGE_TAG} --record=true || true

                        echo "Waiting for rolling update to complete..."
                        kubectl rollout status deployment/hospital-booking-deployment --timeout=120s
                    else
                        echo "WARNING: Kubernetes cluster not reachable. Falling back to local Docker container deployment on port ${HOST_PORT}..."
                        docker stop ${CONTAINER_NAME} 2>/dev/null || true
                        docker rm ${CONTAINER_NAME} 2>/dev/null || true
                        docker run -d --name ${CONTAINER_NAME} --restart unless-stopped -p ${HOST_PORT}:80 ${DOCKER_IMAGE}:latest
                        sleep 3
                        curl -s -f http://localhost:${HOST_PORT}/healthz || exit 1
                    fi
                '''
            }
        }

        stage('6. Post-Deployment Verification') {
            steps {
                echo "=========================================================="
                echo " [STAGE 6] Post-Deployment Runtime Audit..."
                echo "=========================================================="
                sh '''
                    if kubectl cluster-info > /dev/null 2>&1; then
                        echo "=== Kubernetes Deployments ==="
                        kubectl get deployments -l app=hospital-booking

                        echo "=== Kubernetes Pods ==="
                        kubectl get pods -l app=hospital-booking -o wide

                        echo "=== Kubernetes Services ==="
                        kubectl get svc -l app=hospital-booking

                        echo "=== Live HTTP Verification via NodePort ${NODE_PORT} ==="
                        curl -s -f http://localhost:${NODE_PORT}/healthz && echo "Kubernetes Service is HEALTHY!"
                    else
                        echo "=== Standalone Docker Container ==="
                        docker ps -f name=^/${CONTAINER_NAME}$
                        curl -s -f http://localhost:${HOST_PORT}/healthz && echo "Docker Container is HEALTHY!"
                    fi
                '''
            }
        }
    }

    post {
        always {
            echo "CI/CD Pipeline cycle finished."
        }
        success {
            echo "SUCCESS: Hospital Appointment Booking updated and successfully deployed!"
        }
        failure {
            echo "FAILURE: Pipeline failed. Check console output above."
        }
    }
}
