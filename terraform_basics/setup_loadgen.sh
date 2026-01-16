#!/bin/bash
# setup_loadgen.sh - Load Generator VM Setup Script for both simple and distributed testing ;)

set -e  # Exit on any error

echo "================================================"
echo "Load Generator Setup Script"
echo "================================================"
echo ""

# Configuration
WORK_DIR="/opt/monitoring"
REPO_DIR="$WORK_DIR/microservices-demo"
LOADGEN_DIR="$REPO_DIR/src/loadgenerator"
RESULTS_DIR="/opt/locust-results"
SCRIPTS_DIR="/opt/loadgen-scripts"

echo "[1/5] Updating system and installing Docker..."
apt-get update
apt-get install -y git docker.io docker-compose
systemctl start docker
systemctl enable docker

echo ""
echo "[2/5] Cloning repository..."
mkdir -p $WORK_DIR
cd $WORK_DIR

if [ -d "$REPO_DIR" ]; then
    echo "Repository already exists, removing..."
    rm -rf "$REPO_DIR"
fi

git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd $LOADGEN_DIR

echo ""
echo "[3/5] Fixing Dockerfile..."

# Deprecated alpine setup change
sed -i 's/FROM --platform=\$BUILDPLATFORM python:3\.14\.2-alpine@sha256:[a-f0-9]* AS base/FROM python:3.14.2-alpine AS base/' Dockerfile

echo ""
echo "[4/5] Building Docker image..."
docker build -t loadgenerator .

echo ""
echo "[5/5] Creating testing directories and scripts..."
mkdir -p $RESULTS_DIR
mkdir -p $SCRIPTS_DIR

# ============================================
#            SIMPLE LOCUST 
# ============================================

# ------ test runner script ------

cat > $SCRIPTS_DIR/run_test.sh << 'SCRIPTEOF'
#!/bin/bash

FRONTEND_IP=$1
USERS=$2
SPAWN_RATE=$3
DURATION=$4
TEST_NAME=$5

if [ -z "$FRONTEND_IP" ] || [ -z "$USERS" ] || [ -z "$SPAWN_RATE" ] || [ -z "$DURATION" ] || [ -z "$TEST_NAME" ]; then
    echo "Usage: $0 <frontend_ip> <users> <spawn_rate> <duration> <test_name>"
    echo "Example: $0 35.1.2.3 100 10 5m test1"
    exit 1
fi

RESULTS_DIR="/opt/locust-results"

echo "================================================"
echo "Test: $TEST_NAME"
echo "Target: http://$FRONTEND_IP"
echo "Users: $USERS | Spawn Rate: $SPAWN_RATE | Duration: $DURATION"
echo "================================================"

docker run --rm \
  --entrypoint locust \
  -v $RESULTS_DIR:/results \
  -e FRONTEND_ADDR="$FRONTEND_IP:80" \
  -e USERS="$USERS" \
  -e SPAWN_RATE="$SPAWN_RATE" \
  -e RUN_TIME="$DURATION" \
  loadgenerator \
    --host=http://$FRONTEND_IP \
    --users=$USERS \
    --spawn-rate=$SPAWN_RATE \
    --run-time=$DURATION \
    --headless \
    --csv=/results/${TEST_NAME} \
    --html=/results/${TEST_NAME}.html

echo ""
echo "================================================"
echo "✓ Test complete!"
echo "Results saved to: $RESULTS_DIR/${TEST_NAME}*"
echo "================================================"
SCRIPTEOF

chmod +x $SCRIPTS_DIR/run_test.sh

# ------ full test suite script ------

cat > $SCRIPTS_DIR/run_all_tests.sh << 'ALLEOF'
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <frontend_ip>"
    echo "Example: $0 35.1.2.3"
    exit 1
fi

FRONTEND_IP=$1
SCRIPTS_DIR="/opt/loadgen-scripts"

echo "=========================================="
echo "Full Performance Test Suite"
echo "Frontend: http://$FRONTEND_IP"
echo "=========================================="
echo ""

# Test configurations: users:spawn_rate:duration:name:label
declare -a tests=(
  "10:5:5m:test_baseline:Baseline (10 users)"
  "50:10:5m:test_light:Light Load (50 users)"
  "100:10:5m:test_medium:Medium Load (100 users)"
  "200:20:5m:test_heavy:Heavy Load (200 users)"
  "500:50:5m:test_stress:Stress Test (500 users)"
)

