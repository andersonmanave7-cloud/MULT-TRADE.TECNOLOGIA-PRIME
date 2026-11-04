# Base de dados (Supabase)

Projeto: `multtrade` (id `achjmbapqobhmydhjmol`, região eu-west-2).

## Migrações
Cada alteração de estrutura ou de funções fica num ficheiro SQL nesta pasta, numerado pela data.
Aplicar por ordem, no SQL Editor do Supabase ou com a CLI (`supabase db push`).

- `20261104_place_order_variants_and_product_images.sql`: função `place_order` com variantes e bucket `product-images`.

As migrações anteriores (esquema, RLS, funções de catálogo e o ajuste 04) estão aplicadas no projeto.
Antes de este repositório ser usado noutro projeto, exporte o esquema completo com `supabase db dump`.

## Regras de segurança
- O site usa só a chave publicável.
- A chave `service_role` e a senha da base de dados nunca entram no repositório.
