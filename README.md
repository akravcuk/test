# Allianz test task

## Setup
* Ubuntu 22.04 LTS (or similar) running on AWS/EC2
* Apache HTTP Server installed and configured to act as a reverse proxy
* Apache Tomcat 9 installed, with a simple “ROOT” webapp deployed
* The web application currently returns an HTTP 503 error
* Apache listens only on port 80

## 1. Task Findings & Fixes
*Question:*
* What you discovered, how you analysed the issue, and how you
approached fixing it.
* Explain any improvements or adjustments you made.

*Answer:*

**Discovery:**
The Application (a servlet) which is deployed on Apache Tomcat server uses Java System Property which is set server-wide (globally in scope of a server) as the argument for server startup. This leads to the issue that toggling this property needs a server restart which leads to service disruption.

**Finding the issue:**
1. Make sure what service is listening
```sh
sudo ss -tunlp

# we get 80 and 8080 ports, as it's being stated in setup
# 80 - is for apache web-server which is in reverse-proxy mode
# 8080 - is for Tomcat
```

2. Check the url
2.1 Check the url through recerse proxy
```sh
curl -L http://localhost
# Answer is HTTP 503
```

2.2 Check the url directly to Tomcat
```sh
curl -L http://localhost:8080

# The same answer is HTTP 503
# 
# That means, that Apache works and we need to focus on the application server or deployed application.
```

3. Check Tomcat logs
3.1 Find where tomcat is
```sh
ps aux | grep tomcat
```

3.2 What is runing on this Application server?
```sh
cd /var/lib/tomcat9/webapps
```

3.3 check the content
```sh
cat ROOT/index.jsp

Context env = (Context) new InitialContext().lookup("java:comp/env");
Boolean maintenance = (Boolean) env.lookup("maintenance");

if (Boolean.TRUE.equals(maintenance)) {
    response.setStatus(503);
    response.setHeader("X-Maintenance","on");
```

# Aha! This is a property. So, this is not a backend or middleware problem

3.4 Check Tomcat logs just in case
```sh
tail -n 100 /var/lib/tomcat9/logs/catalina.log

catalina.2025-11-02.log:02-Nov-2025 21:44:00.884 INFO [main] org.apache.catalina.startup.VersionLoggerListener.log Command line argument: -DMAINTENANCE=1
catalina.2025-11-02.log:02-Nov-2025 21:44:08.038 INFO [main] org.apache.catalina.startup.VersionLoggerListener.log Command line argument: -DMAINTENANCE=1
catalina.2025-11-03.log:03-Nov-2025 16:57:52.489 INFO [main] org.apache.catalina.startup.VersionLoggerListener.log Command line argument: -DMAINTENANCE=1
catalina.out:[2025-11-02 21:44:00] [info] Command line argument: -DMAINTENANCE=1
catalina.out:[2025-11-02 21:44:08] [info] Command line argument: -DMAINTENANCE=1
catalina.out:[2025-11-03 16:57:52] [info] Command line argument: -DMAINTENANCE=1
```
# And this is correct: the message is INFO (neither CRITICAL nor ERROR)

**Aproach to fixing***

3.5 Is it started by SystemD?
```sh
systemctl list-units --type=service --no-pager --state=running | grep tomcat
```

3.6 Get more info about the service
```sh
sudo systemctl status tomcat9

● tomcat9.service - Apache Tomcat 9 Web Application Server
     Loaded: loaded (/lib/systemd/system/tomcat9.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/tomcat9.service.d
             └─env.conf

```

3.7 Check this one first
```sh
cat /etc/systemd/system/tomcat9.service.d/env.conf
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -DMAINTENANCE=1"
```

3.8 Change the status to 0 and restart the server. No effect. Revert


3.9 Check another parameter
```sh
cat /lib/systemd/system/tomcat9.service

# ...
# Lifecycle
# ...
ExecStart=/bin/sh /usr/libexec/tomcat9/tomcat-start.sh			#### <<--- Check this file, because this file is for start and has ENVS!
```

3.10 Check this file
```sh
cat /usr/libexec/tomcat9/tomcat-start.sh
#!/bin/sh
#
# Startup script for Apache Tomcat with systemd
#
# ...
. /etc/default/tomcat9 ####  <<---- Service settings. Go here
```


3.11 Check this file
```sh
cat  /etc/default/tomcat9

# Set MAINTENANCE=1 so app returns 503 (intentional for exercise). Change to 0 to return 200.
# Changed by Andriy Kravchuk 03.10.2025, 18:39
# MAINTENANCE=1 -> MAINTENANCE=0
# JAVA_OPTS="-Djava.awt.headless=true -DMAINTENANCE=1"
JAVA_OPTS="-Djava.awt.headless=true -DMAINTENANCE=0"
```

4. Restart and check
```sh
sudo systemct restart tomcat9
journalctl -f -u tomcat9
curl -L http://localhost:8080
```

**Explain any improvements or adjustments you made.**
1. Change to application or microservice maintenance status toggle approach from server-wide to microservice-wide.
1.1 Add context file: ./META-INF/context.xml
```xml
<Context>
    <Environment name="maintenance" type="java.lang.Boolean" value="false" override="false"/>
</Context>
```
1.2 Application code is:
```java
Context env = (Context) new InitialContext().lookup("java:comp/env");
Boolean maintenance = (Boolean) env.lookup("maintenance");
```
1.3 How to toggle the status "false" to "true".
## It's easy with XPATH!

