from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import engine, Base
from app.routers import clientes, financeiro, prazos, processos


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Muglia", version="1.0.0", lifespan=lifespan)

app.include_router(clientes.router)
app.include_router(financeiro.router)
app.include_router(prazos.router)
app.include_router(processos.router)


@app.get("/health")
def health():
    return {"status": "ok"}
