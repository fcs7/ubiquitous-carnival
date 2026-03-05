"""
Consulta de processos na API Publica do DataJud (CNJ).
Uso: python consulta_datajud.py [numero_cnj]
"""

import sys
import json
import re
import requests

API_KEY = "cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw=="
BASE_URL = "https://api-publica.datajud.cnj.jus.br"

# Mapeamento J.TT do CNJ -> alias do tribunal na API
# J=3 STJ, J=4 Federal, J=5 Trabalho, J=6 Eleitoral, J=7 Militar, J=8 Estadual, J=9 Militar Estadual
TRIBUNAL_MAP = {
    # Tribunais Superiores
    "5.00": "tst",
    "6.00": "tse",
    "3.00": "stj",
    "7.00": "stm",
    # Justica Federal (J=4, TT=01-06)
    **{f"4.{t:02d}": f"trf{t}" for t in range(1, 7)},
    # Justica do Trabalho (J=5, TT=01-24)
    **{f"5.{t:02d}": f"trt{t}" for t in range(1, 25)},
    # Justica Estadual (J=8, TT=01-27)
    "8.01": "tjac", "8.02": "tjal", "8.03": "tjap", "8.04": "tjam",
    "8.05": "tjba", "8.06": "tjce", "8.07": "tjdft", "8.08": "tjes",
    "8.09": "tjgo", "8.10": "tjma", "8.11": "tjmt", "8.12": "tjms",
    "8.13": "tjmg", "8.14": "tjpa", "8.15": "tjpb", "8.16": "tjpr",
    "8.17": "tjpe", "8.18": "tjpi", "8.19": "tjrj", "8.20": "tjrn",
    "8.21": "tjrs", "8.22": "tjro", "8.23": "tjrr", "8.24": "tjsc",
    "8.25": "tjse", "8.26": "tjsp", "8.27": "tjto",
    # Justica Eleitoral (J=6, TT=01-27)
    "6.01": "tre-ac", "6.02": "tre-al", "6.03": "tre-ap", "6.04": "tre-am",
    "6.05": "tre-ba", "6.06": "tre-ce", "6.07": "tre-dft", "6.08": "tre-es",
    "6.09": "tre-go", "6.10": "tre-ma", "6.11": "tre-mt", "6.12": "tre-ms",
    "6.13": "tre-mg", "6.14": "tre-pa", "6.15": "tre-pb", "6.16": "tre-pr",
    "6.17": "tre-pe", "6.18": "tre-pi", "6.19": "tre-rj", "6.20": "tre-rn",
    "6.21": "tre-rs", "6.22": "tre-ro", "6.23": "tre-rr", "6.24": "tre-sc",
    "6.25": "tre-se", "6.26": "tre-sp", "6.27": "tre-to",
    # Justica Militar Estadual (J=9)
    "9.13": "tjmmg", "9.21": "tjmrs", "9.26": "tjmsp",
}


def parse_cnj(cnj: str) -> dict:
    """Extrai componentes do numero CNJ (formato NNNNNNN-DD.AAAA.J.TT.OOOO)."""
    cnj = cnj.strip()
    match = re.match(r"^(\d{7})-(\d{2})\.(\d{4})\.(\d)\.(\d{2})\.(\d{4})$", cnj)
    if not match:
        return None
    return {
        "numero": match.group(1),
        "digito": match.group(2),
        "ano": match.group(3),
        "justica": match.group(4),
        "tribunal": match.group(5),
        "origem": match.group(6),
        "codigo_tribunal": f"{match.group(4)}.{match.group(5)}",
        "numero_limpo": cnj.replace("-", "").replace(".", ""),
    }


def identificar_tribunal(codigo: str) -> str:
    """Retorna o alias do tribunal na API DataJud."""
    alias = TRIBUNAL_MAP.get(codigo)
    if not alias:
        raise ValueError(f"Tribunal desconhecido para codigo {codigo}")
    return alias


