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
                sh "terraform init -input=false -reconfigure"
                sh "terraform apply -auto-approve"
            }
        }
    }
}      
   
        stage('Deploy to EC2') {
            steps {
                withAWS(credentials: AWS_CRED, region: 'ap-south-1') {
                    sshagent([SSH_KEY]) {
                       script {
                           dir('terraform') {
                            def ec2_ips_json = sh(
                                script: "terraform output -json ec2_public_ip",
                                returnStdout: true
                            ).trim()

                            def ec2_map = readJSON text: ec2_ips_json

                            ['dev','uat','prod'].each { envName ->
                                def ec2_ip = ec2_map[envName]
                                echo "Deploying to ${envName} at ${ec2_ip}"

                                sh "sleep 30"

                                sh """
                                    mkdir -p /var/lib/jenkins/.ssh
                                    ssh-keyscan -H ${ec2_ip} >> /var/lib/jenkins/.ssh/known_hosts || true
                                    chmod 600 /var/lib/jenkins/.ssh/known_hosts
                                """

                                sh "ssh-add -l"
                                sh "ssh -o BatchMode=yes ubuntu@${ec2_ip} whoami"

                                sh """
                                    ssh -o BatchMode=yes ubuntu@${ec2_ip} "
                                    while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
                                        echo 'Waiting for apt lock to be released...'
                                        sleep 30
                                    done

                                    if ! command -v docker &> /dev/null; then
                                        sudo apt-get update -y
                                        sudo apt-get install -y docker.io
                                        sudo usermod -aG docker ubuntu
                                        sudo systemctl enable docker
                                        sudo systemctl start docker
                                    fi

                                    sudo docker stop myapp || true
                                    sudo docker rm -f myapp || true
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