total=${#tests[@]}
current=1

for test in "${tests[@]}"; do
  IFS=':' read -r users spawn_rate duration name label <<< "$test"
  
  echo ""
  echo "=========================================="
  echo "[$current/$total] Running: $label"
  echo "=========================================="
  
  $SCRIPTS_DIR/run_test.sh "$FRONTEND_IP" "$users" "$spawn_rate" "$duration" "$name"
  
  if [ $current -lt $total ]; then
    echo ""
    echo "Waiting 2 minutes before next test..."
    sleep 120
  fi
  
  ((current++))
done

echo ""
echo "=========================================="
echo "All tests complete!"
echo "=========================================="
echo ""
echo "Results location: /opt/locust-results/"
ls -lh /opt/locust-results/
ALLEOF

chmod +x $SCRIPTS_DIR/run_all_tests.sh

# ------ script to list results ------

cat > $SCRIPTS_DIR/list_results.sh << 'LISTEOF'
#!/bin/bash

RESULTS_DIR="/opt/locust-results"

echo "Test Results:"
echo "============================================"
ls -lh $RESULTS_DIR/
echo ""
echo "HTML Reports:"
echo "============================================"
ls -1 $RESULTS_DIR/*.html 2>/dev/null || echo "No HTML reports found"
echo ""
echo "CSV Files:"
echo "============================================"
ls -1 $RESULTS_DIR/*.csv 2>/dev/null || echo "No CSV files found"
LISTEOF

chmod +x $SCRIPTS_DIR/list_results.sh

# ------ cleanup script ------

cat > $SCRIPTS_DIR/clean_results.sh << 'CLEANEOF'
#!/bin/bash

RESULTS_DIR="/opt/locust-results"

echo "This will delete all test results in $RESULTS_DIR"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    rm -f $RESULTS_DIR/*
    echo "Results cleaned!"
else
    echo "Cancelled"
fi
CLEANEOF

chmod +x $SCRIPTS_DIR/clean_results.sh

# ============================================
#            DISTRIBUTED LOCUST 
# ============================================

echo ""
echo "[6/6] Creating distributed Locust scripts..."

# ------ distributed master script ------

cat > $SCRIPTS_DIR/run_distributed_master.sh << 'MASTEREOF'
#!/bin/bash

FRONTEND_IP=$1
TOTAL_USERS=$2
SPAWN_RATE=$3
DURATION=$4
TEST_NAME=$5
NUM_WORKERS=$6

if [ -z "$FRONTEND_IP" ] || [ -z "$TOTAL_USERS" ] || [ -z "$SPAWN_RATE" ] || [ -z "$DURATION" ] || [ -z "$TEST_NAME" ] || [ -z "$NUM_WORKERS" ]; then
    echo "Usage: $0 <frontend_ip> <total_users> <spawn_rate> <duration> <test_name> <num_workers>"
    echo "Example: $0 35.1.2.3 1000 100 10m test_high 3"
    exit 1
fi

RESULTS_DIR="/opt/locust-results"

echo "================================================"
echo "Distributed Locust Test - MASTER"
echo "================================================"
echo "Test: $TEST_NAME"
echo "Target: http://$FRONTEND_IP"
echo "Total Users: $TOTAL_USERS"
echo "Spawn Rate: $SPAWN_RATE"
echo "Duration: $DURATION"
echo "Expected Workers: $NUM_WORKERS"
echo "================================================"
echo ""
echo "Starting master node..."
echo "Waiting for $NUM_WORKERS workers to connect..."
echo ""

docker run --rm \
  --entrypoint locust \
  --name locust-master \
  -p 8089:8089 \
  -v $RESULTS_DIR:/results \
  loadgenerator \
    --host=http://$FRONTEND_IP \
    --master \
    --expect-workers=$NUM_WORKERS \
    --users=$TOTAL_USERS \
    --spawn-rate=$SPAWN_RATE \
    --run-time=$DURATION \
    --headless \
    --csv=/results/${TEST_NAME} \
    --html=/results/${TEST_NAME}.html

echo ""
echo "================================================"
echo "✓ Distributed test complete!"
echo "Results: $RESULTS_DIR/${TEST_NAME}*"
echo "================================================"
MASTEREOF

chmod +x $SCRIPTS_DIR/run_distributed_master.sh

# ------ distributed worker script ------

cat > $SCRIPTS_DIR/run_distributed_worker.sh << 'WORKEREOF'
#!/bin/bash

WORKER_ID=$1

if [ -z "$WORKER_ID" ]; then
    echo "Usage: $0 <worker_id>"
    echo "Example: $0 1"
    exit 1
fi

echo "================================================"
echo "Starting Distributed Locust Worker #$WORKER_ID"
echo "================================================"
echo "Connecting to master at localhost:5557"
echo ""

docker run --rm \
  --entrypoint locust \
  --name locust-worker-$WORKER_ID \
  --network host \
  loadgenerator \
    --worker \
    --master-host=localhost

echo ""
echo "Worker #$WORKER_ID stopped"
WORKEREOF

chmod +x $SCRIPTS_DIR/run_distributed_worker.sh

# ------ script to run distributed test ------

cat > $SCRIPTS_DIR/run_distributed_test.sh << 'DISTEOF'
#!/bin/bash

FRONTEND_IP=$1
TOTAL_USERS=$2
SPAWN_RATE=$3
DURATION=$4
TEST_NAME=$5
NUM_WORKERS=$6

if [ -z "$FRONTEND_IP" ] || [ -z "$TOTAL_USERS" ] || [ -z "$SPAWN_RATE" ] || [ -z "$DURATION" ] || [ -z "$TEST_NAME" ] || [ -z "$NUM_WORKERS" ]; then
    echo "Usage: $0 <frontend_ip> <total_users> <spawn_rate> <duration> <test_name> <num_workers>"
    echo "Example: $0 35.1.2.3 1000 100 10m test_high 3"
    exit 1
fi

SCRIPTS_DIR="/opt/loadgen-scripts"

echo "================================================"
echo "Starting Distributed Locust Test"
echo "================================================"
echo "Master + $NUM_WORKERS workers will be started"
echo ""
echo "Starting workers in background..."

# Start workers in background
for i in $(seq 1 $NUM_WORKERS); do
    echo "Starting worker #$i..."
    $SCRIPTS_DIR/run_distributed_worker.sh $i &
    sleep 2
done

echo ""
echo "All workers started. Waiting 10 seconds for initialization..."
sleep 10

echo ""
echo "Starting master node..."
$SCRIPTS_DIR/run_distributed_master.sh "$FRONTEND_IP" "$TOTAL_USERS" "$SPAWN_RATE" "$DURATION" "$TEST_NAME" "$NUM_WORKERS"

echo ""
echo "Cleaning up workers..."
docker stop $(docker ps -q --filter "name=locust-worker") 2>/dev/null || true

echo "Done!"
DISTEOF

chmod +x $SCRIPTS_DIR/run_distributed_test.sh

# ------ high-load test suite ------

cat > $SCRIPTS_DIR/run_high_load_tests.sh << 'HIGHEOF'
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <frontend_ip>"
    echo "Example: $0 35.1.2.3"
    exit 1
fi

FRONTEND_IP=$1
SCRIPTS_DIR="/opt/loadgen-scripts"

echo "=========================================="
echo "High Load Performance Test Suite"
echo "Using Distributed Locust"
echo "Frontend: http://$FRONTEND_IP"
echo "=========================================="
echo ""

# High load test configurations: users:spawn_rate:duration:name:workers:label
declare -a tests=(
  "1000:100:10m:test_high_1k:3:High Load 1K Users (3 workers)"
  "2000:200:10m:test_high_2k:4:High Load 2K Users (4 workers)"
  "3000:300:10m:test_peak_3k:5:Peak Load 3K Users (5 workers)"
)

total=${#tests[@]}
current=1

for test in "${tests[@]}"; do
  IFS=':' read -r users spawn_rate duration name workers label <<< "$test"
  
  echo ""
  echo "=========================================="
  echo "[$current/$total] $label"
  echo "=========================================="
  
  $SCRIPTS_DIR/run_distributed_test.sh "$FRONTEND_IP" "$users" "$spawn_rate" "$duration" "$name" "$workers"
  
  if [ $current -lt $total ]; then
    echo ""
    echo "Waiting 3 minutes before next test..."
    sleep 180
  fi
  
  ((current++))
done

echo ""
echo "=========================================="
echo "All high-load tests complete!"
echo "=========================================="
echo ""
ls -lh /opt/locust-results/
HIGHEOF

chmod +x $SCRIPTS_DIR/run_high_load_tests.sh

# ------ monitoring helper ------
cat > $SCRIPTS_DIR/monitor_loadgen.sh << 'MONEOF'
#!/bin/bash

echo "Load Generator Resource Monitoring"
echo "=========================================="
echo ""

while true; do
    clear
    echo "Load Generator VM Resources"
    echo "=========================================="
    echo "Time: $(date)"
    echo ""
    
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "  Used: " 100 - $1 "%"}'
    echo ""
    
    echo "Memory Usage:"
    free -h | grep Mem | awk '{print "  Used: " $3 " / " $2 " (" $3/$2*100 "%)"}'
    echo ""
    
    echo "Running Docker Containers:"
    docker ps --format "  {{.Names}}: {{.Status}}"
    echo ""
    
    echo "Network Connections:"
    netstat -an | grep ESTABLISHED | wc -l | awk '{print "  Active connections: " $1}'
    echo ""
    
    echo "Press Ctrl+C to exit"
    sleep 5
done
MONEOF

chmod +x $SCRIPTS_DIR/monitor_loadgen.sh

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Docker image 'loadgenerator' has been built"
echo "Repository cloned to: $REPO_DIR"
echo "Test scripts location: $SCRIPTS_DIR"
echo "Results directory: $RESULTS_DIR"
echo ""
echo "Available scripts:"
echo "  - run_test.sh       : Run a single test"
echo "  - run_all_tests.sh  : Run full test suite"
echo "  - list_results.sh   : List all test results"
echo "  - clean_results.sh  : Clean up test results"
echo ""
echo "Quick start:"
echo "  1. Get your frontend IP: kubectl get service frontend-external"
echo "  2. Run tests: $SCRIPTS_DIR/run_all_tests.sh <frontend_ip>"
echo "  3. View results: $SCRIPTS_DIR/list_results.sh"
echo ""