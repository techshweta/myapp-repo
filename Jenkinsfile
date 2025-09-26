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
        IMAGE_NAME = "techshweta/myapp"
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Build WAR and Docker Image') {
            steps {
                sh 'mvn clean package -DskipTests'
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: DOCKERHUB_CRED, usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                        docker push ${IMAGE_NAME}:${BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Provision Infra with Terraform') {
            steps {
                withAWS(credentials: AWS_CRED, region: 'ap-south-1') {
                    dir('terraform') {
                        sh "terraform init"
                        sh "terraform apply -auto-approve"
                    }
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
        sshagent([SSH_KEY]) {
            script {
                // Get Terraform outputs as JSON
                def ec2_ips_json = sh(
                    script: "terraform -chdir=terraform output -json ec2_public_ip",
                    returnStdout: true
                ).trim()
                
                // Parse JSON to map
                def ec2_map = readJSON text: ec2_ips_json

                // Loop through each environment
                ['dev','uat','prod'].each { envName ->
                    def ec2_ip = ec2_map[envName]
                    
                    echo "Deploying to ${envName} at ${ec2_ip}"
                    // Optional: wait for EC2 to be ready
                    sh "sleep 30"

                    //  Debug: check if key is loaded and usable
                    sh "ssh-add -l"
                    sh "ssh -v ubuntu@${ec2_ip} whoami || true"

                    // Actual deployment command
                    // Run commands on EC2
                    sh """
                        ssh -o StrictHostKeyChecking=no ubuntu@${ec2_ip} \\
                        " export PATH=$PATH:/usr/bin:/usr/local/bin && \\
                         sudo docker pull ${IMAGE_NAME}:${BUILD_NUMBER} && \\
                         sudo docker rm -f myapp || true && \\
                         sudo docker run -d --name myapp -p 8080:8080 ${IMAGE_NAME}:${BUILD_NUMBER}"
                    """
                }
            }
        }
    }   
}
    }
}
