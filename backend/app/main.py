from fastapi import FastAPI
from app.database import engine, Base

app = FastAPI(title="Muglia", version="1.0.0")

Base.metadata.create_all(bind=engine)


@app.get("/health")
def health():
    return {"status": "ok"}
