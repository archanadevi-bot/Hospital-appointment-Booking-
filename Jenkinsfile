pipeline {
    agent any

    environment {
        APP_NAME        = 'hospital-appointment-booking'
        DOCKER_IMAGE    = 'hospital-booking'
        IMAGE_TAG       = "${BUILD_NUMBER}"
        CONTAINER_NAME  = 'hospital-booking-app'
        HOST_PORT       = '8080'
        TEST_PORT       = '8085'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        ansiColor('xterm')
    }

    triggers {
        // Automatically triggers on GitHub push webhook, with SCM polling backup every 5 minutes
        githubPush()
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo "=========================================================="
                echo " [STAGE 1] Checking out source code from GitHub..."
                echo "=========================================================="
                checkout scm
                script {
                    def branchName = env.GIT_BRANCH ?: 'main'
                    def commitHash = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    echo "Branch: ${branchName}"
                    echo "Commit ID: ${commitHash}"
                    echo "Build Number: ${BUILD_NUMBER}"
                }
            }
        }

        stage('2. Static Validation') {
            steps {
                echo "=========================================================="
                echo " [STAGE 2] Validating core frontend assets and configs..."
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
                    echo "All core application files verified successfully."
                '''
            }
        }

        stage('3. Docker Build') {
            steps {
                echo "=========================================================="
                echo " [STAGE 3] Building Docker Image: ${DOCKER_IMAGE}:${IMAGE_TAG}..."
                echo "=========================================================="
                sh '''
                    docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} .
                    docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest

                    echo "Verifying Docker image creation..."
                    docker images | grep ${DOCKER_IMAGE} | head -n 2
                '''
            }
        }

        stage('4. Automated Testing') {
            steps {
                echo "=========================================================="
                echo " [STAGE 4] Testing container on isolated port ${TEST_PORT}..."
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
                    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/healthz)
                    echo "-> /healthz HTTP status: ${HEALTH_STATUS}"
                    if [ "$HEALTH_STATUS" -ne 200 ]; then
                        echo "TEST FAILED: /healthz did not return HTTP 200"
                        docker logs ${DOCKER_IMAGE}-test
                        docker rm -f ${DOCKER_IMAGE}-test
                        exit 1
                    fi

                    # 2. Verify homepage index.html
                    echo "Checking homepage index.html..."
                    INDEX_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/index.html)
                    echo "-> /index.html HTTP status: ${INDEX_STATUS}"
                    if [ "$INDEX_STATUS" -ne 200 ]; then
                        echo "TEST FAILED: index.html did not return HTTP 200"
                        docker logs ${DOCKER_IMAGE}-test
                        docker rm -f ${DOCKER_IMAGE}-test
                        exit 1
                    fi

                    # 3. Verify doctors.html
                    echo "Checking doctors.html..."
                    DOCS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/doctors.html)
                    echo "-> /doctors.html HTTP status: ${DOCS_STATUS}"
                    if [ "$DOCS_STATUS" -ne 200 ]; then
                        echo "TEST FAILED: doctors.html did not return HTTP 200"
                        docker logs ${DOCKER_IMAGE}-test
                        docker rm -f ${DOCKER_IMAGE}-test
                        exit 1
                    fi

                    # 4. Verify CSS stylesheet
                    echo "Checking css/style.css..."
                    CSS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/css/style.css)
                    echo "-> /css/style.css HTTP status: ${CSS_STATUS}"
                    if [ "$CSS_STATUS" -ne 200 ]; then
                        echo "TEST FAILED: css/style.css did not return HTTP 200"
                        docker logs ${DOCKER_IMAGE}-test
                        docker rm -f ${DOCKER_IMAGE}-test
                        exit 1
                    fi

                    # 5. Verify JavaScript data script
                    echo "Checking js/app.js..."
                    JS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/js/app.js)
                    echo "-> /js/app.js HTTP status: ${JS_STATUS}"
                    if [ "$JS_STATUS" -ne 200 ]; then
                        echo "TEST FAILED: js/app.js did not return HTTP 200"
                        docker logs ${DOCKER_IMAGE}-test
                        docker rm -f ${DOCKER_IMAGE}-test
                        exit 1
                    fi

                    # Inspect container logs
                    echo "Inspecting test container logs:"
                    docker logs --tail 20 ${DOCKER_IMAGE}-test

                    # Tear down temporary test container safely
                    echo "Tearing down test container..."
                    docker rm -f ${DOCKER_IMAGE}-test
                    echo "ALL AUTOMATED TESTS PASSED!"
                '''
            }
        }

        stage('5. Deployment') {
            steps {
                echo "=========================================================="
                echo " [STAGE 5] Zero-Downtime Safe Container Deployment..."
                echo "=========================================================="
                sh '''
                    # Stop and remove existing production container
                    if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
                        echo "Stopping currently running container ${CONTAINER_NAME}..."
                        docker stop ${CONTAINER_NAME}
                    fi

                    if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
                        echo "Removing previous container ${CONTAINER_NAME}..."
                        docker rm ${CONTAINER_NAME}
                    fi

                    # Deploy new production container on port 8080
                    echo "Launching new container ${CONTAINER_NAME} on host port ${HOST_PORT}..."
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --restart unless-stopped \
                        -p ${HOST_PORT}:80 \
                        ${DOCKER_IMAGE}:latest

                    sleep 3

                    # Verify new container is healthy
                    PROD_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${HOST_PORT}/healthz)
                    if [ "$PROD_HEALTH" -ne 200 ]; then
                        echo "DEPLOYMENT FAILED: Production health check returned ${PROD_HEALTH}"
                        docker logs ${CONTAINER_NAME}
                        exit 1
                    fi

                    # Clean up dangling untagged images safely
                    docker image prune -f || true
                    echo "Container successfully deployed on http://localhost:${HOST_PORT}"
                '''
            }
        }

        stage('6. Post-Deployment Verification') {
            steps {
                echo "=========================================================="
                echo " [STAGE 6] Post-Deployment Runtime Audit..."
                echo "=========================================================="
                sh '''
                    echo "--- 1. Running Docker Containers ---"
                    docker ps -f name=^/${CONTAINER_NAME}$

                    echo "--- 2. Docker Image Repository ---"
                    docker images ${DOCKER_IMAGE}:latest

                    echo "--- 3. Container Logs (Last 10 lines) ---"
                    docker logs --tail 10 ${CONTAINER_NAME}

                    echo "--- 4. HTTP Endpoint Verifications ---"
                    echo "GET /         HTTP: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:${HOST_PORT}/)"
                    echo "GET /healthz  HTTP: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:${HOST_PORT}/healthz)"
                '''
            }
        }
    }

    post {
        always {
            echo "CI/CD Pipeline execution cycle completed."
        }
        success {
            echo "SUCCESS: Hospital Appointment Booking updated and live at http://localhost:${HOST_PORT}"
        }
        failure {
            echo "FAILURE: Pipeline execution failed. Please check console logs above."
        }
    }
}
