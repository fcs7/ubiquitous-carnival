from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Tag, TagEntidade
from app.schemas import TagCreate, TagEntidadeCreate, TagEntidadeOut, TagOut

router = APIRouter(prefix="/tags", tags=["tags"])

ENTIDADE_TIPOS_VALIDOS = {"cliente", "processo", "financeiro", "vindi_customer", "vindi_subscription", "vindi_bill"}


@router.post("/", response_model=TagOut, status_code=201)
def criar_tag(body: TagCreate, db: Session = Depends(get_db)):
    tag = Tag(nome=body.nome, cor=body.cor)
    db.add(tag)
    db.commit()
    db.refresh(tag)
    return tag


@router.get("/", response_model=list[TagOut])
def listar_tags(db: Session = Depends(get_db)):
    return db.query(Tag).order_by(Tag.nome).all()


@router.post("/aplicar", response_model=TagEntidadeOut, status_code=201)
def aplicar_tag(body: TagEntidadeCreate, db: Session = Depends(get_db)):
    if body.entidade_tipo not in ENTIDADE_TIPOS_VALIDOS:
        raise HTTPException(status_code=400, detail=f"entidade_tipo invalido. Validos: {ENTIDADE_TIPOS_VALIDOS}")

    tag = db.get(Tag, body.tag_id)
    if not tag:
        raise HTTPException(status_code=404, detail="Tag nao encontrada")

    existente = db.query(TagEntidade).filter_by(
        tag_id=body.tag_id, entidade_tipo=body.entidade_tipo, entidade_id=body.entidade_id,
    ).first()
    if existente:
        return existente

    te = TagEntidade(tag_id=body.tag_id, entidade_tipo=body.entidade_tipo, entidade_id=body.entidade_id)
    db.add(te)
    db.commit()
    db.refresh(te)
    return te


@router.delete("/remover", status_code=204)
def remover_tag(tag_id: int, entidade_tipo: str, entidade_id: int, db: Session = Depends(get_db)):
    te = db.query(TagEntidade).filter_by(
        tag_id=tag_id, entidade_tipo=entidade_tipo, entidade_id=entidade_id,
    ).first()
    if not te:
        raise HTTPException(status_code=404, detail="Associacao nao encontrada")
    db.delete(te)
    db.commit()


@router.get("/entidade/{tipo}/{entidade_id}", response_model=list[TagOut])
def listar_tags_entidade(tipo: str, entidade_id: int, db: Session = Depends(get_db)):
    tag_ids = db.query(TagEntidade.tag_id).filter_by(
        entidade_tipo=tipo, entidade_id=entidade_id,
    ).all()
    if not tag_ids:
        return []
    ids = [t[0] for t in tag_ids]
    return db.query(Tag).filter(Tag.id.in_(ids)).order_by(Tag.nome).all()


@router.delete("/{tag_id}", status_code=204)
def deletar_tag(tag_id: int, db: Session = Depends(get_db)):
    tag = db.get(Tag, tag_id)
    if not tag:
        raise HTTPException(status_code=404, detail="Tag nao encontrada")
    db.delete(tag)
    db.commit()
