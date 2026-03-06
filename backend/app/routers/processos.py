from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query


def _parse_datajud_datetime(raw: str) -> datetime | None:
    """Converte datas do DataJud que vem em formatos variados."""
    if not raw:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y%m%d%H%M%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(raw, fmt)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(raw)
    except (ValueError, TypeError):
        return None
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Processo, ProcessoParte, Movimento
from app.schemas import (
    ProcessoCreate,
    ProcessoOut,
    ProcessoDetailOut,
    MovimentoOut,
    ProcessoParteCreate,
    ProcessoParteOut,
)
from app.services.datajud import parse_cnj, consultar_processo

router = APIRouter(prefix="/processos", tags=["processos"])


@router.post("/", response_model=ProcessoOut, status_code=201)
def cadastrar_processo(payload: ProcessoCreate, db: Session = Depends(get_db)):
    # 1) Validar CNJ
    parsed = parse_cnj(payload.cnj)
    if parsed is None:
        raise HTTPException(status_code=400, detail="CNJ invalido")

    # 2) Checar duplicidade
    existe = db.query(Processo).filter(Processo.cnj == parsed["cnj"]).first()
    if existe:
        raise HTTPException(status_code=409, detail="Processo ja cadastrado")

    # 3) Consultar DataJud
    dados = consultar_processo(parsed["numero_limpo"], parsed["alias_tribunal"])

    # 4) Criar processo
    processo = Processo(
        cnj=parsed["cnj"],
        numero_limpo=parsed["numero_limpo"],
        tribunal=parsed["codigo_tribunal"],
        alias_tribunal=parsed["alias_tribunal"],
        classe_codigo=dados.get("classe", {}).get("codigo") if dados else None,
        classe_nome=dados.get("classe", {}).get("nome") if dados else None,
        orgao_julgador=dados.get("orgaoJulgador", {}).get("nome") if dados else None,
        grau=dados.get("grau") if dados else None,
        data_ajuizamento=(
            _parse_datajud_datetime(dados.get("dataAjuizamento", ""))
            if dados else None
        ),
        ultima_verificacao=datetime.utcnow(),
    )
    db.add(processo)
    db.flush()

    # 5) Salvar movimentos
    for mov in (dados.get("movimentos") or []) if dados else []:
        data_hora_raw = mov.get("dataHora", "")
        data_hora = _parse_datajud_datetime(data_hora_raw) if data_hora_raw else None
        if data_hora is None:
            data_hora = datetime.utcnow()

        complementos_list = mov.get("complementosTabelados") or []
        complementos_str = (
            "; ".join(
                f"{c.get('nome', '')}: {c.get('valor', '')}"
                for c in complementos_list
            )
            if complementos_list
            else None
        )

        movimento = Movimento(
            processo_id=processo.id,
            codigo=mov.get("codigo", 0),
            nome=mov.get("nome", ""),
            data_hora=data_hora,
            complementos=complementos_str,
        )
        db.add(movimento)

    db.commit()
    db.refresh(processo)
    return processo


@router.get("/", response_model=list[ProcessoOut])
def listar_processos(
    status: str | None = Query(None),
    busca: str | None = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(Processo)
    if status:
        query = query.filter(Processo.status == status)
    if busca:
        query = query.filter(Processo.cnj.contains(busca))
    return query.order_by(Processo.created_at.desc()).all()


@router.get("/{processo_id}", response_model=ProcessoDetailOut)
def detalhe_processo(processo_id: int, db: Session = Depends(get_db)):
    processo = db.query(Processo).filter(Processo.id == processo_id).first()
    if not processo:
        raise HTTPException(status_code=404, detail="Processo nao encontrado")
    return processo


@router.get("/{processo_id}/movimentos", response_model=list[MovimentoOut])
def listar_movimentos(processo_id: int, db: Session = Depends(get_db)):
    processo = db.query(Processo).filter(Processo.id == processo_id).first()
    if not processo:
        raise HTTPException(status_code=404, detail="Processo nao encontrado")
    movimentos = (
        db.query(Movimento)
        .filter(Movimento.processo_id == processo_id)
        .order_by(Movimento.data_hora.desc())
        .all()
    )
    return movimentos


@router.post("/{processo_id}/partes", response_model=ProcessoParteOut, status_code=201)
def vincular_parte(
    processo_id: int,
    payload: ProcessoParteCreate,
    db: Session = Depends(get_db),
):
    processo = db.query(Processo).filter(Processo.id == processo_id).first()
    if not processo:
        raise HTTPException(status_code=404, detail="Processo nao encontrado")

    parte = ProcessoParte(
        processo_id=processo_id,
        cliente_id=payload.cliente_id,
        papel=payload.papel,
    )
    db.add(parte)
    db.commit()
    db.refresh(parte)
    return parte
