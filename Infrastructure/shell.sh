#!/bin/bash
set -euxo pipefail

# Log everything to /var/log/user-data.log
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Function to wait for Jenkins to be ready
function wait_for_jenkins() {
    local url=$1
    echo "Waiting for Jenkins to be ready at $url..."
    until curl -sL -w "%{http_code}" "$url" -o /dev/null | grep -q "200"; do
        sleep 5
    done
    echo "Jenkins is ready!"
}

## Public IP as a variable
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")" -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Public IP: $PUBLIC_IP"

# Update package list and upgrade system
sudo apt update && sudo apt upgrade -y

# Install necessary dependencies
sudo apt install -y fontconfig openjdk-17-jre wget

# Verify Java installation
java -version

# Add Jenkins repository key
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

# Add Jenkins repository
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list again after adding Jenkins repo
sudo apt update

# Install Jenkins
sudo apt install -y jenkins

# Enable and start Jenkins service
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Provide Jenkins user with sudo privileges
echo "Granting Jenkins user sudo privileges..."
sudo usermod -aG sudo jenkins
sudo bash -c "echo 'jenkins ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/jenkins"

# Wait for Jenkins to fully start
#wait_for_jenkins "http://$PUBLIC_IP:8080"

# Extract initial admin password
JENKINS_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Jenkins initial password: $JENKINS_PASSWORD"

# Download Jenkins CLI
wget http://$PUBLIC_IP:8080/jnlpJars/jenkins-cli.jar -P ~

# Create a new Jenkins admin user (modify USERNAME & PASSWORD as needed)
USERNAME="admin"
PASSWORD="admin123"
FULLNAME="Admin User"
EMAIL="vigneshs00@outlook.com"

# Configure Jenkins using CLI
echo "Creating Jenkins admin user..."
echo "jenkins.model.Jenkins.instance.securityRealm.createAccount('$USERNAME', '$PASSWORD')" | \
    java -jar ~/jenkins-cli.jar -s http://$PUBLIC_IP:8080/ -auth admin:$JENKINS_PASSWORD groovy =

# Disable Jenkins setup wizard
echo "Disabling Jenkins setup wizard..."
sudo bash -c 'echo "jenkins.install.runSetupWizard=false" >> /etc/default/jenkins'
sudo systemctl restart jenkins

# Configure Jenkins URL
JENKINS_URL="http://$PUBLIC_IP:8080"
echo "Configuring Jenkins URL to $JENKINS_URL..."
JENKINS_CONFIG_XML="/var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml"

sudo bash -c "cat <<EOF > $JENKINS_CONFIG_XML
<?xml version='1.1' encoding='UTF-8'?>
<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>vigneshs00@outlook.com</adminAddress>
  <jenkinsUrl>$JENKINS_URL</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>
EOF"

# Restart Jenkins to apply configuration changes
sudo systemctl restart jenkins

echo "Jenkins installation, plugin setup, and URL configuration complete!"
echo "Login with Username: $USERNAME and Password: $PASSWORD"

# Install Jenkins Plugins via Jenkins API
url="http://$PUBLIC_IP:8080"
user="admin"
password="admin123"

cookie_jar="$(mktemp)"
full_crumb=$(curl -u "$user:$password" --cookie-jar "$cookie_jar" $url/crumbIssuer/api/xml?xpath=concat\(//crumbRequestField,%22:%22,//crumb\))
arr_crumb=(${full_crumb//:/ })
only_crumb=$(echo ${arr_crumb[1]})

# Make the request to download and install required modules
echo "Installing Jenkins plugins..."
curl -X POST -u "$user:$password" $url/pluginManager/installPlugins \
  -H 'Connection: keep-alive' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H "$full_crumb" \
  -H 'Content-Type: application/json' \
  -H 'Accept-Language: en,en-US;q=0.9,it;q=0.8' \
  --cookie $cookie_jar \
  --data-raw "{
    'dynamicLoad':true,
    'plugins':[
        'cloudbees-folder', 'antisamy-markup-formatter', 'build-timeout', 'credentials-binding',
        'timestamper', 'ws-cleanup', 'ant', 'gradle', 'workflow-aggregator', 'github-branch-source',
        'pipeline-github-lib', 'pipeline-stage-view', 'git', 'ssh-slaves', 'matrix-auth', 'pam-auth',
        'ldap', 'email-ext', 'mailer'
    ],
    'Jenkins-Crumb':'$only_crumb'
  }"

echo "Jenkins setup and plugin installation complete!"
