import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models import Usuario
from app.services.auth import criar_token, hash_senha

engine_test = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestSession = sessionmaker(bind=engine_test)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine_test)
    yield
    Base.metadata.drop_all(bind=engine_test)


@pytest.fixture
def db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def usuario_teste(db):
    """Cria usuario de teste com senha e retorna o objeto."""
    usuario = Usuario(
        nome="Teste",
        email="teste@muglia.com.br",
        senha_hash=hash_senha("senha123"),
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    return usuario


@pytest.fixture
def auth_headers(usuario_teste):
    """Retorna headers com token JWT valido para o usuario de teste."""
    token = criar_token(usuario_teste.id, usuario_teste.email)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def client(auth_headers):
    """TestClient com headers de autenticacao pre-configurados."""
    c = TestClient(app)
    c.headers.update(auth_headers)
    return c
