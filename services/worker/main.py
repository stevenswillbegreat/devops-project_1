import os
import json
import asyncio
import signal
import nats
import redis
from prometheus_client import start_http_server, Counter

# Configuration
NATS_URL = os.getenv("NATS_URL", "nats://nats.app-workload.svc:4222")
VALKEY_HOST = os.getenv("VALKEY_HOST", "valkey-redis-master.app-workload.svc")
VALKEY_PASS = os.getenv("VALKEY_PASS", "securepassword123")
QUEUE_SUBJECT = "tasks"

# Prometheus Metrics 
TASKS_PROCESSED = Counter('worker_tasks_processed_total', 'Total tasks processed')
TASKS_ERRORS = Counter('worker_tasks_errors_total', 'Total processing errors')

# Initialize Valkey
r = redis.Redis(host=VALKEY_HOST, port=6379, password=VALKEY_PASS, decode_responses=True)

async def message_handler(msg):
    try:
        data = json.loads(msg.data.decode())
        print(f"Received task: {data}")
        
        # Simulate Processing
        result = {"status": "completed", "original_data": data}
        
        # Store result in Valkey [cite: 71]
        # We use a random key or ID from payload if it exists
        key = f"task:{os.urandom(4).hex()}"
        r.set(key, json.dumps(result))
        
        # Update metrics
        TASKS_PROCESSED.inc()
        
        # Also increment a global counter in Valkey for the API /stats endpoint to read [cite: 67]
        r.incr("metric_processed_count")
        
    except Exception as e:
        print(f"Error processing: {e}")
        TASKS_ERRORS.inc()

async def run():
    # Expose Prometheus metrics on port 8000
    start_http_server(8000)
    print("Prometheus metrics started on :8000")

    nc = await nats.connect(NATS_URL)
    print(f"Worker connected to NATS at {NATS_URL}")

    # Subscribe to queue
    # Using a queue group 'workers' ensures load balancing if we scale up pods [cite: 35]
    await nc.subscribe(QUEUE_SUBJECT, queue="workers", cb=message_handler)

    # Keep running until signal
    stop_event = asyncio.Event()
    
    # Graceful Shutdown Handler 
    def signal_handler():
        print("Shutdown signal received...")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, signal_handler)

    await stop_event.wait()
    await nc.drain() # Ensure messages are processed before closing
    await nc.close()
    print("Worker shutdown complete.")

if __name__ == '__main__':
    asyncio.run(run())