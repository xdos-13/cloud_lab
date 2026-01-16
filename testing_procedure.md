# Performance Testing Procedure

## Phase 1: Single Instance Testing

### Step 1: Deploy and Prepare
```bash
# Deploy VM
terraform apply

# Wait 5-7 minutes for setup

# Get frontend IP
kubectl get service frontend-external

# SSH into VM
gcloud compute ssh loadgen-vm-0 --zone=YOUR_ZONE
```

### Step 2: Run Baseline Tests
```bash
# In one SSH terminal, run tests
/opt/loadgen-scripts/run_all_tests.sh YOUR_FRONTEND_IP

# In another SSH terminal, monitor load generator
/opt/loadgen-scripts/monitor_loadgen.sh
```

### Step 3: Analyze Single Instance Results
- Check if CPU usage on load generator stays < 80%
- If CPU saturates before application shows degradation → need distributed testing
- If application degrades first → bottleneck is in application (good!)

## Phase 2: Distributed Testing (if needed)

### Decision Criteria
Run distributed tests if:
- Load generator CPU > 80% during stress test
- RPS plateaus despite increasing users
- Want to test beyond 500 concurrent users

### Step 4: Run High Load Tests
```bash
/opt/loadgen-scripts/run_high_load_tests.sh YOUR_FRONTEND_IP
```

### Step 5: Monitor Both Systems
**Load Generator:**
```bash
/opt/loadgen-scripts/monitor_loadgen.sh
```

**Application (from local machine):**
```bash
# Terminal 1: Watch pods
kubectl get pods -w

# Terminal 2: Monitor resources
watch kubectl top pods

# Terminal 3: Monitor nodes
watch kubectl top nodes
```

## Phase 3: Data Collection

### During Each Test
1. Take Grafana screenshots at:
   - Start of test (0 min)
   - Mid-test (2.5 min for 5min tests)
   - Peak load (end of ramp-up)
   - End of test

2. Note any:
   - Pod restarts
   - Error spikes
   - Resource saturation

### After All Tests
```bash
# Download results
mkdir -p ~/gke-performance-results
gcloud compute scp --recurse loadgen-vm-0:/opt/locust-results/* ~/gke-performance-results/ --zone=YOUR_ZONE
```

## Phase 4: Analysis

### Metrics to Extract
From Locust CSVs:
- Response time: median, p95, p99
- Throughput (RPS)
- Error rate
- Performance per endpoint

From Grafana:
- CPU usage per pod
- Memory usage per pod
- Network I/O
- Pod restarts/OOMs

### Create Comparison Tables
Example format for report:

| Test | Users | RPS | Median RT (ms) | P95 RT (ms) | Error % | App CPU % | LG CPU % |
|------|-------|-----|----------------|-------------|---------|-----------|----------|
| Baseline | 10 | ... | ... | ... | ... | ... | ... |
| Light | 50 | ... | ... | ... | ... | ... | ... |
| ... | ... | ... | ... | ... | ... | ... | ... |