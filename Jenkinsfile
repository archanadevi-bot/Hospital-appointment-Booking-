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
        // Triggers build automatically on GitHub push webhook
        githubPush()
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo "===> Checking out code from Git repository..."
                checkout scm
                script {
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Commit Hash: ${sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()}"
                }
            }
        }

        stage('2. Static Validation') {
            steps {
                echo "===> Validating required frontend files and asset integrity..."
                sh '''
                    echo "Verifying core files..."
                    test -f index.html || { echo "Missing index.html"; exit 1; }
                    test -f doctors.html || { echo "Missing doctors.html"; exit 1; }
                    test -f booking.html || { echo "Missing booking.html"; exit 1; }
                    test -f confirmation.html || { echo "Missing confirmation.html"; exit 1; }
                    test -f style.css || { echo "Missing style.css"; exit 1; }
                    test -f app.js || { echo "Missing app.js"; exit 1; }
                    test -f nginx.conf || { echo "Missing nginx.conf"; exit 1; }
                    test -f Dockerfile || { echo "Missing Dockerfile"; exit 1; }
                    echo "All core files are present."
                '''
            }
        }

        stage('3. Build Docker Image') {
            steps {
                echo "===> Building Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG} and ${DOCKER_IMAGE}:latest..."
                sh '''
                    docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} -t ${DOCKER_IMAGE}:latest .
                '''
            }
        }

        stage('4. Test & Verification') {
            steps {
                echo "===> Starting temporary container for smoke and health verification..."
                sh '''
                    # Clean up any lingering test container
                    docker rm -f ${DOCKER_IMAGE}-test || true

                    # Run container on isolated test port
                    docker run -d --name ${DOCKER_IMAGE}-test -p ${TEST_PORT}:80 ${DOCKER_IMAGE}:${IMAGE_TAG}

                    # Wait for Nginx to initialize
                    sleep 3

                    # Check healthz endpoint
                    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/healthz)
                    echo "Healthz HTTP status: ${HEALTH_STATUS}"
                    if [ "$HEALTH_STATUS" -ne 200 ]; then
                        echo "Health check failed!"
                        docker logs ${DOCKER_IMAGE}-test
                        docker rm -f ${DOCKER_IMAGE}-test
                        exit 1
                    fi

                    # Verify main landing page
                    INDEX_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/index.html)
                    echo "Index.html HTTP status: ${INDEX_STATUS}"
                    if [ "$INDEX_STATUS" -ne 200 ]; then
                        echo "Landing page check failed!"
                        docker rm -f ${DOCKER_IMAGE}-test
                        exit 1
                    fi

                    # Clean up test container
                    docker rm -f ${DOCKER_IMAGE}-test
                    echo "Smoke tests passed successfully!"
                '''
            }
        }

        stage('5. Deploy Container') {
            steps {
                echo "===> Deploying updated container to production environment..."
                sh '''
                    # Stop and remove previous running container if present
                    if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
                        echo "Stopping running container ${CONTAINER_NAME}..."
                        docker stop ${CONTAINER_NAME}
                    fi

                    if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
                        echo "Removing previous container ${CONTAINER_NAME}..."
                        docker rm ${CONTAINER_NAME}
                    fi

                    # Run new container
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --restart unless-stopped \
                        -p ${HOST_PORT}:80 \
                        ${DOCKER_IMAGE}:latest

                    echo "Application deployed and running on port ${HOST_PORT}"
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline run completed."
        }
        success {
            echo "CI/CD Pipeline executed successfully! Hospital Appointment Booking is live."
        }
        failure {
            echo "Pipeline failed! Please check logs for debugging."
        }
    }
}

