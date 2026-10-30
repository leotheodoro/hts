# Hard To Submit App · Handoff de produto para brainstorming técnico

Oct 28, 2026 · @Leonardo

Este documento reúne tudo o que já foi decidido sobre como o app funciona, para uma sessão que vai discutir stack, infraestrutura e banco de dados. O design visual está em outro handoff; aqui o foco é comportamento, dados e regras.

## Visão geral

Hard To Submit (HTS) é um app para registrar treinos de preparação física para jiu-jitsu. Ele junta a usabilidade do Hevy com uma camada de progressão: o atleta organiza o ano em arcos, cada arco tem treinos, e cada série concluída vira XP, nível, patente e atributos. O nome anterior do projeto era Obi.

- **Usuário:** hoje um único atleta de BJJ (o próprio Leo), que treina preparação física 3x por semana seguindo planilhas de um preparador. A marca HTS é de vestuário de BJJ, então abrir o app para outros atletas no futuro é possível, mas ainda não foi decidido.
- **Uso principal:** abrir no celular na academia, ver o treino do dia e registrar carga e repetições série por série, com timer de descanso.
- **Plataforma:** mobile-first (largura \~390 px), uso com uma mão, tela ligada durante o treino, tema escuro.
- **Princípio central:** a temática envolve, não esconde. Nomes de exercícios, séries, reps e kg ficam reais e legíveis. A tela de registro tem que ser rápida antes de ser bonita.

