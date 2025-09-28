# Start from official Tomcat base image
FROM tomcat:9.0-jdk17-openjdk

# Remove default ROOT app
RUN rm -rf /usr/local/tomcat/webapps/*

# Create tomcat user and group
RUN groupadd -r tomcat && useradd -r -g tomcat tomcat

# Copy your WAR file into Tomcat webapps
COPY target/*.war /usr/local/tomcat/webapps/ROOT.war

# Fix permissions so Tomcat can read/deploy it
RUN chown -R tomcat:tomcat /usr/local/tomcat/webapps \
    && chmod -R 755 /usr/local/tomcat/webapps

# Switch to tomcat user
USER tomcat

# Expose Tomcat port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
