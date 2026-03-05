import requests
from bs4 import BeautifulSoup
import re

cnj = input("Digite CNJ novamente: ") or "0702906-79.2026.8.07.0020"
# TJDFT usa PJe ou consulta específica (8.07=DF), fallback TJSP ou Jus.br
urls = [
    f'https://esaj.tjsp.jus.br/cpopg/open.do?gateway=true&numero={cnj.replace("-","").replace(".","")}',
    f'https://www.jus.br/processos/consulta?cnj={cnj}'  # Jus.br unificado
]

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

for i, url in enumerate(urls, 1):
    print(f"\n🔍 Tentativa {i}: {url}")
    try:
        resp = requests.get(url, headers=headers, timeout=10)
        print(f"Status: {resp.status_code}")
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, 'html.parser')
            
            # Título
            titulo = soup.find('h1') or soup.find('h2') or soup.find('title')
            print(f"📄 Título: {titulo.text.strip() if titulo else 'N/A'}")
            
            # Andamentos comuns (ESAJ/PJe)
            selectors = ['.andamentoLista li', '.processoAndamento .item', '.movimentacao', 'td[class*="andamento"]', '.classeMovimentacao']
            for sel in selectors:
                elems = soup.select(sel)
                if elems:
                    print(f"\n🔥 ANDAMENTOS ({len(elems)} encontrados):")
                    for j, elem in enumerate(elems[-5:], 1):
                        texto = re.sub(r'\s+', ' ', elem.get_text(strip=True))[:200]
                        print(f"{j}. {texto}")
                    break
            else:
                print("📝 HTML salvo pra você inspecionar:")
                with open('pagina_processo.html', 'w', encoding='utf-8') as f:
                    f.write(resp.text)
                print("Abra 'pagina_processo.html' no browser > F12 > ache 'andamento'")
            
            break
    except Exception as e:
        print(f"Erro: {e}")

print("\n🚀 Se pegou andamentos, adicione: pip install openai && openai resumo!")
