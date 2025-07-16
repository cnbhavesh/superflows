#!/bin/bash

# Kafka Security Setup Script
# This script generates SSL certificates and sets up security configurations

set -e

echo "Setting up Kafka Security..."

# Create directories
mkdir -p ssl-certs
mkdir -p kafka-config

# Generate SSL certificates (self-signed for development)
echo "Generating SSL certificates..."
openssl req -x509 -newkey rsa:4096 -keyout ssl-certs/kafka.key -out ssl-certs/kafka.crt -days 365 -nodes -subj "/CN=kafka.yourdomain.com"

# Generate DH parameters (optional but recommended)
echo "Generating DH parameters..."
openssl dhparam -out ssl-certs/dhparam.pem 2048

# Create .htpasswd file for basic auth (optional)
echo "Creating basic auth file..."
# Default: admin:admin123
echo 'admin:$apr1$8ohUGqnP$MlOzJCLO.KmPVOXqrVczE/' > nginx-config/.htpasswd

# Set proper permissions
chmod 600 ssl-certs/kafka.key
chmod 644 ssl-certs/kafka.crt
chmod 644 ssl-certs/dhparam.pem
chmod 600 nginx-config/.htpasswd

echo "Security setup completed!"
echo ""
echo "SSL Certificate: ssl-certs/kafka.crt"
echo "SSL Key: ssl-certs/kafka.key"
echo "Basic Auth: nginx-config/.htpasswd (admin:admin123)"
echo ""
echo "Remember to:"
echo "1. Replace 'yourdomain.com' with your actual domain"
echo "2. Update DNS records to point to your server"
echo "3. Use Let's Encrypt for production SSL certificates"
echo "4. Change default passwords in production"
echo "5. Configure firewall to allow only required ports"

# Create ACL setup script
cat > kafka-config/setup-acls.sh << 'EOF'
#!/bin/bash

# Setup Kafka ACLs for fine-grained access control
echo "Setting up Kafka ACLs..."

# Wait for Kafka to be ready
sleep 30

# Create topics (if needed)
docker exec -it kafka kafka-topics --create --topic app1-topic --bootstrap-server localhost:29092 --partitions 3 --replication-factor 1 || true
docker exec -it kafka kafka-topics --create --topic app2-topic --bootstrap-server localhost:29092 --partitions 3 --replication-factor 1 || true

# Grant permissions to app1
docker exec -it kafka kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 \
  --add --allow-principal User:app1 --operation Read --operation Write --topic app1-topic

docker exec -it kafka kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 \
  --add --allow-principal User:app1 --operation Read --group app1-consumer-group

# Grant permissions to app2
docker exec -it kafka kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 \
  --add --allow-principal User:app2 --operation Read --operation Write --topic app2-topic

docker exec -it kafka kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 \
  --add --allow-principal User:app2 --operation Read --group app2-consumer-group

# Grant admin permissions
docker exec -it kafka kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 \
  --add --allow-principal User:admin --operation All --resource-type Topic --resource-name '*'

docker exec -it kafka kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 \
  --add --allow-principal User:admin --operation All --resource-type Group --resource-name '*'

echo "ACLs setup completed!"
EOF

chmod +x kafka-config/setup-acls.sh

echo "ACL setup script created: kafka-config/setup-acls.sh"