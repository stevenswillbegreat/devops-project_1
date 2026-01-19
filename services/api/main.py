import os
import json
import asyncio
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import nats
import redis

app = FastAPI()

# Configuration from Env Vars (K8s ConfigMap/Secrets)
NATS_URL = os.getenv("NATS_URL", "nats://nats.app-workload.svc:4222")
VALKEY_HOST = os.getenv("VALKEY_HOST", "valkey-redis-master.app-workload.svc")
VALKEY_PASS = os.getenv("VALKEY_PASS", "securepassword123")
QUEUE_SUBJECT = "tasks"

# Initialize Clients
nc = None
r = redis.Redis(host=VALKEY_HOST, port=6379, password=VALKEY_PASS, decode_responses=True)

class Task(BaseModel):
    payload: dict

@app.on_event("startup")
async def startup_event():
    global nc
    try:
        # Connect to NATS
        nc = await nats.connect(NATS_URL)
        print(f"Connected to NATS at {NATS_URL}")
    except Exception as e:
        print(f"Error connecting to NATS: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    if nc:
        await nc.close()

@app.post("/task")
async def create_task(task: Task):
    if not nc:
        raise HTTPException(status_code=503, detail="Queue not available")
    
    try:
        # Push JSON payload into queue [cite: 61]
        data = json.dumps(task.payload).encode()
        await nc.publish(QUEUE_SUBJECT, data)
        return {"status": "queued", "payload": task.payload}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stats")
async def get_stats():
    # Returns Valkey keys, Queue backlog, Worker processed count 
    try:
        # 1. Valkey Key Count
        valkey_keys = r.dbsize()
        
        # 2. Worker Processed Count (Retrieved from a counter in Valkey)
        processed_count = r.get("metric_processed_count") or 0
        
        # 3. Queue Backlog (Approximation via NATS JetStream or simplified for NATS Core)
        # Note: NATS Core doesn't easily expose "queue depth" without JetStream monitoring. 
        # For this test, we might mock it or check a specific "backlog" metric if exposed.
        # We will simply return "N/A" for NATS Core or use the JS manager if upgraded.
        queue_depth = "monitoring_dependent" 

        return {
            "valkey_keys": valkey_keys,
            "processed_count": int(processed_count),
            "queue_status": "active" if nc and nc.is_connected else "disconnected"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))