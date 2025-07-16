#!/bin/bash

# Script to integrate Kafka with existing Docker Compose setup

set -e

echo "Integrating Kafka with existing Docker Compose setup..."

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found"
    exit 1
fi

# Backup existing docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup
echo "✅ Backed up existing docker-compose.yml"

# Add Kafka services to existing docker-compose.yml
cat >> docker-compose.yml << 'EOF'

  # Kafka Services
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.3
    container_name: zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"
    volumes:
      - zookeeper_data:/var/lib/zookeeper/data
      - zookeeper_logs:/var/lib/zookeeper/log
    networks:
      - superflows

  kafka:
    image: confluentinc/cp-kafka:7.4.3
    container_name: kafka
    depends_on:
      - zookeeper
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092,EXTERNAL://kafka.yourdomain.com:9093
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT,EXTERNAL:SASL_PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_SASL_ENABLED_MECHANISMS: PLAIN
      KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL: PLAIN
      KAFKA_OPTS: "-Djava.security.auth.login.config=/etc/kafka/kafka_server_jaas.conf"
      KAFKA_SECURITY_INTER_BROKER_PROTOCOL: SASL_PLAINTEXT
    ports:
      - "9092:9092"
      - "9093:9093"
      - "9101:9101"
    volumes:
      - kafka_data:/var/lib/kafka/data
      - ./kafka-config/kafka_server_jaas.conf:/etc/kafka/kafka_server_jaas.conf
    networks:
      - superflows

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on:
      - kafka
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
      KAFKA_CLUSTERS_0_ZOOKEEPER: zookeeper:2181
    networks:
      - superflows

EOF

# Add volumes to existing docker-compose.yml
echo "" >> docker-compose.yml
echo "volumes:" >> docker-compose.yml
echo "  zookeeper_data:" >> docker-compose.yml
echo "  zookeeper_logs:" >> docker-compose.yml
echo "  kafka_data:" >> docker-compose.yml

echo "✅ Added Kafka services to docker-compose.yml"

# Setup security
echo "Setting up security configuration..."
./setup-kafka-security.sh

# Add environment variables to .env file
if [ -f ".env" ]; then
    echo "" >> .env
    echo "# Kafka Configuration" >> .env
    echo "KAFKA_DOMAIN=kafka.yourdomain.com" >> .env
    echo "KAFKA_UI_DOMAIN=kafka-ui.yourdomain.com" >> .env
    echo "✅ Added Kafka environment variables to .env"
fi

# Create start script
cat > start-kafka.sh << 'EOF'
#!/bin/bash

echo "Starting Kafka services..."

# Start all services
docker-compose up -d

# Wait for Kafka to be ready
echo "Waiting for Kafka to be ready..."
sleep 30

# Setup ACLs
echo "Setting up ACLs..."
./kafka-config/setup-acls.sh

echo "✅ Kafka setup complete!"
echo ""
echo "Access points:"
echo "- Kafka: kafka.yourdomain.com:9093"
echo "- Kafka UI: https://kafka-ui.yourdomain.com"
echo "- Local Kafka: localhost:9092"
echo "- Local Kafka UI: http://localhost:8080"
echo ""
echo "Next steps:"
echo "1. Update your domain in all config files"
echo "2. Setup DNS records"
echo "3. Configure SSL certificates for production"
echo "4. Test client connections"
EOF

chmod +x start-kafka.sh

echo "✅ Created start-kafka.sh script"

# Create nginx configuration for existing setup
cat > nginx-kafka-addon.conf << 'EOF'
# Add this to your existing nginx configuration

# Kafka TCP Proxy
stream {
    upstream kafka_backend {
        server localhost:9093;
    }

    server {
        listen 9093;
        proxy_pass kafka_backend;
        proxy_timeout 1s;
        proxy_responses 1;
    }
}

# Kafka UI HTTP Proxy (add to your existing http block)
server {
    listen 443 ssl http2;
    server_name kafka-ui.yourdomain.com;
    
    # Use your existing SSL configuration
    ssl_certificate /path/to/your/ssl/cert.pem;
    ssl_certificate_key /path/to/your/ssl/key.pem;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "✅ Created nginx-kafka-addon.conf"

echo ""
echo "🎉 Kafka integration complete!"
echo ""
echo "Files created:"
echo "- docker-compose.yml (updated with Kafka services)"
echo "- kafka-config/ (directory with security configuration)"
echo "- nginx-config/ (directory with nginx configuration)"
echo "- ssl-certs/ (directory for SSL certificates)"
echo "- start-kafka.sh (startup script)"
echo "- nginx-kafka-addon.conf (nginx configuration to add)"
echo ""
echo "To start Kafka:"
echo "1. Update 'yourdomain.com' in all configuration files"
echo "2. Run: ./start-kafka.sh"
echo "3. Add nginx-kafka-addon.conf to your existing nginx configuration"
echo "4. Restart nginx"
echo ""
echo "For detailed instructions, see KAFKA_SETUP_GUIDE.md"