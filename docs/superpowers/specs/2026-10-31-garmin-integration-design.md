# Integração com o Garmin: design

Data: 2026-10-31. Status: rascunho para aprovação do Leo.

## Intenção

O Leo corre com um relógio Garmin. Ele quer que essas corridas, e qualquer outra atividade gravada no relógio, entrem no HTS sem digitar nada. Cada atividade dá XP e atributos de acordo com o tipo, e aparece no Diário com um selo do Garmin para que ele saiba de onde veio. A preparação física para o jiu-jitsu não é só o treino de força registrado no app, e a progressão deve refletir o resto do trabalho.

Para isso, o Perfil ganha uma página "Integrações". O Garmin é a primeira integração e o desenho deixa espaço para outras.

## Objetivos

- Conectar e desconectar a conta Garmin pelo app, com status visível.
- Receber automaticamente cada atividade nova do Garmin e guardá-la no histórico do atleta.
- Dar XP pela duração e atributos pelo tipo de atividade.
- Mostrar a atividade no Diário com o selo do Garmin e os dados principais: distância, tempo, pace e FC média.
- Não contar duas vezes um treino feito no HTS que também foi gravado no relógio.

## Fora do escopo

- Importar atividades anteriores à conexão. O plano Starter não manda histórico.
- Mandar treinos do HTS para o relógio. O recurso Training/Courses é só do plano Enterprise.
- Mapa ou percurso, gráfico de FC e laps.
- Outras integrações (Strava, Apple Health). O desenho só não deve impedi-las.
- Editar uma atividade importada no app.

## O que não pode acontecer

- Um treino contar em dobro (HTS mais Garmin) e inflar o XP.
- Uma atividade do Garmin contar para a meta da semana ou para a sequência.
- Uma atividade valer mais XP que um treino de força. Referência: um treino de força típico rende cerca de 300 XP, que é o teto de uma atividade.
- Uma atividade subir um atributo mais rápido que um treino de força sobe o dele.
- Os tokens do Garmin chegarem ao aparelho ou a um arquivo versionado.

## Restrições

- **Plano Starter do Garmin Connect Developer Program** (decisão do Leo). O programa reabriu em 21/10/2026. O Starter é gratuito, aceita até cerca de 1.000 usuários e funciona só por push: o Garmin envia os dados para um endpoint nosso quando o relógio sincroniza.
  - O acesso precisa da aprovação do Garmin. O pedido exige um site público e uma política de privacidade publicada.
  - Até a aprovação sair, a feature é construída e testada com atividades de exemplo. O Leo envia o pedido; o Claude prepara o texto e as páginas.
  - Os detalhes técnicos (fluxo OAuth, formato e assinatura do push, nomes de campos, regras do logo) vêm da documentação oficial, liberada com o acesso. Este documento descreve o comportamento; a implementação confirma os detalhes na documentação antes de codar a parte real.
- **Marca do Garmin:** usar o logo e o azul do kit oficial, seguindo as regras do Garmin. É a única exceção às cores da marca HTS, e vale só para o botão de conectar e para o selo.
- Convenções do repo: offline-first, UUIDv7, `athlete_id`, exclusão lógica, valores derivados nunca guardados, regras de progressão em `progression.json` com implementação em TS e em Swift e fixtures em comum.
- A API só serve o atleta da sessão (ADR 0031).

## Decisões do Leo

1. **Plano Starter**, com o botão "Conectar Garmin" e login no site do Garmin.
2. **Atividade do Garmin é extra:** dá XP e atributos, mas não conta para a meta da semana nem para a sequência, como a Manutenção (ADR 0030).
3. **XP só pelo tempo**, sem considerar esforço (FC, pace): 5 XP por minuto, contando no máximo 60 minutos por atividade. Os atributos recebem 10 XP a cada 4 minutos, a escala de uma série.
4. **Regra contra o dobro:** se a atividade do Garmin se cruza em horário com um treino do HTS, ela não vira treino novo e não dá XP. Ela fica pendurada no treino do HTS e mostra ali a FC média e as calorias. Se não cruza com nenhum treino, entra como treino extra.
5. **Telas** aprovadas nos modelos (`.superpowers/brainstorm/.../garmin-screens.html`):
   - **Integrações sem conexão:** card do Garmin com o logo, uma linha explicando e o botão azul "Conectar Garmin".
   - **Integrações com conexão:** status "Conectado", a conta, o último treino recebido (tipo e quando), o total de treinos importados e o botão "Desconectar".
   - **Diário:** a atividade entre os treinos, com data, "+N XP", nome do tipo (ex.: "Corrida"), o selo GARMIN, a linha "8,2 km · 40 min · 4:53 /km · FC 152" e o atributo (ex.: GÁS).

## Comportamento

### Conectar

1. Em Perfil > Integrações, o atleta toca em "Conectar Garmin".
2. O app abre o login do Garmin numa sessão web segura (`ASWebAuthenticationSession`). O atleta autoriza.
3. O Garmin volta para a API, que troca o código por tokens e guarda tudo no servidor, ligado à conta.
4. O app volta para Integrações com o status "Conectado".

O login precisa de internet. Sem conexão, o botão mostra a mensagem de erro de rede no padrão do app.

### Receber atividades

