from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, Response
from pydantic import BaseModel
from typing import Optional

app = FastAPI()

PORT = 3002
BACKEND = "B"
ETAG_VALUE = '"backend-b-v1"'

# Dummy in-memory database
items = [
    {"id": 1, "name": "Item One", "status": "active"},
    {"id": 2, "name": "Item Two", "status": "pending"},
]

class ItemCreate(BaseModel):
    name: str
    status: Optional[str] = "pending"

class ItemUpdate(BaseModel):
    name: Optional[str] = None
    status: Optional[str] = None


# Middleware: set X-Backend header on every response
@app.middleware("http")
async def add_backend_header(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Backend"] = BACKEND
    return response


# Required: GET / — with caching headers + conditional request support
@app.get("/", response_class=HTMLResponse)
def read_root(request: Request):
    if request.headers.get("if-none-match") == ETAG_VALUE:
        return Response(status_code=304, headers={
            "Cache-Control": "max-age=60",
            "ETag": ETAG_VALUE,
        })

    html = f"""
    <body style="background-color: gray; color: black; font-family: Arial, sans-serif; padding: 40px;">
      <h1>Welcome to Backend {BACKEND}!</h1>
      <p>The backend is running smoothly.</p>
    </body>
    """
    return HTMLResponse(
        content=html,
        headers={
            "Cache-Control": "max-age=60",
            "ETag": ETAG_VALUE,
        },
    )


# Required: GET /api/status
@app.get("/api/status")
def get_status():
    return JSONResponse(content={"backend": BACKEND, "status": "ok"})


# Optional extra routes — not required by the brief, kept from your original
@app.get("/api/items")
def get_items():
    return {"success": True, "count": len(items), "data": items}


@app.get("/api/items/{item_id}")
def get_item(item_id: int):
    item = next((i for i in items if i["id"] == item_id), None)
    if not item:
        raise HTTPException(status_code=404, detail={"success": False, "message": "Item not found"})
    return {"success": True, "data": item}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)