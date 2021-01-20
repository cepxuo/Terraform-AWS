#!/bin/bash
yum -y update
amazon-linux-extras enable php7.4
yum clean metadata
yum -y install httpd php git

rm -rf /var/www/html/
git clone https://github.com/cepxuo/webpage.git /var/www/html
rm -rf /var/www/html/.git

service httpd restart
chkconfig httpd on
