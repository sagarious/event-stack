from fastapi import Response
from typing import Optional
from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.responses import Response, JSONResponse
import qrcode, io, os, time, jwt, sqlite3, threading

API_KEY = os.getenv("SGE_API_KEY", "")
SECRET  = os.getenv("SGE_SECRET", "devsecret")
ISSUER  = "sagarious-events"

DB_PATH = os.getenv("SGE_DB", "/data/sge.db")
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

# SQLite (thread-safe via a lock)
conn = sqlite3.connect(DB_PATH, check_same_thread=False)
conn.execute("""
CREATE TABLE IF NOT EXISTS checkins (
  token      TEXT PRIMARY KEY,
  tid        INTEGER,
  eid        INTEGER,
  first_seen INTEGER,
  last_seen  INTEGER,
  count      INTEGER DEFAULT 1,
  first_ip   TEXT,
  last_ip    TEXT
)
""")
conn.commit()
_lock = threading.Lock()

# Single app instance + proxy headers
api = FastAPI(title="Sagarious Ticket Service")
app = api

def require_key(x_api_key: Optional[str]) -> None:
    if not API_KEY or x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="invalid api key")

def verify_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET, algorithms=["HS256"], issuer=ISSUER)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="expired token")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="invalid token")

@api.get("/healthz")
def healthz():
    return Response(b"ok\n", media_type="text/plain")

@api.get("/api/v1/qr/{token}.png", name="qr_png")
def qr_png(token: str):
    # Public so email clients can render <img> directly
    img = qrcode.make(token)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return Response(buf.getvalue(), media_type="image/png")

@api.post("/api/v1/checkin")
def checkin(payload: dict, request: Request, x_api_key: Optional[str] = Header(None)):
    require_key(x_api_key)
    token = payload.get("token")
    if not token:
        raise HTTPException(status_code=400, detail="missing token")
    data = verify_token(token)

    client_ip = request.headers.get("x-forwarded-for", request.client.host)

    now = int(time.time())
    with _lock:
        cur = conn.execute("SELECT token,tid,eid,first_seen,last_seen,count FROM checkins WHERE token=?", (token,))
        row = cur.fetchone()
        if not row:
            conn.execute(
                "INSERT INTO checkins(token,tid,eid,first_seen,last_seen,count,first_ip,last_ip) VALUES(?,?,?,?,?,?,?,?)",
                (token, int(data.get("tid", 0)), int(data.get("eid", 0)), now, now, 1, client_ip, client_ip)
            )
            conn.commit()
            first_seen, last_seen, count = now, now, 1
            already = False
        else:
            _, tid, eid, first_seen, last_seen, count = row
            count += 1
            conn.execute(
                "UPDATE checkins SET last_seen=?, count=?, last_ip=? WHERE token=?",
                (now, count, client_ip, token)
            )
            conn.commit()
            already = True

    return JSONResponse({
        "ok": True,
        "ticket_id": int(data.get("tid", 0)),
        "event_id": int(data.get("eid", 0)),
        "already_checked_in": already,
        "first_checked_in_at": int(first_seen),
        "last_checked_in_at": int(now),
        "count": int(count),
    })

@api.get("/api/v1/status/{token}")
def status(token: str, x_api_key: Optional[str] = Header(None)):
    require_key(x_api_key)
    cur = conn.execute("SELECT tid,eid,first_seen,last_seen,count FROM checkins WHERE token=?", (token,))
    row = cur.fetchone()
    if not row:
        return JSONResponse({"seen": False})
    tid, eid, first_seen, last_seen, count = row
    return JSONResponse({
        "seen": True,
        "ticket_id": int(tid),
        "event_id": int(eid),
        "first_checked_in_at": int(first_seen),
        "last_checked_in_at": int(last_seen),
        "count": int(count),
    })

@api.post("/api/v1/mint")
def mint(payload: dict, request: Request, x_api_key: Optional[str] = Header(None)):
    require_key(x_api_key)
    try:
        tid = int(payload.get("tid"))
        eid = int(payload.get("eid"))
    except Exception:
        raise HTTPException(status_code=400, detail="tid/eid must be integers")

    ttl = int(payload.get("ttl", 3600))
    ttl = max(60, min(ttl, 7 * 24 * 3600))  # clamp: 1 minute .. 7 days
    now = int(time.time())
    token = jwt.encode(
        {"tid": tid, "eid": eid, "iat": now, "exp": now + ttl, "iss": ISSUER},
        SECRET, algorithm="HS256"
    )

    # Prefer url_for (uses proxy headers via middleware)
    try:
        qr_url = str(request.url_for("qr_png", token=token))
    except Exception:
        qr_url = None

    # Fallback: explicitly reconstruct using forwarded headers if needed
    if not qr_url or qr_url.startswith("http://"):
        proto = request.headers.get("x-forwarded-proto", request.url.scheme)
        host  = request.headers.get("x-forwarded-host", request.headers.get("host", ""))
        if host:
            qr_url = f"{proto}://{host}/api/v1/qr/{token}.png"
        else:
            base = str(request.base_url).rstrip("/")
            qr_url = f"{base}/api/v1/qr/{token}.png"

    return JSONResponse({"ok": True, "token": token, "qr_png_url": qr_url})
@app.head("/api/v1/qr/{token}.png")
def qr_head(token: str):
    # Optionally validate token format; we only advertise availability here.
    return Response(status_code=200, media_type="image/png")
