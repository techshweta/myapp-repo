
## ⚙️ Technologies Used
- Java / Maven  
- Docker  
- Jenkins  
- Terraform  
- AWS EC2 / S3 / DynamoDB

## 🚀 CI/CD Workflow
1. Jenkins pulls the latest code from GitHub  
2. Builds the Maven project (`mvn clean package`)  
3. Builds Docker image and pushes to Docker Hub  
4. Terraform provisions infrastructure on AWS  
5. Docker container as tomcat server  is deployed on EC2

## 🧠 How to Run Locally
```bash
# Clone the repository
git clone https://github.com/techshweta/myapp-repo.git

# Navigate into the project directory
cd myapp-repo

# Build using Maven
mvn clean package

# Build Docker image
docker build -t myapp .

# Run container
docker run -p 8080:8080 myapp

# Run container
docker run -p 8080:8080 myapp
