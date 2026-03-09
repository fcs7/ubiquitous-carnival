import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.database import engine, Base, SessionLocal
from app.models import Usuario
from app.routers import agentes, assistente, auth, chat, clientes, documentos, prazos, processos, status, vindi, vindi_webhook


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    # Criar usuario padrao se nao existir
    db = SessionLocal()
    try:
        if not db.query(Usuario).first():
            from app.services.auth import hash_senha
            db.add(Usuario(
                nome="Admin Muglia",
                email="admin@muglia.com.br",
                senha_hash=hash_senha("muglia2024"),
            ))
            db.commit()
        # Seed agente padrao do assistente
        from app.services.assistente import get_or_create_agente_padrao
        get_or_create_agente_padrao(db, 1)
        db.commit()
    finally:
        db.close()
    yield


logger = logging.getLogger(__name__)

app = FastAPI(title="Muglia", version="1.0.0", lifespan=lifespan)


# ── Middleware: Headers de seguranca ──────────────
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        return response


app.add_middleware(SecurityHeadersMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)


# ── Handler global: ocultar detalhes de erros 500 ──
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Erro nao tratado: %s %s", request.method, request.url, exc_info=exc)
    return JSONResponse(
        status_code=500,
        content={"detail": "Erro interno do servidor"},
    )

app.include_router(auth.router)
app.include_router(agentes.router)
app.include_router(assistente.router)
app.include_router(chat.router)
app.include_router(clientes.router)
app.include_router(documentos.router)
app.include_router(prazos.router)
app.include_router(processos.router)
app.include_router(status.router)
app.include_router(vindi_webhook.router)
app.include_router(vindi.router)


@app.get("/health")
def health():
    return {"status": "ok"}
