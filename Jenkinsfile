pipeline{
  agent any

  environment {
    TOMCAT_HOME
    TOMCAT_WEBAPPS_PATH="/home/user/Downloads/apache-tomcat-9.0.111/webapps"
  }

  stages {

    stage('Make standard infrastructure checks before build'){
      steps{
        sh'''
          JAVA_VERSION=$(java -version 2>&1 | perl -ne 'print $1 if /version.*?(21)/')

          if [ "$JAVA_VERSION" != "21" ]; then
            echo "Installed Java vesion is: $JAVA_VERSION. Required: 21"
            exit 1
          else
            echo "Installed Java vesion is: $JAVA_VERSION and this is compliant. Continue"
          fi
        '''

        sh'''
          echo "Check is TOMCAT_HOME variable set"

          if [ -z "$TOMCAT_HOME" ]; then
            echo "TOMCAT_HOME is not set"
            exit 1
          else
            echo "TOMCAT_HOME is set: ${TOMCAT_HOME}"
          fi
        '''
      }
    }

    // stage('Build'){
    //   steps{
    //     sh'''
    //       cd app
    //       javac -cp "$TOMCAT_HOME/lib/servlet-api.jar" HelloServlet.java
    //     '''
    //   }
    // }


  }
}
