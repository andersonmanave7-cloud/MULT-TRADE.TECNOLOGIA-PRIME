# MULT TRADE · Tecnologia Prime

Loja online da Mult Trade: produtos da África do Sul entregues em Moçambique.

## Estrutura

```
index.html                  Loja pública (site estático, liga-se ao Supabase)
vercel.json                 Configuração do Vercel (site estático, sem build)
assets/                     Recursos fixos (logótipos, ícones)
admin/                      Painel de administração (por construir)
supabase/
  README.md                 Como funciona a base de dados
  migrations/               Alterações SQL, numeradas pela data
.env.example                Variáveis (apenas referência; o site não precisa delas)
```

## Publicar no Vercel
1. No Vercel: **Add New → Project** e escolha este repositório.
2. Framework preset: **Other**. Build command vazio. Output directory vazio (a raiz).
3. **Deploy**. Cada alteração no GitHub gera um novo deploy automaticamente.

## Base de dados
O site lê e escreve no Supabase (projeto `multtrade`). As alterações no Supabase
aparecem no site imediatamente, sem novo deploy. Ver `supabase/README.md`.

## Segurança
- Só a chave publicável é usada no site.
- Nunca commitar a chave `service_role`, senhas ou ficheiros `.env` com segredos.
