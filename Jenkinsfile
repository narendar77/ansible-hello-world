pipeline {
  agent {
    docker {
      image 'willhallonline/ansible:latest'
    }
  }
  stages {
    stage('Run Hello World') {
      steps {
        sh 'ansible-playbook ansible/hello.yml -i ansible/inventory'
      }
    }
  }
}
