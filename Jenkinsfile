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

        sh'''
          echo "Check if folder with JAVA application exists"
          if [ -d "$JAVA_SERVLET_FILE_LOCATION" ]; then
            echo "$JAVA_SERVLET_FILE_LOCATION is present. OK"
          else
            echo "$JAVA_SERVLET_FILE_LOCATION is missing"
            exit 1
          fi
        '''
      }
    }

    // stage('Build'){
    //   steps{
    //     sh'''
    //       echo "Compile"
          
    //       javac -cp "./app/javax.servlet-api-4.0.1.jar" "${JAVA_SERVLET_FILE_LOCATION}/${JAVA_SERVLET_FILENAME}"
    //       if [ $? -ne 0 ]; then
    //         echo "Compilation error"
    //         exit 1
    //       fi
    //     '''
    //   }
    // }
    stage('Deploy'){
      steps{
        sh'''
          SERVLET_FULL_NAME="$TOMCAT_WEBAPPS_PATH/$SERVLET_FOLDER_NAME"
          if [ -d "$SERVLET_FULL_NAME" ]; then
            rm -rf $SERVLET_FULL_NAME" && mkdir $SERVLET_FULL_NAME"
          else
            mkdir $SERVLET_FULL_NAME
            cp -r ./app/hello-tomcat/* $SERVLET_FULL_NAME/
        '''
      }
    }
    // stage('Deploy'){
    //   steps{
    //     sh'''
    //       cd ./app/hello-tomcat

    //       jar -cvf $JAVA_APP_WAR_FILENAME .

    //       if [ $? -ne 0 ]; then
    //         echo "Packing to jar error"
    //         exit 1
    //       fi

    //       mv ./$JAVA_APP_WAR_FILENAME $TOMCAT_WEBAPPS_PATH/
    //     '''
    //   }
    // }

    // stage('Test application endpoint'){
    //   steps{
    //     // Check service availability. Implement retry-pattern
    //     sh'''
    //       URL="http://localhost:8080/hello"
    //       MAX_RETRY_TIMES=3
    //       DELAY_SECONDS=5


    //       for i in $(seq 1 $MAX_RETRY_TIMES); do
    //         HTTP_CODE=$(/usr/bin/curl -Lso /dev/null -w "%{http_code}" http://localhost:8080/hello)

    //         if [ $HTTP_CODE -eq 200 ]; then
    //           echo "Service is UP"
    //           exit 0
    //         fi
    //         echo "Retrying in ${DELAY_SECONDS} seconds..."
    //         sleep $DELAY_SECONDS
    //       done

    //       echo "Service is not available. Attempts: $MAX_RETRY_TIMES. HTTP CODE: $HTTP_CODE"
    //       exit 1
    //     '''
    //   }
    // }
  }
}
