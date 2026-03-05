from unittest.mock import patch, MagicMock
from app.services.ia import traduzir_movimento


def test_traduzir_movimento_sucesso():
    mock_resp = MagicMock()
    mock_resp.choices = [MagicMock()]
    mock_resp.choices[0].message.content = "O processo foi distribuido para um juiz."

    with patch("app.services.ia.get_client") as mock_client:
        mock_client.return_value.chat.completions.create.return_value = mock_resp
        resultado = traduzir_movimento("Distribuicao", "competencia exclusiva")

    assert "distribuido" in resultado.lower()


def test_traduzir_movimento_erro():
    with patch("app.services.ia.get_client") as mock_client:
        mock_client.return_value.chat.completions.create.side_effect = Exception("API error")
        resultado = traduzir_movimento("Distribuicao")

    assert "Distribuicao" in resultado
    assert "indisponivel" in resultado
