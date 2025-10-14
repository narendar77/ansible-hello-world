pipeline {
  agent {
    docker {
      image 'willhallonline/ansible:latest'
      args '-u root' // Optional: run as root to avoid permission issues
    }
  }
  environment {
    ANSIBLE_LOCAL_TEMP = "${WORKSPACE}/.ansible/tmp"
  }
  stages {
    stage('Run Hello World') {
      steps {
        sh 'mkdir -p $ANSIBLE_LOCAL_TEMP'
        sh 'ansible-playbook ansible/hello.yml -i ansible/inventory'
      }
    }
  }
}
