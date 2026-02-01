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
        # Push JSON payload into queue
        data = json.dumps(task.payload).encode()
        await nc.publish(QUEUE_SUBJECT, data)
        return {"status": "queued", "payload": task.payload}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stats")
async def get_stats():
    try:
        # 1. Valkey keys count
        valkey_keys_count = r.dbsize()
        
        # 2. Queue backlog length
        queue_backlog_length = r.get("queue_backlog_length") or 0
        
        # 3. Worker processed count
        worker_processed_count = r.get("worker_processed_total") or 0

        return {
            "valkey_keys_count": valkey_keys_count,
            "queue_backlog_length": int(queue_backlog_length),
            "worker_processed_count": int(worker_processed_count)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))