- O Garmin chama nosso endpoint de push a cada atividade nova. A API confere de que conta Garmin ela é, acha o atleta e grava a atividade.
- A atividade chega ao aparelho pela sync normal (pull), como qualquer outra linha do atleta.
- Atividade repetida (o mesmo id do Garmin) atualiza a existente; nunca cria outra.
- Atividade apagada no Garmin, se o push avisar a exclusão, recebe exclusão lógica no HTS.

### Desconectar

"Desconectar" revoga a autorização no Garmin, se a API dele permitir, e apaga os tokens do servidor. As atividades já importadas continuam no histórico.

### XP e atributos

- **Minutos que contam** = minutos ativos, no máximo **60** por atividade (decisão do Leo). Uma aula de 90 min conta como 60.
- **XP** = minutos que contam × **5**, arredondado (40 min = 200 XP; o teto dá 300 XP, o mesmo de um treino de força típico). Não há teto por dia nem por semana, e a curva de nível não muda por enquanto.
- **XP de atributo** = **10 a cada 4 minutos que contam** (2,5 por minuto, arredondado), para cada atributo do tipo da atividade (decisão do Leo). É a escala de uma série (`setCompleted` = 10) a cada 4 minutos: a corrida de 40 min dá 100 de GÁS; a natação de 40 min dá 100 de GÁS e 100 de FOR.
- Os três valores (teto de 60 min, 5 XP/min, 10 XP de atributo a cada 4 min) ficam em `progression.json`.
- **Atributos** vêm de uma tabela tipo → atributos em `progression.json`. Tabela inicial:

  | Tipo de atividade | Atributos |
  | --- | --- |
  | Corrida (rua, esteira, trilha) | GÁS |
  | Bike, remo, elíptico, caminhada rápida | GÁS |
  | Natação | GÁS, FOR |
  | HIIT, cardio | GÁS, EXP |
  | Yoga, pilates, alongamento | MOB |
  | Musculação | FOR |
  | Luta, artes marciais | GÁS, COR |
  | Desconhecido | nenhum (só XP) |

  Os ids exatos dos tipos vêm da documentação do Garmin.
- XP e atributos de atividade são **derivados** (nunca colunas), calculados em TS e em Swift, com fixtures em `packages/fixtures/`.
- A atividade entra no XP total, no nível, na patente e nos atributos. Fica fora da meta semanal, da sequência e dos títulos ligados a treinos do arco (como a Manutenção).

### Regra contra o dobro

- Uma atividade está **vinculada** a um treino do HTS quando o intervalo dela cruza o intervalo do treino (`started_at` a `finished_at`) em mais da metade da duração da atividade.
- Atividade vinculada não dá XP e não aparece sozinha no Diário. O detalhe do treino do HTS mostra a FC média e as calorias, com o selo do Garmin.
- O vínculo é **derivado** na hora (comparando horários), não guardado. Se o treino do HTS for apagado, a atividade volta a contar sozinha.
- Atividade de qualquer tipo pode ser vinculada, não só musculação.

### Diário

- Atividades não vinculadas entram na lista de treinos em ordem de data, com o card do modelo 3.
- Tocar no card abre um detalhe simples com tipo, data e hora, duração, distância, pace médio, FC média, calorias, XP e atributos.
- Os totais do topo (TREINOS, SÉRIES, VOLUME) continuam contando só os treinos do HTS.

## Dados (proposta para o planejamento confirmar)

- **`imported_activity`** (sincronizada; espelhada no SQLite): `id` (UUIDv7, gerado no servidor), `athlete_id`, `source` ('garmin'), `external_id` (único por `source`), `activity_type` (texto do Garmin), `name`, `started_at`, `duration_seconds`, `distance_meters` (numeric), `average_heart_rate`, `calories`, mais `created_at`, `updated_at`, `deleted_at` e `server_updated_at`. Sem XP, atributos ou vínculo: tudo isso é derivado.
  - O id é gerado no servidor, ao contrário da convenção (UUIDv7 no cliente), porque a linha nasce no servidor. Vira ADR.
- **`integration_connection`** (só no servidor, como `account`): `account_id`, `provider`, ids do usuário no Garmin, tokens criptografados ou guardados conforme a documentação, `connected_at`, `last_activity_at`.
- **Status no app:** um endpoint `GET /v1/integrations` devolve, por provedor, conectado ou não, a conta e a data do último treino recebido. O total de treinos importados sai do SQLite.

## Antes da aprovação do Garmin

- Endpoint de push e importação testados com payloads de exemplo, montados a partir da documentação.
- Em DEBUG, um modo de demonstração cria atividades de exemplo no aparelho para ver o Diário e o progresso.
- Tarefas do Leo: enviar o pedido do Starter; publicar o site e a política de privacidade (o Claude prepara as páginas, que podem ficar no Render).

## Escolhas do Claude (para o Leo conferir)

- Atividade anterior à conexão não entra (limite do Starter).
- Atividade apagada no Garmin recebe exclusão lógica no HTS.
- Vínculo quando o cruzamento de horário passa da metade da duração da atividade.
- Desconectar mantém as atividades já importadas.
- Os totais do topo do Diário continuam contando só os treinos do HTS.
- A tabela de tipos → atributos.
- O id da atividade é gerado no servidor (vira ADR).

## O que fica para quem construir

- O fluxo OAuth exato, a verificação do push e o formato dos tokens, conforme a documentação oficial.
- O nome exato e a forma dos endpoints da API.
- O mapeamento dos ids de tipo do Garmin para a tabela de atributos acima.
- O layout do detalhe da atividade, seguindo o design system.
- A divisão em tickets e a ordem.
