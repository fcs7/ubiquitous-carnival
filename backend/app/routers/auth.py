from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Usuario
from app.services.auth import criar_token, hash_senha, verificar_senha

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginRequest(BaseModel):
    email: str
    senha: str


class RegistrarRequest(BaseModel):
    nome: str
    email: str
    senha: str
    oab: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario_id: int
    nome: str


class UsuarioResponse(BaseModel):
    id: int
    nome: str
    email: str
    oab: str | None
    ativo: bool

    model_config = {"from_attributes": True}


@router.post("/registrar", response_model=TokenResponse, status_code=201)
def registrar(payload: RegistrarRequest, db: Session = Depends(get_db)):
    """Registra novo usuario com senha criptografada (bcrypt)."""
    existente = db.query(Usuario).filter(Usuario.email == payload.email).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email ja cadastrado",
        )

    usuario = Usuario(
        nome=payload.nome,
        email=payload.email,
        senha_hash=hash_senha(payload.senha),
        oab=payload.oab,
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)

    token = criar_token(usuario.id, usuario.email)
    return TokenResponse(
        access_token=token,
        usuario_id=usuario.id,
        nome=usuario.nome,
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """Autentica usuario e retorna JWT."""
    usuario = db.query(Usuario).filter(Usuario.email == payload.email).first()

    if not usuario or not usuario.senha_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais invalidas",
        )

    if not verificar_senha(payload.senha, usuario.senha_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais invalidas",
        )

    if not usuario.ativo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario inativo",
        )

    token = criar_token(usuario.id, usuario.email)
    return TokenResponse(
        access_token=token,
        usuario_id=usuario.id,
        nome=usuario.nome,
    )


@router.get("/me", response_model=UsuarioResponse)
def perfil(usuario: Usuario = Depends(get_current_user)):
    """Retorna dados do usuario autenticado."""
    return usuario
