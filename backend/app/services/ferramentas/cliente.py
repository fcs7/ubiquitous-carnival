from sqlalchemy.orm import Session
from app.models import Cliente


SCHEMA_BUSCAR_CLIENTE = {
    "name": "buscar_cliente",
    "description": "Busca dados de um cliente por nome ou CPF/CNPJ. Retorna dados pessoais, contato e endereco.",
    "input_schema": {
        "type": "object",
        "properties": {
            "busca": {
                "type": "string",
                "description": "Nome parcial ou CPF/CNPJ do cliente",
            },
        },
        "required": ["busca"],
    },
}


def executar_buscar_cliente(input_data: dict, db: Session) -> str:
    busca = input_data.get("busca", "").strip()
    if not busca:
        return "Parametro de busca vazio."

    cliente = db.query(Cliente).filter(Cliente.cpf_cnpj == busca).first()
    if not cliente:
        clientes = (
            db.query(Cliente)
            .filter(Cliente.nome.ilike(f"%{busca}%"))
            .limit(5)
            .all()
        )
        if not clientes:
            return f"Nenhum cliente encontrado para '{busca}'."
        if len(clientes) == 1:
            cliente = clientes[0]
        else:
            linhas = [f"Encontrados {len(clientes)} clientes:"]
            for c in clientes:
                linhas.append(f"  ID {c.id}: {c.nome} (CPF/CNPJ: {c.cpf_cnpj})")
            return "\n".join(linhas)

    linhas = [
        f"CLIENTE: {cliente.nome}",
        f"CPF/CNPJ: {cliente.cpf_cnpj}",
        f"Telefone: {cliente.telefone}",
    ]
    if cliente.email:
        linhas.append(f"Email: {cliente.email}")
    if cliente.endereco:
        linhas.append(f"Endereco: {cliente.endereco}")
        if cliente.cidade:
            linhas.append(f"Cidade: {cliente.cidade}/{cliente.uf} CEP: {cliente.cep or 'N/A'}")
    if cliente.profissao:
        linhas.append(f"Profissao: {cliente.profissao}")
    if cliente.estado_civil:
        linhas.append(f"Estado Civil: {cliente.estado_civil}")

    return "\n".join(linhas)
