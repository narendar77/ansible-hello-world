pipeline {
  agent {
    docker {
      image 'willhallonline/ansible:latest'
      args '-u root' // Optional: run as root to avoid permission issues
    }
  }
  environment {
    ANSIBLE_LOCAL_TEMP = "${WORKSPACE}/.ansible/tmp"
    PROXMOX_PASSWORD = credentials('proxmox-password') // Jenkins credential ID
  }
  stages {
    stage('Install Dependencies') {
      steps {
        sh 'mkdir -p $ANSIBLE_LOCAL_TEMP'
        sh 'pip install proxmoxer requests'
        sh 'ansible-galaxy collection install -r ansible/requirements.yml'
      }
    }
    stage('Run Hello World') {
      steps {
        sh 'ansible-playbook ansible/hello.yml -i ansible/inventory'
      }
    }
    stage('Create Proxmox VMs') {
      steps {
        script {
          // Add SSH key for Proxmox host if needed
          sh '''
            mkdir -p ~/.ssh
            # Uncomment and configure if using SSH key authentication
            # echo "$PROXMOX_SSH_KEY" > ~/.ssh/id_rsa
            # chmod 600 ~/.ssh/id_rsa
            # ssh-keyscan -H 192.168.1.10 >> ~/.ssh/known_hosts
          '''
        }
        sh 'ansible-playbook ansible/create_vms.yml -i ansible/inventory -v'
      }
    }
  }
  post {
    success {
      echo 'VMs created successfully!'
    }
    failure {
      echo 'Failed to create VMs. Check the logs for details.'
    }
  }
}
