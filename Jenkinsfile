pipeline {
    agent any
    tools {
        maven '3.9'
        jdk 'OpenJDK-17'
    }
    environment {
        AWS_CRED = 'aws-cred'
        DOCKERHUB_CRED = 'dockerhub-cred'
        SSH_KEY = 'ec2-key'
        REGISTRY = "docker.io"
        TAG = "${env.BUILD_NUMBER}"// Docker tag / build number
        IMAGE_NAME = "techshweta/myapp"
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Build WAR and Docker Image') {
            steps {
                sh 'mvn clean package -DskipTests'
                sh "docker build -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: DOCKERHUB_CRED, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                        docker push ${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Provision Infra with Terraform') {
    steps {
        withAWS(credentials: AWS_CRED, region: 'ap-south-1') {
            dir('terraform') {
                script {
                    // Loop through each environment
                    ['dev', 'uat', 'prod'].each { envName ->
                        echo "Provisioning environment: ${envName}"

                        // Initialize Terraform with backend key specific to env
                        sh """
                           terraform init -input=false -reconfigure -force-copy \
                           -backend-config="key=infra/${envName}/terraform.tfstate"
                        """

                        // Select or create workspace
                        sh "terraform workspace new ${envName} || terraform workspace select ${envName}"

                        // Apply Terraform
                        sh "terraform apply -auto-approve"
                    }
                }
            }
        }
    }
}
   
        stage('Deploy to EC2') {
     steps {
                withAWS(credentials: AWS_CRED, region: 'ap-south-1') {
                    dir('terraform') {
                        script {
                            ['dev','uat','prod'].each { envName ->
                                echo "Fetching output for ${envName}"

                                // Ensure workspace is selected
                                sh "terraform workspace select ${envName}"

                                // Get Terraform output (per workspace)
                                def ec2_ip = sh(
                                    script: "terraform output -raw ec2_public_ip",
                                    returnStdout: true
                                ).trim()

                                echo "Deploying to ${envName} at ${ec2_ip}"

                                sh "sleep 30" // Optional wait for EC2 to be ready

                                // Add EC2 host key to known_hosts safely
                                sh """
                                    mkdir -p /var/lib/jenkins/.ssh
                                    ssh-keyscan -H ${ec2_ip} >> /var/lib/jenkins/.ssh/known_hosts || true
                                    chmod 600 /var/lib/jenkins/.ssh/known_hosts
                                """

                                // SSH deployment
                                sshagent([SSH_KEY]) {
                                    sh """
                                        ssh -o BatchMode=yes ubuntu@${ec2_ip} "
                                        # Wait for any apt locks
                                        while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
                                            echo 'Waiting for apt lock...'
                                            sleep 10
                                        done

                                        # Install Docker if missing
                                        if ! command -v docker &> /dev/null; then
                                            sudo apt-get update -y
                                            sudo apt-get install -y docker.io
                                            sudo usermod -aG docker ubuntu
                                            sudo systemctl enable docker
                                            sudo systemctl start docker
                                        fi

                                        # Stop & remove old container
                                        sudo docker stop myapp || true
                                        sudo docker rm -f myapp || true

                                        # Pull latest image & run
                                        sudo docker pull ${IMAGE_NAME}:latest
                                        sudo docker run -d --name myapp -p 8081:8080 ${IMAGE_NAME}:latest
                                        "
                                    """
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}