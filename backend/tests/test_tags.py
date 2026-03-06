from app.models import Cliente, Tag, TagEntidade


def test_criar_tag(client):
    r = client.post("/tags/", json={"nome": "Urgente", "cor": "#FF0000"})
    assert r.status_code == 201
    assert r.json()["nome"] == "Urgente"
    assert r.json()["cor"] == "#FF0000"


def test_listar_tags(client, db):
    db.add(Tag(nome="A"))
    db.add(Tag(nome="B"))
    db.commit()

    r = client.get("/tags/")
    assert r.status_code == 200
    assert len(r.json()) == 2
    assert r.json()[0]["nome"] == "A"  # ordenado por nome


def test_deletar_tag(client, db):
    tag = Tag(nome="Deletar")
    db.add(tag)
    db.commit()
    tag_id = tag.id

    r = client.delete(f"/tags/{tag_id}")
    assert r.status_code == 204

    db.expire_all()
    assert db.query(Tag).filter_by(id=tag_id).first() is None


def test_aplicar_tag_a_cliente(client, db):
    tag = Tag(nome="VIP")
    cliente = Cliente(nome="Teste", cpf_cnpj="999", telefone="11111")
    db.add_all([tag, cliente])
    db.commit()

    r = client.post("/tags/aplicar", json={
        "tag_id": tag.id, "entidade_tipo": "cliente", "entidade_id": cliente.id,
    })
    assert r.status_code == 201
    assert r.json()["tag_id"] == tag.id
    assert r.json()["entidade_tipo"] == "cliente"


def test_aplicar_tag_a_processo(client, db):
    from app.models import Processo
    tag = Tag(nome="Criminal")
    processo = Processo(cnj="0000004-00.2026.8.26.0001", numero_limpo="00000040020268260001",
                        tribunal="TJSP", alias_tribunal="tjsp")
    db.add_all([tag, processo])
    db.commit()

    r = client.post("/tags/aplicar", json={
        "tag_id": tag.id, "entidade_tipo": "processo", "entidade_id": processo.id,
    })
    assert r.status_code == 201


def test_listar_tags_entidade(client, db):
    tag1 = Tag(nome="Tag1")
    tag2 = Tag(nome="Tag2")
    cliente = Cliente(nome="Multi", cpf_cnpj="888", telefone="22222")
    db.add_all([tag1, tag2, cliente])
    db.commit()

    client.post("/tags/aplicar", json={"tag_id": tag1.id, "entidade_tipo": "cliente", "entidade_id": cliente.id})
    client.post("/tags/aplicar", json={"tag_id": tag2.id, "entidade_tipo": "cliente", "entidade_id": cliente.id})

    r = client.get(f"/tags/entidade/cliente/{cliente.id}")
    assert r.status_code == 200
    assert len(r.json()) == 2


def test_remover_tag(client, db):
    tag = Tag(nome="Remover")
    cliente = Cliente(nome="Rem", cpf_cnpj="777", telefone="33333")
    db.add_all([tag, cliente])
    db.commit()

    client.post("/tags/aplicar", json={"tag_id": tag.id, "entidade_tipo": "cliente", "entidade_id": cliente.id})

    r = client.request("DELETE", "/tags/remover", params={
        "tag_id": tag.id, "entidade_tipo": "cliente", "entidade_id": cliente.id,
    })
    assert r.status_code == 204


def test_deletar_tag_cascade(client, db):
    tag = Tag(nome="Cascade")
    db.add(tag)
    db.commit()

    client.post("/tags/aplicar", json={"tag_id": tag.id, "entidade_tipo": "cliente", "entidade_id": 1})
    client.post("/tags/aplicar", json={"tag_id": tag.id, "entidade_tipo": "processo", "entidade_id": 1})

    r = client.delete(f"/tags/{tag.id}")
    assert r.status_code == 204

    assert db.query(TagEntidade).filter_by(tag_id=tag.id).count() == 0


def test_unique_constraint_tag_entidade(client, db):
    tag = Tag(nome="Unica")
    cliente = Cliente(nome="Dup", cpf_cnpj="666", telefone="44444")
    db.add_all([tag, cliente])
    db.commit()

    r1 = client.post("/tags/aplicar", json={"tag_id": tag.id, "entidade_tipo": "cliente", "entidade_id": cliente.id})
    assert r1.status_code == 201

    # Aplicar novamente retorna o existente (idempotente)
    r2 = client.post("/tags/aplicar", json={"tag_id": tag.id, "entidade_tipo": "cliente", "entidade_id": cliente.id})
    assert r2.status_code == 201
    assert r2.json()["id"] == r1.json()["id"]


def test_entidade_tipo_invalido(client, db):
    tag = Tag(nome="Invalido")
    db.add(tag)
    db.commit()

    r = client.post("/tags/aplicar", json={"tag_id": tag.id, "entidade_tipo": "xpto", "entidade_id": 1})
    assert r.status_code == 400
