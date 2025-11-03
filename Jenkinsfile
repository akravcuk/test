pipeline{
  agent any

  environment {
    TOMCAT_WEBAPPS_PATH="/home/user/Downloads/apache-tomcat-9.0.111/webapps"
  }

  stages {

    stage('Check Java version'){
      steps{
        sh'''
          JAVA_VERSION=$(java -version 2>&1 | perl -ne 'print $1 if /version.*?(21)/')

          if [ "$JAVA_VERSION" != "21" ]; then
            echo "Installed Java vesion is: $JAVA_VERSION. Required: 21"
            exit 1
          fi
        '''
      }
    }

    stage('Hello'){
      steps{
        sh'''
          echo 'hello'
        '''
      }
    }


  }
}
