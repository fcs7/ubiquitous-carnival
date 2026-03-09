from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base, SessionLocal
from app.models import Usuario
from app.routers import agentes, assistente, chat, clientes, documentos, prazos, processos, status, vindi, vindi_webhook


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    # Criar usuario padrao se nao existir
    db = SessionLocal()
    try:
        if not db.query(Usuario).first():
            db.add(Usuario(nome="Admin Muglia", email="admin@muglia.com.br"))
            db.commit()
        # Seed agente padrao do assistente
        from app.services.assistente import get_or_create_agente_padrao
        get_or_create_agente_padrao(db, 1)
        db.commit()
    finally:
        db.close()
    yield


app = FastAPI(title="Muglia", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
