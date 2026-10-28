# 0025 · Hospedagem: Render e Neon

Data: 2026-10-28 · Status: aceita (decisão do Leo, #20) · Substitui 0011

## Decisão
A API roda no Render como serviço web Docker (`render.yaml`, Blueprint) a partir de `apps/api/Dockerfile`, com deploy automático a cada push na `main` e health check em `/health`. O Postgres fica no Neon. O container aplica as migrations antes de subir o servidor; se a migration falhar, o deploy falha e a versão anterior continua no ar.

`DATABASE_URL` e `API_TOKEN` ficam como segredos no painel do Render. O Render acessa o repositório pelo app dele no GitHub, então não há credencial no GitHub Actions.

## Custo
- Render `free`: $0, o serviço dorme após 15 min sem uso e a primeira chamada leva cerca de 1 min. Serve enquanto só o Diagnóstico e a sync usam a API.
- Render `starter`: $7/mês, sempre ligado. Trocar em `plan:` no `render.yaml`.
- Neon free: 0,5 GB, com restauração point-in-time de 24 h.

## Consequências
O CI constrói a imagem Docker em todo PR, para o deploy não quebrar em silêncio.
