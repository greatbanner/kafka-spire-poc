#!/bin/bash
# setup.sh - Initialize SPIRE and register workloads

set -e

echo "Creating directory structure..."
mkdir -p spire/server spire/agent-kafka spire/agent-envoy
mkdir -p envoy kafka/config client/config

echo "Waiting for SPIRE server to be healthy..."
sleep 10

echo "Creating SPIRE registration entries..."

# Register Kafka workload
docker compose exec spire-server /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/kafka \
  -parentID spiffe://example.org/spire/agent/join_token/kafka-agent \
  -selector docker:label:com.docker.compose.service:kafka \
  -dns kafka \
  -ttl 3600

# Register Envoy workload
docker compose exec spire-server /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/envoy \
  -parentID spiffe://example.org/spire/agent/join_token/envoy-agent \
  -selector docker:label:com.docker.compose.service:envoy \
  -dns envoy \
  -ttl 3600

# Register client workload
docker compose exec spire-server /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://example.org/kafka-client \
  -parentID spiffe://example.org/spire/agent/join_token/envoy-agent \
  -selector docker:label:com.docker.compose.service:kafka-client \
  -dns kafka-client \
  -ttl 3600

echo "SPIRE workloads registered successfully!"

echo "
Setup complete! 

To test the connection:

1. Create a test topic:
   docker compose exec kafka-client kafka-topics --create \\
     --topic test-topic \\
     --bootstrap-server envoy:9092 \\
     --command-config /etc/kafka/config/client.properties

2. Produce messages:
   docker compose exec kafka-client kafka-console-producer \\
     --topic test-topic \\
     --bootstrap-server envoy:9092 \\
     --producer.config /etc/kafka/config/client.properties

3. Consume messages:
   docker compose exec kafka-client kafka-console-consumer \\
     --topic test-topic \\
     --bootstrap-server envoy:9092 \\
     --consumer.config /etc/kafka/config/client.properties \\
     --from-beginning

4. Check Envoy stats:
   curl http://localhost:9901/stats
"
