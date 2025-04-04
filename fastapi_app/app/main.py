from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def read_root():
  return {"Hello": "World"}

@app.get("/ws/{agent_id}")
async def websocket_endpoint(agent_id: str):
  return {"message": f"WebSocket endpoint for agent {agent_id}"}
