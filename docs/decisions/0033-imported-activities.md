# 0033 · Atividades importadas (Garmin)

Data: 2026-10-31 · Status: aceita (spec `docs/superpowers/specs/2026-10-31-garmin-integration-design.md`, #162).

## Decisão
- **`imported_activity`:** guarda cada atividade que chega de outra plataforma (hoje o Garmin). É sincronizada como as outras tabelas do atleta e espelhada no SQLite.
  - Exceção à 0009: o `id` (UUIDv7) é gerado no **servidor**, porque a linha nasce lá, no push do Garmin. O app só lê.
  - `(source, external_id)` é único: uma atividade repetida atualiza a linha existente.
- **XP, atributos e vínculo:** o XP e os atributos da atividade, e o vínculo com um treino do HTS (horários que se cruzam em mais da metade da duração dela), são **derivados** de `progression.json`, nunca colunas. Apagar o treino desfaz o vínculo sozinho.
- **`integration_connection`:** guarda a ligação da conta com a plataforma, com os tokens. Fica **só no servidor**, como `account` e `auth_session`, e os tokens nunca vão para o aparelho.

## Consequências
- A atividade é um extra, como a Manutenção (0030): dá XP, nível, patente e atributos, e fica fora da meta semanal, da sequência e dos títulos.
- `imported_activity` é só de puxar: o app não a envia no push, e a API ignora linhas dessa tabela num push (#176). Só o import do Garmin escreve nela.
