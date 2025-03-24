#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y
# Installing Nginx
sudo apt-get install -y nginx
# Installing Node.js
curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install nodejs -y
# Installing PM2
sudo npm i -g pm2
cd /home/ubuntu
mkdir nodeapp
mkdir backend
# Checking out from Version Control
git clone https://github.com/mmdcloud/aws-view-analytics
cd aws-view-analytics/frontend
cp -r . /home/ubuntu/nodeapp/
cd /home/ubuntu/nodeapp/
# Copying Nginx config
cp /home/ubuntu/aws-view-analytics/terraform/scripts/default /etc/nginx/sites-available/
# Installing dependencies
sudo npm i
sudo chmod 755 /home/ubuntu
# Building the project
sudo npm run build
# Starting PM2 app
cp -r /home/ubuntu/aws-view-analytics/backend/* /home/ubuntu/backend/
cd /home/ubuntu/backend
sudo npm i
sudo pm2 start server.js
sudo service nginx restart