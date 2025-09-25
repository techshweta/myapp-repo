# Start from official Tomcat base image
FROM tomcat:9.0-jdk11-openjdk

# Remove default ROOT app
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy your WAR file into Tomcat webapps
# If using Maven, Jenkins will produce target/myapp.war
COPY target/*.war /usr/local/tomcat/webapps/ROOT.war

# Expose Tomcat port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
