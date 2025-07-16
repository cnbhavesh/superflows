# Kafka Internet Exposure with Nginx Proxy and Security Setup

This guide explains how to expose Kafka over the internet through nginx with proper security configurations.

## Overview

The setup includes:
- **Kafka** with SASL/PLAIN authentication
- **Zookeeper** for Kafka coordination
- **Nginx** as a TCP proxy for Kafka and HTTP proxy for Kafka UI
- **Kafka UI** for management and monitoring
- **SSL/TLS** encryption for web interfaces
- **Access Control Lists (ACLs)** for fine-grained permissions

## Architecture

```
Internet → Nginx (Port 9093) → Kafka (SASL Auth)
Internet → Nginx (Port 443) → Kafka UI (Basic Auth + SSL)
```

## Prerequisites

1. Docker and Docker Compose installed
2. Domain name pointing to your server (e.g., `kafka.yourdomain.com`)
3. Ports 9093, 80, 443 open in firewall
4. SSL certificates (Let's Encrypt recommended for production)

## Quick Start

### 1. Setup Security Configuration

```bash
cd docker/development
chmod +x setup-kafka-security.sh
./setup-kafka-security.sh
```

### 2. Update Configuration

Edit the following files and replace `yourdomain.com` with your actual domain:

- `kafka-docker-compose.yml` (line 28: KAFKA_ADVERTISED_LISTENERS)
- `nginx-config/kafka.conf` (server_name directives)
- `ssl-certs/kafka.crt` (regenerate with correct domain)

### 3. Start the Services

```bash
docker-compose -f kafka-docker-compose.yml up -d
```

### 4. Setup ACLs (Optional but Recommended)

```bash
./kafka-config/setup-acls.sh
```

## Configuration Details

### Kafka Security

#### Authentication Methods
- **SASL/PLAIN**: Username/password authentication
- **SSL/TLS**: For encryption (optional but recommended)

#### User Accounts
- `admin`: Full administrative access
- `app1`: Access to app1-topic only
- `app2`: Access to app2-topic only
- `producer`: Producer-only access
- `consumer`: Consumer-only access

#### JAAS Configuration
Located in `kafka-config/kafka_server_jaas.conf`:
```
KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="admin"
    password="admin-secret"
    user_admin="admin-secret"
    user_app1="app1-secret"
    user_app2="app2-secret";
};
```

### Nginx Configuration

#### TCP Proxy for Kafka
- **Port**: 9093
- **Protocol**: TCP with SASL authentication
- **Rate Limiting**: 10 connections per IP
- **Logging**: Detailed access logs

#### HTTP Proxy for Kafka UI
- **Port**: 443 (HTTPS)
- **Authentication**: Basic Auth + SSL
- **Security Headers**: XSS protection, HSTS, etc.
- **Rate Limiting**: 10 requests per minute

### Client Configuration

#### For App1 (Producer)
```properties
bootstrap.servers=kafka.yourdomain.com:9093
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="app1" password="app1-secret";
```

#### For App2 (Consumer)
```properties
bootstrap.servers=kafka.yourdomain.com:9093
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="app2" password="app2-secret";
group.id=app2-consumer-group
```

## Security Best Practices

### 1. Authentication
- ✅ SASL/PLAIN for basic authentication
- ✅ SSL/TLS for encryption (configure in production)
- ✅ Separate credentials for each application

### 2. Authorization
- ✅ ACLs for topic-level permissions
- ✅ Consumer group restrictions
- ✅ Principle of least privilege

### 3. Network Security
- ✅ Nginx rate limiting
- ✅ IP whitelisting (configure in nginx.conf)
- ✅ Firewall rules
- ✅ SSL/TLS for web interfaces

### 4. Monitoring
- ✅ Nginx access logs
- ✅ Kafka UI for cluster monitoring
- ✅ JMX metrics (port 9101)

## Production Considerations

### SSL/TLS Setup
1. **Get Let's Encrypt certificates**:
   ```bash
   certbot certonly --nginx -d kafka.yourdomain.com
   ```

2. **Update nginx configuration**:
   ```nginx
   ssl_certificate /etc/letsencrypt/live/kafka.yourdomain.com/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/kafka.yourdomain.com/privkey.pem;
   ```

### Password Security
1. **Change default passwords** in `kafka_server_jaas.conf`
2. **Use strong passwords** (minimum 12 characters)
3. **Store passwords securely** (use Docker secrets or environment variables)

### Firewall Configuration
```bash
# Allow only necessary ports
ufw allow 9093/tcp  # Kafka
ufw allow 443/tcp   # HTTPS
ufw allow 80/tcp    # HTTP (redirects to HTTPS)
ufw deny 9092/tcp   # Block direct Kafka access
ufw deny 2181/tcp   # Block Zookeeper access
```

### Monitoring Setup
1. **Enable JMX** for Kafka metrics
2. **Set up log aggregation** for nginx and Kafka logs
3. **Configure alerts** for failed authentication attempts

## Troubleshooting

### Common Issues

1. **Connection refused**:
   - Check if Kafka is running: `docker ps`
   - Verify port forwarding: `netstat -tlnp | grep 9093`

2. **Authentication failed**:
   - Check credentials in JAAS config
   - Verify client configuration

3. **SSL errors**:
   - Check certificate validity: `openssl x509 -in ssl-certs/kafka.crt -text -noout`
   - Verify domain matches certificate

### Useful Commands

```bash
# Check Kafka logs
docker logs kafka

# Test connection
docker exec -it kafka kafka-console-producer --bootstrap-server localhost:29092 --topic test

# List topics
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:29092

# Check ACLs
docker exec -it kafka kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 --list
```

## Monitoring and Maintenance

### Health Checks
- Kafka UI: `https://kafka-ui.yourdomain.com/health`
- Kafka JMX: `localhost:9101`

### Log Files
- Nginx access: `/var/log/nginx/kafka_access.log`
- Kafka logs: `docker logs kafka`

### Backup Considerations
- **Topics**: Regular topic backups
- **Configuration**: Version control all config files
- **Certificates**: Backup SSL certificates

## Integration Examples

### Node.js Client
```javascript
const { Kafka } = require('kafkajs');

const kafka = Kafka({
  clientId: 'my-app',
  brokers: ['kafka.yourdomain.com:9093'],
  sasl: {
    mechanism: 'plain',
    username: 'app1',
    password: 'app1-secret'
  }
});
```

### Java Client
```java
Properties props = new Properties();
props.put("bootstrap.servers", "kafka.yourdomain.com:9093");
props.put("security.protocol", "SASL_PLAINTEXT");
props.put("sasl.mechanism", "PLAIN");
props.put("sasl.jaas.config", 
  "org.apache.kafka.common.security.plain.PlainLoginModule required " +
  "username=\"app1\" password=\"app1-secret\";");
```

### Python Client
```python
from kafka import KafkaProducer
import ssl

producer = KafkaProducer(
    bootstrap_servers=['kafka.yourdomain.com:9093'],
    security_protocol="SASL_PLAINTEXT",
    sasl_mechanism="PLAIN",
    sasl_plain_username="app1",
    sasl_plain_password="app1-secret"
)
```

## Support

For issues or questions:
1. Check the logs first
2. Review the configuration files
3. Test connectivity with telnet: `telnet kafka.yourdomain.com 9093`
4. Verify DNS resolution: `nslookup kafka.yourdomain.com`

Remember to always test in a development environment before deploying to production!