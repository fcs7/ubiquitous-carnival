from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import engine, Base, SessionLocal
from app.models import Usuario
from app.routers import agentes, chat, clientes, financeiro, prazos, processos, tags, vindi, vindi_webhook, whatsapp


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    # Criar usuario padrao se nao existir
    db = SessionLocal()
    try:
        if not db.query(Usuario).first():
            db.add(Usuario(nome="Admin Muglia", email="admin@muglia.com.br"))
            db.commit()
    finally:
        db.close()
    yield


app = FastAPI(title="Muglia", version="1.0.0", lifespan=lifespan)

app.include_router(agentes.router)
app.include_router(chat.router)
app.include_router(clientes.router)
app.include_router(financeiro.router)
app.include_router(prazos.router)
app.include_router(processos.router)
app.include_router(vindi_webhook.router)
app.include_router(vindi.router)
app.include_router(tags.router)
app.include_router(whatsapp.router)


@app.get("/health")
def health():
    return {"status": "ok"}
