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
        BUILD_NUMBER = "${env.BUILD_NUMBER}"// Docker tag / build number
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
                    sh "sleep 30" // Optional wait for EC2 to be ready

                    // Add EC2 host key to known_hosts safely
                    sh """
                        ssh-keyscan -H ${ec2_ip} >> /var/lib/jenkins/.ssh/known_hosts || true
                        chmod 600 /var/lib/jenkins/.ssh/known_hosts
                    """

                    // Debug: list loaded keys
                    sh "ssh-add -l"

                    // Test SSH connection
                    sh "ssh -o BatchMode=yes ubuntu@${ec2_ip} whoami"

                    // Actual deployment command
                     
                    sh """
                    ssh -o BatchMode=yes ubuntu@${ec2_ip} \\
                        "env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin docker pull ${IMAGE_NAME}:${BUILD_NUMBER} && \\
                         env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin docker rm -f myapp || true && \\
                         env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin docker run -d --name myapp -p 8080:8080 ${IMAGE_NAME}:${BUILD_NUMBER}"
                    """
                }
            }
        }
    }
}
    }
}