Referências: [canvas de design](https://claude.ai/artifact/KzHW9r1MKGRutmzu1niXZ3) (fileira "versão minimalista" na página Hard To Submit) · [handoff original com os treinos reais](https://claude.ai/artifact/VFJQ7L9SfNkTQdVvJUXCET) · [handoff do design system](https://claude.ai/artifact/R8wYCjGSN24XG7vcZ1XKBk).

## Glossário

| Termo | Significado |
| --- | --- |
| Temporada | Uma sequência de arcos com um objetivo (ex.: Jiu-Jitsu, Performance). Só uma fica ativa; cada arco libera o próximo ao terminar. A Manutenção fica fora de qualquer temporada. |
| Arco | Uma fase do programa, criada pelo usuário, com N treinos-modelo e uma duração em semanas. |
| Treino-modelo | A receita de um treino dentro do arco, identificada por letra e nome (ex.: A · Linha de Frente). Antes se chamava "técnica". |
| Treino (sessão) | Uma execução registrada de um treino-modelo, numerada (Treino 5 de 6 no arco; numeração global também existe). Antes se chamava "episódio". |
| Bloco | Grupo de exercícios dentro do treino, com tipo e atributo. |
| Combo | Exercícios em sequência; o descanso vem depois do último. |
| Combo Encadeado | Um exercício logo após o outro, sem pausa, descanso no fim. |
| Round de Luta | Bloco por tempo (6 a 12 min) sem pausa; registra rounds completos em vez de séries. |
| Ativação | Bloco de aquecimento e mobilidade. |
| Limite Quebrado | Recorde pessoal: nova carga máxima num exercício. |
| Patente | O rank do atleta, de E (Recruta) a S (Comandante). |
| Atributos | FOR (força), EXP (explosão), GÁS (resistência), NÚC (núcleo/core), MOB (mobilidade). |
| Sequência | Semanas seguidas batendo a meta semanal de treinos (antes "Chama"). |
| A Batalha | Competição com data cadastrada; o chefe final da temporada. |
| A Véspera | Arco especial de 2 treinos na semana da competição. |
| Filler / Manutenção | Arco livre, sem prazo, sempre disponível (Manutenção, Mobilidade). É um extra: dá XP, mas não conta para a sequência. |

## Modelo de domínio

Este é um rascunho de entidades a partir das regras de produto. Nomes, tipos e normalização ficam para a sessão técnica. A divisão central é entre o **plano** (arco, treino-modelo, bloco, exercício prescrito) e o **registro** (sessão, série feita). O registro guarda uma cópia do que foi prescrito, para o histórico não mudar se o plano for editado depois.

| Entidade | Campos principais | Relações |
| --- | --- | --- |
| Atleta | nome do personagem, descanso padrão (90 s), data da Batalha | tem temporadas, sessões, recordes, títulos |
| Temporada | nome, posição, ativa | pertence ao atleta; tem arcos em ordem |
| Arco | nome, kanji (opcional), programa real, tipo (normal, especial, filler), semanas, data de início, status (atual, concluído, na fila), contagem atual | pertence a uma temporada (ou a nenhuma, se for Manutenção); tem treinos-modelo em ordem |
| Treino-modelo | letra, nome, foco, ordem | pertence ao arco; tem blocos em ordem |
| Bloco | tipo (Ativação, Força, Combo, Combo Encadeado, Round de Luta, Condicionamento, Core, Mobilidade, Cardio), atributo(s), duração em min (só Round de Luta), ordem | pertence ao treino-modelo; tem exercícios prescritos |
| Exercício (catálogo) | nome real, atributo padrão, unidade (reps, segundos, metros, minutos), por lado (sim/não) | usado por vários exercícios prescritos |
| Exercício prescrito | séries (pode ser faixa, ex.: 3 a 4), alvo por série (ex.: 6-6-3-3, 12/12, 10-20 s, máx), descanso próprio (opcional), dica de carga, ordem | pertence ao bloco; aponta para o catálogo |
| Sessão (treino feito) | número global, número no arco, data, início, fim, duração, status (em andamento, concluída), XP ganho, volume | pertence ao atleta; aponta para arco e treino-modelo; tem séries feitas |
| Série feita | nº da série, kg, reps (ou segundos/metros), concluída, hora | pertence à sessão e ao exercício prescrito |
| Round registrado | rounds completos, kg por exercício | pertence à sessão e ao bloco Round de Luta |
| Recorde | exercício, kg, reps, data, sessão | pertence ao atleta |
| Batalha | data, nome, resultado (ouro, prata, bronze, participação) | pertence ao atleta e, opcionalmente, à temporada ativa |
| Título | nome, condição, desbloqueado em | catálogo fixo + estado por atleta |

Dado derivado (calcular ou guardar fica em aberto): XP total, nível, patente, atributos, sequência semanal, "Anterior" de cada série.

## Arcos e treinos

A regra central: **total de treinos do arco = nº de treinos-modelo × nº de semanas**, e esses treinos precisam ser feitos dentro dessas semanas. Exemplo: 3 treinos e 2 semanas = 6 treinos em 14 dias, 3 por semana (A, B, C, A, B, C).

Criação e edição:

- O usuário cria arcos: kanji (opcional), nome, data de início, lista de treinos e semanas. A data de término é início + semanas × 7 − 1.
- Dentro do arco, ele cria treinos novos ou reaproveita treinos existentes. As letras A, B, C... seguem a ordem e podem ser reordenadas.
- Criar treino: letra, nome, foco e blocos. Cada bloco tem tipo, atributo e exercícios com séries × alvo e descanso opcional.
- A meta semanal é igual ao número de treinos do arco.
- "Recomeçar contagem" zera o progresso do arco para refazer o ciclo, mantendo o histórico.
- Os treinos vêm de planilhas reais de um preparador (exemplos no handoff original). Por enquanto a entrada é manual pelo formulário; importar planilha é uma ideia em aberto.

Ordem e sugestão:

- O próximo treino sugerido segue a rotação A, B, C a partir do último feito no arco atual.
- Só um arco é o atual. Ao concluir todos os treinos, aparece a tela de transição e o próximo arco da fila é liberado.
- Ordem típica do ano: Recrutamento (base 1), Forja (base 2), Torneio (repete por temporada bimestral, 3 treinos × 8 semanas = 24), Véspera, Batalha.

Arcos especiais:

- **Filler / Manutenção:** sem duração, disponível a qualquer momento, cargas moderadas a leves. É um extra: dá XP para os atributos, mas não conta para a meta da semana nem para a sequência (ADR 0030).
- **A Véspera:** 1 treino feito 2 vezes na semana da competição; ganha destaque quando a Batalha está a menos de 7 dias.
- **A Batalha:** data cadastrada, contagem regressiva na tela inicial e resultado registrado depois. Fecha a temporada no histórico.

Nomes de treino usados nos mockups: Linha de Frente, Trincheira, Bombardeio (arco I); Blindado, Paraquedista, Marcha Forçada (II); Muralha, Escalada, Couraça (Torneio); Fio da Navalha (Véspera); Patrulha, Sentinela (Manutenção).

## Execução do treino

A tela de treino ativo é a mais usada e a mais crítica. A tabela de séries segue o Hevy; a navegação segue o TrainHeroic (#108).

- **Páginas:** uma por bloco (combo, exercício solo, round de luta). Troca arrastando para os lados ou pelas setas no rodapé ("BLOCO 03 DE 07"). O treino abre no primeiro bloco pendente.
- **Vídeo:** exercício com link do treinador mostra um botão de play ao lado do nome, no treino ativo e na página do treino; toca o vídeo do YouTube num player embutido, já em reprodução e sem sair do app (#110, #112); link que não é do YouTube abre numa folha do Safari. O link fica no catálogo (`exercise.video_url`) e vem do StarterPlan.json local.
- **Bullets:** um quadrado por bloco no topo, cheio em `blood` quando o bloco foi feito (todas as séries marcadas, ou ao menos um round), só a borda quando falta; a bandeira é o slide de finalizar. Tocar num bullet leva à página.

- **Abrir:** "Iniciar treino" cria uma sessão em andamento e dispara o cronômetro geral. Se já houver uma em andamento, o botão vira "Continuar".
- **Minimizar:** o treino pode ser minimizado; aparece uma barra flutuante "Treino em andamento · 32:10" acima das abas. A sessão precisa sobreviver a fechar o app, travar a tela e perder conexão.
- **Tabela de séries:** colunas Série · Anterior · kg · Reps (ou Seg/Min/M) · ✓.
  - "Anterior" mostra o que foi feito na mesma série, na última vez desse mesmo treino-modelo (ex.: 60 × 6).
  - O placeholder de reps é o alvo da planilha; o de kg é a carga anterior.
  - Ao marcar ✓: a linha muda de estado, os campos vazios recebem o alvo e o timer de descanso dispara.
  - Adicionar e remover série dentro da sessão, sem alterar o treino-modelo.
- **Combo:** o timer só dispara no último exercício do combo.
- **Round de Luta:** em vez de séries, um cronômetro do round (ex.: 6 a 8 min), um contador de rounds completos e o kg de cada exercício.
- **Timer de descanso:** fixo no rodapé, com contagem, barra, −15 s, +15 s e Pular. O padrão é 90 s, ajustável no perfil; alguns exercícios têm descanso próprio (ex.: Swing Russo 30 s). Precisa avisar (vibração ou som) mesmo com a tela bloqueada.
- **Finalizar:** é o último slide, com as séries marcadas do total e a lista de blocos (feito ou falta). Com séries não marcadas, pede confirmação na própria tela. Ao concluir: calcula XP, volume, duração, recordes e títulos e mostra a tela "Treino concluído" com a próxima ordem.
- **Histórico:** uma sessão pode ser aberta e excluída pelo Diário; excluir precisa recalcular XP, recordes e sequência.
- **Volume:** soma de kg × reps das séries concluídas. Séries por tempo ou distância não entram.

## Progressão

Toda a progressão vem só de treinar de verdade. Séries concluídas geram XP, o XP define nível e patente, e o tipo de exercício molda os atributos.

| Ação | XP |
| --- | --- |
| Série concluída | +10 |
| Treino concluído | +40 |
| Limite Quebrado (nova carga máxima num exercício) | +25 cada |
| Volume do treino | +1 a cada 500 kg, máx. +60 |

- **Nível:** a curva fica mais lenta com o tempo, ou seja, cada nível pede um pouco mais de XP. A fórmula exata está em aberto. No mockup, o nível 7 vai até 2 000 XP.
- **Patentes:** E Recruta (nível 1 a 4), D Soldado (5 a 9), C Cabo (10 a 14), B Sargento (15 a 21), A Tenente (22 a 29), S Comandante (30+). Subir de patente tem tela própria, diferente de subir de nível.
- **Atributos:** cada bloco ou exercício tem um atributo, e as séries concluídas alimentam esse atributo. São 5 eixos (FOR, EXP, GÁS, NÚC, MOB), mostrados como barras ou radar. A escala (0 a 100? relativa?) está em aberto.
- **Sequência:** a meta é o número de treinos do arco atual por semana (segunda a domingo). Conta semanas seguidas com a meta batida. Não existe sequência diária. Treino de Manutenção conta.
- **Limite Quebrado:** maior kg já registrado num exercício do catálogo. Fica salvo como recorde com data e sessão.
- **Títulos (catálogo fixo):** Primeiro Treino (1º treino) · Recrutamento Concluído (fechar o arco I) · Semana Perfeita (meta da semana batida) · Sequência Acesa (4 semanas seguidas) · Limite Quebrado x10 (10 recordes) · Cem Barras (100 séries de barra fixa) · Pronto para a Batalha (os 2 treinos da Véspera).

## Telas e fluxos

O app só abre com login (docs/decisions/0031). Depois de entrar, tem quatro abas fixas (Home, Arcos, Diário, Perfil) e o treino ativo, que abre por cima de tudo.

- **Login:** 不屈 e o wordmark no centro, "USERNAME OU E-MAIL", "SENHA" e "Entrar". Sem cadastro e sem "esqueci a senha": as contas são criadas no servidor (`pnpm --filter api db:seed`). Erro: "Usuário ou senha incorretos." (não diz qual dos dois). O login é o único momento que precisa de internet.
- **Sessão:** fica no Keychain e não expira. Só sai com "Sair" no Perfil (os dados ficam no aparelho) ou apagando o app (reinstalar pede login). Se o servidor recusar a sessão, o app volta ao login sem apagar os dados.
- **Dados:** tudo vive no servidor e chega pela sincronização depois do login, inclusive os programas do treinador, que não vão mais dentro do app.

| Tela | O que mostra | Dados que lê / escreve |
| --- | --- | --- |
| Login | 不屈, wordmark, username ou e-mail, senha, Entrar | Cria a sessão e puxa os dados da conta |
| Home | Nome, patente, nível, barra de XP, próximo treino com "Ver treino", progresso do arco (4/6), dias até a Batalha, semana atual e sequência | Lê atleta, arco atual, última sessão, Batalha |
| Arcos | Temporadas com seus arcos e os arcos livres; kanji, nome, "3 treinos × 2 semanas", progresso. Tocar abre o arco | Lê temporadas e arcos |
| Arco | Kanji, nome, situação e os treinos; tocar abre o treino | Lê o arco |
| Treino | Somente leitura: blocos, exercícios, séries × alvo, descanso. "Iniciar treino" só no arco atual e nos arcos livres; é o único lugar que inicia treino | Lê o treino-modelo |
| Criar arco | Kanji, nome, início, treinos (criar ou reaproveitar), semanas; resumo com total, ritmo, grade semanal e data de término | Escreve arco e ligações com treinos |
| Editar arco | Os mesmos campos + Recomeçar contagem | Escreve arco |
| Criar treino | Letra, nome, blocos (tipo, atributo), exercícios (séries × alvo, descanso) | Escreve treino-modelo, blocos, prescrições, catálogo |
| Treino ativo | Cabeçalho (nº, nome, cronômetro, bullets), uma página por bloco, slide de finalizar, timer de descanso | Escreve sessão e séries em tempo real; lê "Anterior" |
| Treino concluído | XP ganho, barra de nível, séries, volume, tempo, recordes, próximo treino | Calcula e grava XP, recordes, títulos |
| Rank up / abertura de arco | Telas de momento: nova patente; novo arco com kanji | Lê eventos da conclusão |
| Diário | Totais (treinos, séries, volume), recordes por exercício, lista de treinos mais recentes primeiro | Lê sessões, recordes |
| Detalhe do treino | Todas as séries feitas, excluir | Lê/exclui sessão |
| Perfil | Atributos, títulos, orientações de carga, ajustes (nome, descanso padrão, data e resultado da Batalha) | Lê e escreve atleta |

Orientações de carga mostradas no Perfil e como dica em cada exercício: 1 a 3 reps = 90 a 100% RM; 4 a 6 = 70 a 85%; 8 a 12 = 60 a 75%; acima de 12 = moderada a leve. A dica de cada exercício sai da faixa de reps do alvo.

## Requisitos não funcionais e fora de escopo

O que a stack precisa garantir:

- **Funciona sem internet na academia:** registrar séries, timer e sessão em andamento não podem depender de rede.
- **Sessão resistente:** um treino em andamento sobrevive a fechar o app, travar a tela ou trocar de app, sem perder séries.
- **Timer confiável em segundo plano,** com aviso por vibração ou som.
- **Input rápido:** teclado numérico, alvos de toque de pelo menos 44 px, nenhuma animação atrasando o registro.
- **Mobile-first, uma mão, tema escuro.** Tela ligada durante o treino (wake lock) é desejável.
- **Histórico é permanente:** editar um treino-modelo não altera as sessões já feitas.
- **Backup dos dados:** o histórico de cargas é o ativo principal do usuário.

Fora de escopo agora:

- Social, ranking entre usuários, feed
- Integração com relógio ou apps de saúde
- Personagens ilustrados ou mascote
- Importação automática de planilhas (ideia futura)
- Login e contas: no handoff original estavam fora de escopo; voltam a ser decisão se o app for aberto para outros atletas (ver Perguntas)

## Perguntas abertas para a sessão técnica

Produto (decidir antes da stack):

1. O app é só pessoal ou vai abrir para outros atletas da marca? Isso decide login, contas e multi-tenant.
2. O que acontece se o arco passar do prazo com treinos faltando: estende, fecha incompleto ou marca atraso?
3. Reaproveitar um treino em outro arco copia ou compartilha? Editar a cópia afeta o original?
4. Qual a fórmula da curva de nível e a escala dos atributos?
5. Recorde considera só kg ou também reps (ex.: mais reps com a mesma carga)?
6. O catálogo de exercícios é livre (o usuário digita) ou uma lista curada com sinônimos?

Técnica (pauta da sessão):

1. PWA ou app nativo (React Native/Expo)? Pesa o timer em segundo plano, a vibração, o wake lock e o modo offline.
2. Offline-first com banco local (SQLite, IndexedDB) e sync, ou servidor como fonte da verdade?
3. Banco do servidor, se houver: Postgres com Drizzle, que é o padrão de outros projetos do Leo (ex.: Pine)? Ou um BaaS (Supabase, Firebase)?
4. Calcular XP, nível, atributos e sequência na hora a partir das séries, ou guardar agregados e recalcular quando algo é excluído?
5. Como modelar alvos flexíveis (6-6-3-3, 12/12, 10-20 s, máx, faixas de séries)?
6. Snapshot do plano dentro da sessão (JSON) ou versão do treino-modelo?
7. Backup e exportação: CSV, JSON, conta na nuvem?
8. Hospedagem e custo: Vercel, GCP, Azure, AWS ou nenhum servidor no começo?
