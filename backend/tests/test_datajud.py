from app.services.datajud import parse_cnj, TRIBUNAL_MAP


def test_parse_cnj_valido():
    result = parse_cnj("0702906-79.2026.8.07.0020")
    assert result["numero_limpo"] == "07029067920268070020"
    assert result["codigo_tribunal"] == "8.07"
    assert result["alias_tribunal"] == "tjdft"


def test_parse_cnj_trf1():
    result = parse_cnj("0000832-35.2018.4.01.3202")
    assert result["alias_tribunal"] == "trf1"


def test_parse_cnj_invalido():
    assert parse_cnj("12345") is None
    assert parse_cnj("") is None


def test_tribunal_map_cobertura():
    assert len(TRIBUNAL_MAP) >= 90
