pipeline {
    agent any

    environment {
        IMAGE_NAME = "hello-world-app"
        CONTAINER_NAME = "hello-world-container"
        PORT = "5000"
    }

    stages {
        stage('Clone Repository') {
            steps {
                git url: 'https://github.com/rishugkp688/python_jenkins_demo.git', branch: 'main'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $IMAGE_NAME .'
            }
        }

        stage('Stop and Remove Existing Container') {
            steps {
                script {
                    sh """
                        if [ \$(docker ps -q -f name=$CONTAINER_NAME) ]; then
                            docker stop $CONTAINER_NAME
                        fi
                        if [ \$(docker ps -a -q -f name=$CONTAINER_NAME) ]; then
                            docker rm $CONTAINER_NAME
                        fi
                    """
                }
            }
        }

        stage('Run New Container') {
            steps {
                sh 'docker run -d -p $PORT:5000 --name $CONTAINER_NAME $IMAGE_NAME'
            }
        }

        stage('Health Check') {
            steps {
                echo "Waiting 5s for app to start..."
                sleep time: 5, unit: 'SECONDS'
                sh "curl -f http://localhost:$PORT || (echo 'Health check failed!' && exit 1)"
            }
        }
    }

    post {
        success {
            echo "✅ Deployment successful: App is running on port $PORT"
        }
        failure {
            echo "❌ Deployment failed. Check logs above."
        }
        always {
            echo "📦 Jenkins build #${env.BUILD_NUMBER} completed at ${env.BUILD_TIMESTAMP}"
        }
    }
}