```sh
xmlstarlet \
    ed \
    --inplace \
    -u '//Environment[@name="maintenance"]/@value' \
    -v 'false' \
    ./context.xml
```

2. Change the deployment approach
2.1 Install Jenkins + Compatible Java
2.1.1 Prepare
```sh

# add user for jenkins
sudo useradd -r -s /sbin/nologin deploy

# It has to have rights to deploy, so let's add jenkins to "tomcat" group
sudo usermod -aG tomcat deploy

# Any new folders/files will inherit rights from webapps folder except the group
# Jenkins can deploy here to this folder
sudo setfacl -R -d -m u:tomcat:rwx,g:tomcat:rwx webapps/

# put everything in /opt/deploy
chown -R deploy:deploy /opt/deploy

# make a script to start Jenkins. in Prod it's SystemD service of course
cat ./start-jenkins.sh
#!/bin/bash

export JENKINS_HOME=/opt/deploy

./jdk-21.0.9/bin/java \
        -jar ./jenkins.war \
        --httpPort=8888 \
        --httpListenAddress=localhost \
        --prefix=/jenkins

# Make it available from outside - as we don't need the access to VM
# This is LAB, so in prod it's HTTPS of course

vi /etc/apache2/sites-enabled/010-proxy-tomcat.conf
<VirtualHost *:80>
  ServerName _
  ProxyPreserveHost On
  RequestHeader set X-Forwarded-Proto "http"
  RequestHeader set X-Maintenance "on"

  # Jenkins
  ProxyPass         /jenkins http://127.0.0.1:8888/jenkins
  ProxyPassReverse  /jenkins http://127.0.0.1:8888/jenkins


  ProxyPass        /  http://127.0.0.1:8080/
  ProxyPassReverse /  http://127.0.0.1:8080/

  ErrorLog  ${APACHE_LOG_DIR}/tomcat-proxy-error.log
  CustomLog ${APACHE_LOG_DIR}/tomcat-proxy-access.log combined
</VirtualHost>

```
2.2  Setup a pipeline in Jenkins

2.2.1 This Pipeline if for product lifecycle

```
In jenkins
new item \ pipeline

Pipeline from the SCM
Repository URL: https://github.com/akravcuk/test
Branch Specifier: */main
```

2.2.2 This pipeline is for maintenance (can be extended)

New item \ pipeline \pipeline from the Pipeline script (not SCM)

## Summary
### Once we need to deploy the application we change the maintenance mode with Jenkins script

### Pipelines

### App lifecycle
```sh
pipeline{
  agent any

  environment {
    JAVA_VERSION_REQUIRED = "11"
    TOMCAT_WEBAPPS_PATH="/var/lib/tomcat9/webapps"
    SERVLET_FOLDER_NAME="hello"
  }

  stages {

    stage('Make standard infrastructure checks before build'){
      steps{
        sh'''
          JAVA_VERSION=$(java -version 2>&1 | perl -ne 'print $1 if /version.*?(11)/')

          if [ "$JAVA_VERSION" != "$JAVA_VERSION_REQUIRED" ]; then
            echo "Installed Java vesion is: $JAVA_VERSION. Required: JAVA_VERSION_REQUIRED"
            exit 1
          else
            echo "Installed Java vesion is: $JAVA_VERSION and this is compliant. Continue"
          fi
        '''
      }
    }


    stage('Deploy'){
      steps{
        sh'''
          SERVLET_FULL_NAME="$TOMCAT_WEBAPPS_PATH/$SERVLET_FOLDER_NAME"

          if [ -d "$SERVLET_FULL_NAME" ]; then
            rm -rf "$SERVLET_FULL_NAME"
          fi

          if [ ! -d "$SERVLET_FULL_NAME" ]; then
            mkdir $SERVLET_FULL_NAME
          else
            echo "Can't create servlet directory: $SERVLET_FULL_NAME"
            exit 1
          fi

          cp -r ./app/hello-tomcat/* $SERVLET_FULL_NAME/
          
        '''
      }
    }

    stage('Test application endpoint'){
      steps{
        // Check service availability. Implement retry-pattern
        sh'''
          URL="http://localhost:8080/hello"
          MAX_RETRY_TIMES=5
          DELAY_SECONDS=10


          for i in $(seq 1 $MAX_RETRY_TIMES); do
            HTTP_CODE=$(/usr/bin/curl -Lso /dev/null -w "%{http_code}" http://localhost:8080/hello)

            if [ $HTTP_CODE -eq 200 ]; then
              echo "Service is UP"
              exit 0
            fi
            echo "Retrying in ${DELAY_SECONDS} seconds..."
            sleep $DELAY_SECONDS
          done

          echo "Service is not available. Attempts: $MAX_RETRY_TIMES. HTTP CODE: $HTTP_CODE"
          exit 1
        '''
      }
    }
  }
}
```
## App maintenance
```sh
environment{
    TOMCAT_WEBAPPS_PATH="/var/lib/tomcat9/webapps/META-INF/context.xml"
}
pipeline {
    agent any

    stages {
        stage('Maintenance-on') {
            steps {
                sh '''
                    /usr/bin/xmlstarlet \
                        ed \
                        --inplace \
                        -u '//Environment[@name="maintenance"]/@value' \
                        -v 'false' \
                        ./$TOMCAT_WEBAPPS_PATH
                '''
            }
        }
    }
}
```


