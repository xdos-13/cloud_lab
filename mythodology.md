# Performance Evaluation Methodology

## Test Environment
- **Load Generator**: GCE e2-standard-2 (2 vCPUs, 8GB RAM)
- **Application**: Online Boutique on GKE (standard mode)
- **Network**: Same GCP region to minimize latency
- **Tool**: Locust load testing framework

## Test Parameters

### Single Locust Instance Tests (Baseline)
We start with a single Locust instance to establish baseline performance and identify the saturation point of the application before hitting load generator limits.

| Test Name | Users | Spawn Rate | Duration | Purpose |
|-----------|-------|------------|----------|---------|
| Baseline  | 10    | 5/s        | 5 min    | Normal operation baseline |
| Light     | 50    | 10/s       | 5 min    | Light traffic simulation |
| Medium    | 100   | 10/s       | 5 min    | Moderate traffic |
| Heavy     | 200   | 20/s       | 5 min    | Heavy traffic |
| Stress    | 500   | 50/s       | 5 min    | Stress test |

**Spawn Rate Rationale**: 
- Gradual ramp-up prevents sudden spikes
- Allows observation of performance degradation patterns
- Spawn rate = users/10 to complete ramp in ~10 seconds

### Multi-Instance Distributed Tests (High Load)
When single instance shows CPU saturation (>80%) or decreased RPS despite more users, we deploy distributed Locust with 1 master + N workers.

| Test Name | Total Users | Workers | Users/Worker | Duration | Purpose |
|-----------|-------------|---------|--------------|----------|---------|
| High-1    | 1000        | 3       | ~333         | 10 min   | High load capacity test |
| High-2    | 2000        | 4       | 500          | 10 min   | Maximum throughput test |
| Peak      | 3000        | 5       | 600          | 10 min   | Breaking point identification |

## Metrics Collection

### Application Metrics (via Locust)
- **Response Time**: Median, 95th percentile, 99th percentile
- **Throughput**: Requests per second (RPS)
- **Error Rate**: Percentage of failed requests
- **Request Distribution**: Performance per endpoint

### Infrastructure Metrics (via Prometheus/Grafana)
- **Pod-level**: CPU usage, Memory usage, Network I/O
- **Node-level**: CPU usage, Memory usage, Disk I/O
- **Service-level**: Request latency, error rates

### Load Generator Metrics
- **CPU Usage**: Monitor to detect generator bottleneck
- **Memory Usage**: Ensure no memory constraints
- **Network**: Bandwidth utilization

## Success Criteria

1. **Functional**: Error rate < 1% under normal load (< 200 users)
2. **Performance**: 95th percentile response time < 2 seconds under normal load
3. **Scalability**: Linear throughput increase until application saturation
4. **Stability**: No pod restarts or OOM kills during tests

## Bottleneck Identification Strategy

1. Correlate Locust metrics with Grafana dashboards
2. Identify which pods show resource saturation first
3. Analyze if reduced resources (from earlier steps) impact performance
4. Determine if bottleneck is CPU, memory, or network