import re
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query
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

# Mapeamento de tribunais (J.TT -> alias)
TRIBUNAL_MAP = {
    "5.00": "tst", "6.00": "tse", "3.00": "stj", "7.00": "stm",
    **{f"4.{t:02d}": f"trf{t}" for t in range(1, 7)},
    **{f"5.{t:02d}": f"trt{t}" for t in range(1, 25)},
    "8.01": "tjac", "8.02": "tjal", "8.03": "tjap", "8.04": "tjam",
    "8.05": "tjba", "8.06": "tjce", "8.07": "tjdft", "8.08": "tjes",
    "8.09": "tjgo", "8.10": "tjma", "8.11": "tjmt", "8.12": "tjms",
    "8.13": "tjmg", "8.14": "tjpa", "8.15": "tjpb", "8.16": "tjpr",
    "8.17": "tjpe", "8.18": "tjpi", "8.19": "tjrj", "8.20": "tjrn",
    "8.21": "tjrs", "8.22": "tjro", "8.23": "tjrr", "8.24": "tjsc",
    "8.25": "tjse", "8.26": "tjsp", "8.27": "tjto",
    "6.01": "tre-ac", "6.02": "tre-al", "6.03": "tre-ap", "6.04": "tre-am",
    "6.05": "tre-ba", "6.06": "tre-ce", "6.07": "tre-dft", "6.08": "tre-es",
    "6.09": "tre-go", "6.10": "tre-ma", "6.11": "tre-mt", "6.12": "tre-ms",
    "6.13": "tre-mg", "6.14": "tre-pa", "6.15": "tre-pb", "6.16": "tre-pr",
    "6.17": "tre-pe", "6.18": "tre-pi", "6.19": "tre-rj", "6.20": "tre-rn",
    "6.21": "tre-rs", "6.22": "tre-ro", "6.23": "tre-rr", "6.24": "tre-sc",
    "6.25": "tre-se", "6.26": "tre-sp", "6.27": "tre-to",
    "9.13": "tjmmg", "9.21": "tjmrs", "9.26": "tjmsp",
}

CNJ_REGEX = re.compile(r"^(\d{7})-(\d{2})\.(\d{4})\.(\d)\.(\d{2})\.(\d{4})$")


def parse_cnj(cnj: str) -> dict | None:
    match = CNJ_REGEX.match(cnj.strip())
    if not match:
        return None
    j, tt = match.group(4), match.group(5)
    return {
        "cnj": cnj.strip(),
        "numero_limpo": cnj.replace("-", "").replace(".", ""),
        "codigo_tribunal": f"{j}.{tt}",
        "alias_tribunal": TRIBUNAL_MAP.get(f"{j}.{tt}"),
    }


router = APIRouter(prefix="/processos", tags=["processos"])


@router.post("/", response_model=ProcessoOut, status_code=201)
def cadastrar_processo(payload: ProcessoCreate, db: Session = Depends(get_db)):
    parsed = parse_cnj(payload.cnj)
    if parsed is None:
        raise HTTPException(status_code=400, detail="CNJ invalido")

    existe = db.query(Processo).filter(Processo.cnj == parsed["cnj"]).first()
    if existe:
        raise HTTPException(status_code=409, detail="Processo ja cadastrado")

    processo = Processo(
        cnj=parsed["cnj"],
        numero_limpo=parsed["numero_limpo"],
        tribunal=parsed["codigo_tribunal"],
        alias_tribunal=parsed["alias_tribunal"],
    )
    db.add(processo)
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
