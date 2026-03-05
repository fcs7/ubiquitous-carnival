from unittest.mock import patch, MagicMock
from app.services.whatsapp import formatar_notificacao, enviar_mensagem


def test_formatar_notificacao():
    msg = formatar_notificacao("0000832-35.2018.4.01.3202", "O juiz deu uma decisao.")
    assert "0000832-35.2018.4.01.3202" in msg
    assert "O juiz deu uma decisao." in msg
    assert "Muglia" in msg


@patch("app.services.whatsapp.requests.post")
def test_enviar_mensagem_sucesso(mock_post):
    mock_post.return_value = MagicMock(status_code=201)
    assert enviar_mensagem("61999998888", "teste") is True


@patch("app.services.whatsapp.requests.post")
def test_enviar_mensagem_erro(mock_post):
    mock_post.side_effect = Exception("Connection error")
    assert enviar_mensagem("61999998888", "teste") is False
