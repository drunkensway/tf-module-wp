#!/bin/bash

yum update -y
yum install httpd php php-mysql -y

cd /var/www/html
wget https://wordpress.org/wordpress-5.1.1.tar.gz
tar -xzf wordpress-5.1.1.tar.gz
cp -r wordpress/* /var/www/html/
rm -rf wordpress
rm -rf wordpress-5.1.1.tar.gz
chmod -R 755 wp-content
chown -R apache:apache wp-content
chkconfig httpd on
service httpd start

aws s3 sync s3://blog-app-2021-wp-content /var/www/html
aws s3 sync s3://alexanderrochettetest/ /etc/httpd/conf

service httpd restart

echo "*/5 * * * * /bin/aws s3 sync /var/www/html s3://blog-app-2021-wp-content" >> /var/spool/cron/root