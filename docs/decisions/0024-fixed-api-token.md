# 0024 · Token fixo na API

Data: 2026-10-28 · Status: substituída pela 0031 (contas)

## Decisão
Enquanto o app tiver um atleta só, `/v1/*` exige `Authorization: Bearer <API_TOKEN>`. O token tem pelo menos 32 caracteres (`openssl rand -hex 32`), vem da variável `API_TOKEN` na API e de `HTS_API_TOKEN` no `apps/ios/Local.xcconfig` (fora do git). A comparação é em tempo constante. `/health` continua público.

## Consequências
- O token fica embutido no binário do app: aceitável só para uso pessoal. Se o app abrir para outros atletas, entra autenticação de verdade (Sign in with Apple) e acesso por `athlete_id`.
- Trocar o token = mudar no Render e no `Local.xcconfig` e reinstalar o app.