def consultar_processo(numero_limpo: str, alias_tribunal: str) -> dict:
    """Faz a consulta na API DataJud."""
    url = f"{BASE_URL}/api_publica_{alias_tribunal}/_search"
    headers = {
        "Authorization": f"APIKey {API_KEY}",
        "Content-Type": "application/json",
    }
    body = {
        "query": {
            "match": {
                "numeroProcesso": numero_limpo
            }
        }
    }

    resp = requests.post(url, headers=headers, json=body, timeout=30)
    resp.raise_for_status()
    return resp.json()


def exibir_resultado(data: dict):
    """Exibe os dados do processo de forma legivel."""
    hits = data.get("hits", {}).get("hits", [])

    if not hits:
        print("\nNenhum processo encontrado.")
        return

    for hit in hits:
        proc = hit.get("_source", {})
        print("\n" + "=" * 60)
        print(f"PROCESSO: {proc.get('numeroProcesso', 'N/A')}")
        print(f"TRIBUNAL: {proc.get('tribunal', 'N/A')}")
        print(f"GRAU: {proc.get('grau', 'N/A')}")
        print(f"CLASSE: {proc.get('classe', {}).get('nome', 'N/A')} (cod: {proc.get('classe', {}).get('codigo', 'N/A')})")
        print(f"DATA AJUIZAMENTO: {proc.get('dataAjuizamento', 'N/A')}")
        print(f"SIGILO: {proc.get('nivelSigilo', 'N/A')}")
        print(f"FORMATO: {proc.get('formato', {}).get('nome', 'N/A')}")
        print(f"SISTEMA: {proc.get('sistema', {}).get('nome', 'N/A')}")
        print(f"ORGAO JULGADOR: {proc.get('orgaoJulgador', {}).get('nome', 'N/A')}")
        print(f"ULTIMA ATUALIZACAO: {proc.get('dataHoraUltimaAtualizacao', 'N/A')}")

        assuntos = proc.get("assuntos", [])
        if assuntos:
            print(f"\nASSUNTOS ({len(assuntos)}):")
            for a in assuntos:
                print(f"  - {a.get('nome', 'N/A')} (cod: {a.get('codigo', 'N/A')})")

        movimentos = proc.get("movimentos", [])
        if movimentos:
            # Ordena por data (mais recente primeiro)
            movimentos_sorted = sorted(
                movimentos,
                key=lambda m: m.get("dataHora", ""),
                reverse=True,
            )
            print(f"\nMOVIMENTOS ({len(movimentos)} total, mostrando ultimos 10):")
            for m in movimentos_sorted[:10]:
                data_hora = m.get("dataHora", "N/A")
                nome = m.get("nome", "N/A")
                complementos = m.get("complementosTabelados", [])
                comp_str = ""
                if complementos:
                    partes = [f"{c.get('nome', '')}: {c.get('valor', '')}" for c in complementos if c.get('valor')]
                    if partes:
                        comp_str = f" [{', '.join(partes)}]"
                print(f"  {data_hora} | {nome}{comp_str}")
        print("=" * 60)

    # Mostra o JSON bruto do primeiro hit para referencia
    print("\n--- JSON BRUTO (primeiro resultado) ---")
    print(json.dumps(hits[0]["_source"], indent=2, ensure_ascii=False))


def main():
    cnj = sys.argv[1] if len(sys.argv) > 1 else "0702906-79.2026.8.07.0020"
    print(f"Consultando CNJ: {cnj}")

    parsed = parse_cnj(cnj)
    if not parsed:
        print(f"ERRO: formato CNJ invalido. Use NNNNNNN-DD.AAAA.J.TT.OOOO")
        sys.exit(1)

    print(f"Numero limpo: {parsed['numero_limpo']}")
    print(f"Codigo tribunal: {parsed['codigo_tribunal']}")

    alias = identificar_tribunal(parsed["codigo_tribunal"])
    print(f"Tribunal: {alias.upper()}")
    print(f"Endpoint: {BASE_URL}/api_publica_{alias}/_search")

    print("\nFazendo requisicao...")
    resultado = consultar_processo(parsed["numero_limpo"], alias)
    exibir_resultado(resultado)


if __name__ == "__main__":
    main()
