#!/bin/bash
yum update -y 
yum install -y httpd
systemctl enable httpd --now
cat > /var/www/html/index.html <<EOF
<h1>Hello World </h1>
<h3> Web Server running on ${server_port} </h3>
EOF

