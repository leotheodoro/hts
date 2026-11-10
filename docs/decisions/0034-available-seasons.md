# 0034 · Temporadas disponíveis e troca de temporada recomeça o arco

Data: 2026-11-10 · Status: aceita (decisão do Leo, #204). Substitui em parte a 0029 (troca de temporada e tela de Arcos).

## Contexto
O Leo vai cadastrar mais temporadas além da Jiu-Jitsu. Com todas listadas na aba Arcos, a tela fica gigante. E, ao trocar de programa, ele quer recomeçar o arco em que parou, e não retomar a contagem antiga.

## Decisão
- A aba Arcos mostra só a temporada ativa e os arcos livres (Manutenção). No topo, ao lado do título, fica o botão "Temporadas disponíveis".
- "Temporadas disponíveis" lista todas as temporadas, com a ativa marcada, o número de arcos e quantos estão concluídos. Cada temporada abre uma página com os arcos em ordem: concluídos, o próximo (PRÓXIMO) e os bloqueados. Cada arco abre a página do arco.
- "Ativar temporada" pede confirmação na tela e diz o que muda.
- Ao ativar outra temporada, o arco atual da anterior volta para a fila e a contagem dele recomeça (`count_reset_at`, o mesmo campo de "Recomeçar contagem"). XP, nível, treinos feitos e arcos concluídos continuam. Ao reativar a temporada, ela volta a esse arco com a contagem do zero.
- As temporadas novas entram pelo seed da API (`apps/api/seed`, fora do git, porque os programas são licenciados) e chegam ao app pela sincronização.

## Consequências
Nenhuma coluna nova: a troca grava `count_reset_at` e `updated_at` no arco pausado, e a sincronização leva isso ao servidor.
