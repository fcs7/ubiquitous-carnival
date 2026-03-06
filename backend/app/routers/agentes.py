import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AgenteConfig, Usuario
from app.schemas import (
    AgenteConfigCreate,
    AgenteConfigOut,
    AgenteConfigUpdate,
    FerramentaDisponivel,
)

router = APIRouter(prefix="/agentes", tags=["agentes"])


@router.get("/ferramentas/disponiveis", response_model=list[FerramentaDisponivel])
def listar_ferramentas_disponiveis():
    from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS
    return [
        FerramentaDisponivel(nome=k, descricao_ui=v["descricao_ui"], categoria=v["categoria"])
        for k, v in FERRAMENTAS_DISPONIVEIS.items()
    ]


@router.post("/", response_model=AgenteConfigOut, status_code=201)
def criar_agente(payload: AgenteConfigCreate, db: Session = Depends(get_db)):
    usuario = db.query(Usuario).filter(Usuario.id == payload.usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")

    agente = AgenteConfig(
        usuario_id=payload.usuario_id,
        nome=payload.nome,
        descricao=payload.descricao,
        instrucoes_sistema=payload.instrucoes_sistema,
        provider=payload.provider,
        modelo=payload.modelo,
        ferramentas_habilitadas=json.dumps(payload.ferramentas_habilitadas),
        contexto_referencia=payload.contexto_referencia,
        max_tokens=payload.max_tokens,
        max_iteracoes_tool=payload.max_iteracoes_tool,
    )
    db.add(agente)
    db.commit()
    db.refresh(agente)
    return AgenteConfigOut.from_orm_with_tools(agente)


@router.get("/", response_model=list[AgenteConfigOut])
def listar_agentes(usuario_id: int | None = None, db: Session = Depends(get_db)):
    q = db.query(AgenteConfig)
    if usuario_id is not None:
        q = q.filter(AgenteConfig.usuario_id == usuario_id)
    agentes = q.order_by(AgenteConfig.updated_at.desc()).all()
    return [AgenteConfigOut.from_orm_with_tools(a) for a in agentes]


@router.get("/{agente_id}", response_model=AgenteConfigOut)
def detalhe_agente(agente_id: int, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(AgenteConfig.id == agente_id).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")
    return AgenteConfigOut.from_orm_with_tools(agente)


@router.put("/{agente_id}", response_model=AgenteConfigOut)
def atualizar_agente(agente_id: int, payload: AgenteConfigUpdate, usuario_id: int, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(
        AgenteConfig.id == agente_id,
        AgenteConfig.usuario_id == usuario_id,
    ).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")

    update_data = payload.model_dump(exclude_unset=True)
    if "ferramentas_habilitadas" in update_data:
        update_data["ferramentas_habilitadas"] = json.dumps(update_data["ferramentas_habilitadas"])

    for key, value in update_data.items():
        setattr(agente, key, value)

    db.commit()
    db.refresh(agente)
    return AgenteConfigOut.from_orm_with_tools(agente)


@router.delete("/{agente_id}", status_code=204)
def deletar_agente(agente_id: int, usuario_id: int, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(
        AgenteConfig.id == agente_id,
        AgenteConfig.usuario_id == usuario_id,
    ).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")
    db.delete(agente)
    db.commit()
