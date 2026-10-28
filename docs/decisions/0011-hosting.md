# 0011 · Hospedagem: Cloud Run e Neon

Data: 2026-10-28 · Status: substituída por 0025

## Decisão
API em container no GCP Cloud Run (escuta em `$PORT`) e Postgres no Neon. Agora só o Dockerfile multi-stage fica pronto; o deploy é ticket próprio.

## Consequências
A API precisa ser stateless e subir rápido. `DATABASE_URL` vem do ambiente.
