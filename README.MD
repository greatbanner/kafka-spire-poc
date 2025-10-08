# Envoy Proxy + Kafka + SPIRE mTLS Setup

This Docker Compose setup demonstrates how to use Envoy as a proxy for Kafka with mTLS authentication powered by SPIRE (SPIFFE Runtime Environment).

## Architecture

```
[Kafka Client] --mTLS--> [Envoy Proxy] --mTLS--> [Kafka Broker]
                    ↑                        ↑
                    |                        |
              [SPIRE Agent]            [SPIRE Agent]
                    ↓                        ↓
                      [SPIRE Server]
```

## Components

- **SPIRE Server**: Issues and manages SPIFFE identities
- **SPIRE Agents**: Run alongside workloads to provide certificates
- **Kafka Broker**: Configured with SSL/mTLS
- **Envoy Proxy**: Terminates client mTLS and proxies to Kafka with mTLS
- **Kafka Client**: Example client connecting through Envoy
- **Zookeeper**: Required for Kafka metadata

## Prerequisites

- Docker and Docker Compose
- Ports 9092, 9093, 9901 available

## Quick Start

1. **Create configuration files** as provided in the artifacts

2. **Start the services:**
   ```bash
   docker compose up -d
   ```

3. **Wait for services to be ready** (about 30 seconds)

4. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

5. **Test the connection:**
   ```bash
   # Create a topic
   docker compose exec kafka-client kafka-topics --create \
     --topic test-topic \
     --bootstrap-server envoy:9092 \
     --replication-factor 1 \
     --partitions 1

   # Produce a message
   echo "Hello from mTLS Kafka!" | docker compose exec -T kafka-client \
     kafka-console-producer \
     --topic test-topic \
     --bootstrap-server envoy:9092

   # Consume messages
   docker compose exec kafka-client kafka-console-consumer \
     --topic test-topic \
     --bootstrap-server envoy:9092 \
     --from-beginning \
     --max-messages 1
   ```

## How It Works

### SPIRE Identity Management

1. **SPIRE Server** acts as the certificate authority for the trust domain `example.org`
2. **SPIRE Agents** attest workload identities using Docker selectors
3. Each workload (Kafka, Envoy, Client) receives a unique SPIFFE ID and X.509 certificate
4. Certificates are automatically rotated by SPIRE

### mTLS Flow

1. Client connects to Envoy (port 9092) with its SPIRE-issued certificate
2. Envoy validates the client certificate against the trust bundle
3. Envoy establishes mTLS connection to Kafka (port 9093) using its own certificate
4. Kafka validates Envoy's certificate and allows the connection

### Envoy Configuration

Envoy uses the SPIRE Agent SDS (Secret Discovery Service) API to:
- Fetch its own certificate for authentication
- Fetch the trust bundle for validation
- Automatically rotate certificates without restart

## Monitoring

**Envoy Admin Interface:**
```bash
curl http://localhost:9901/stats | grep kafka
curl http://localhost:9901/config_dump
```

**Check SPIRE Identities:**
```bash
docker compose exec spire-server /opt/spire/bin/spire-server entry show
```

**View Kafka Logs:**
```bash
docker compose logs kafka -f
```

## Troubleshooting

### Connection Refused
- Ensure all services are healthy: `docker compose ps`
- Check SPIRE registrations: `docker compose exec spire-server /opt/spire/bin/spire-server entry show`

### Certificate Errors
- Verify SPIRE agents are connected: `docker compose logs spire-agent-kafka`
- Check Envoy can access SPIRE socket: `docker compose exec envoy ls -la /opt/spire/sockets/`

### Kafka Errors
- Check Kafka has SPIRE certificates: `docker compose logs kafka | grep SSL`
- Verify Envoy is proxying correctly: `docker compose logs envoy`

## Security Notes

- This setup uses `insecure_bootstrap` for SPIRE agents (suitable for development only)
- In production, use node attestation via TPM, AWS IID, or Kubernetes PSAT
- The trust domain should be organization-specific
- Consider adding authorization policies in Envoy for fine-grained access control

## Cleanup

```bash
docker compose down -v
```

## Next Steps

- Add Kafka ACLs for authorization
- Implement Envoy rate limiting
- Add metrics collection (Prometheus)
- Configure log aggregation
- Set up multi-broker Kafka cluster
