# Start from official Tomcat base image
FROM tomcat:9.0-jdk11-openjdk

# Remove default ROOT app
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy your WAR file into Tomcat webapps
# If using Maven, Jenkins will produce target/myapp.war
COPY target/*.war /usr/local/tomcat/webapps/ROOT.war

# Fix permissions so Tomcat can read/deploy it
RUN chown -R tomcat:tomcat /usr/local/tomcat/webapps

# Expose Tomcat port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
