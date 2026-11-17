# Nutcracker Simulator — Histórico, plano e cards para o Trello

Estado em 17/11/2026 — último commit `2570f2f` (branch `master`, sem remoto).
Cada card abaixo foi pensado para virar **um card do Trello**: título, lista, etiqueta de ferramenta, tamanho,
dependências, descrição, critério de pronto e um prompt pronto para colar no Claude Code ou no Codex.

---

## 1. O que já foi feito

| Commit | Entrega |
|---|---|
| `6836203` | **Round 01** — mapa Acorn Meadow, 3 nozes (Acorn, Walnut, Golden Nut), atribuição de alvo, dano por tick no servidor, moedas, loja de Força, HUD inicial. Spec de referências em `docs/NUTCRACKER_REFERENCE_SPEC.md`. |
| `202d20e` | **Round 01.1** — clique só atribui (sem golpe extra), sem reatribuição automática, kit de UI `Ui.luau`, HUD refeita e responsiva (desktop / celular deitado / em pé), nozes e mapa mais caprichados. |
| `bf71a32` | **Round 02** — 3 ovos com chances, 10 pets (esquilos procedurais), inventário (50), equipar até 3, pets seguem e atacam junto (`attackUnits`). |
| `81fc46e` | Peças de arte do ForgeGUI: botão verde (9-slice) e moeda de bolota (`Assets.luau`, `Ui.imageButton`). |
| `0530db5` | **Progressão** — Diamonds, 6 upgrades permanentes, Rebirth, sorte nos ovos, Attack Speed por jogador, fórmulas centralizadas em `Progression.luau`. |
| `60a3136` | Correções: texto do botão de upgrade, luz estourada no place do Rojo. |
| `6c74650` | **Coleção** — Pet Index (10 espécies, silhuetas), descobertas no servidor, 3 marcos com recompensa (3/6/10), troca direta entre painéis. |
| `123ea13` | **Marreta evolutiva** — 5 tiers (Starter → Cosmic), desbloqueio por Força e rebirth, impacto por tier, banner e indicador na HUD. |
| `c9629d4` | **Multiplayer** — todos veem a marreta de todos (`PlayerHammers.luau`), testado com 2 jogadores reais. |
| `ab25f5e` | **Persistência** — DataStore isolado por PlaceId (ambiente de teste), trava de sessão, migração v1→v4, validado com DataStore real. |
| `2570f2f` | Persistência: espera de 30 s antes de assumir trava viva, expulsão ao perder a sessão, motivo de cada save (`lastSave`). |

**Fora do código, já existe:** experiência privada de teste publicada (PlaceId `111667852947708`, universo `10777051784`),
2 assets de imagem aprovados no Roblox (botão `134086932952272`, moeda `87878445232429`).

**Persistência em produção: DESLIGADA** (`Persistence.Environments` → `production.enabled = false`).

---

## 2. Como trabalhar em dois (Claude + Codex)

**Quando usar cada um**
- **Claude Code** (nesta máquina): tem o **Roblox Studio MCP** (rodar Play, capturar tela, testar com 2 jogadores,
  ler/gravar DataStore de teste). Use para tudo que precisa ser **visto ou testado no Studio**.
- **Codex**: ótimo para **código e documentação que não dependem do Studio** — refatoração, lógica pura, scripts de teste,
  configuração de ferramentas, revisão. O resultado depois passa por um card de validação no Studio (Claude).
- Se o Codex do seu amigo também tiver um MCP do Studio configurado, os cards "Claude" podem ir para ele também.

**Regras para não se atropelarem**
1. **Um card = uma branch** (`card/<número>-nome`). Nada direto em `master`.
2. Arquivos "quentes" que quase todo card toca: `src/client/Hud.luau`, `src/server/PlayerData.luau`,
   `src/client/init.client.luau`, `src/server/init.server.luau`. **Não peguem dois cards que mexem no mesmo
   arquivo quente ao mesmo tempo** — o card diz quais arquivos toca.
3. Os dois leem `CLAUDE.md` antes de começar (o Codex também: é a documentação da arquitetura). Quem mudar a
   arquitetura atualiza o `CLAUDE.md` no mesmo card.
4. **Repositório compartilhado:** hoje o projeto não tem remoto e o `CLAUDE.md` proíbe push. Para trabalharem em dois
   vocês precisam decidir onde fica o repositório (ex.: GitHub privado) e então ajustar a regra "Não fazer push" no
   `CLAUDE.md`. Até lá, troquem patches (`git format-patch`).
5. Nunca publicar o jogo, nunca ligar `production` em `Persistence.luau` sem o card P5.
6. Ferramentas de teste no Studio (barra de comando do **servidor**): `DevCoins`, `DevDiamonds`, `DevPet`,
   `DevTarget`, `DevReload` — ver `CLAUDE.md`.

**Etiquetas sugeridas no Trello:** `Claude (Studio)` · `Codex` · `Qualquer um` · `Manual (você)` · `Decisão` ·
tamanho `P` (até 1 h) / `M` (meio período) / `G` (1 dia+).

---

## 3. Plano futuro (ordem sugerida)

1. **Fechar a persistência** (lista "Persistência") — é o maior risco: sem ela ninguém guarda progresso.
2. **Pendências e bugs conhecidos** (lista "Pendências") — coisas pequenas que ficaram dos rounds anteriores.
3. **Qualidade / infraestrutura** — linter, testes de lógica, refatorar arquivos grandes; facilita trabalhar em dois.
4. **Polimento** — som, tutorial, ajustes de celular.
5. **Conteúdo novo** (lista "Futuro") — segunda área, chefe esquilo, novos ovos/pets, missões. **Cada um começa por
   um card de decisão de design** (escopo, números), que é seu/do ChatGPT, não da IA de código.

---

## 4. Cards

### Lista: Persistência

#### P1 — Teste de concorrência entre dois servidores reais
- **Ferramenta:** Claude (Studio) + Manual (você) · **Tamanho:** M · **Depende de:** —
- **Arquivos:** nenhum (só teste); talvez `docs/PERSISTENCE_TESTS.md`.
- **Descrição:** A trava de sessão só foi testada com dois "servidores" dentro do mesmo processo. Precisa de dois
  processos de verdade: um servidor real (entrar pela app do Roblox) + um Play no Studio, ou dois computadores.
  Procedimento completo na seção 1 de `docs/PERSISTENCE_TESTS.md` (chave sintética `test_concurrency_-424242`).
- **Pronto quando:** B espera ~30 s e assume; o save velho de A é recusado (`lost = true`); o registro final tem os
  dados de B; resultado anotado no `PERSISTENCE_TESTS.md`.
- **Prompt (Claude):**
  > Leia `CLAUDE.md` e `docs/PERSISTENCE_TESTS.md`. Vamos executar a seção 1 (concorrência entre dois servidores) na
  > experiência de teste 111667852947708. Eu vou abrir o segundo servidor quando você pedir. Use só a chave sintética
  > do documento, não mexa em produção, registre os resultados reais no documento e faça commit local.

#### P2 — BindToClose num servidor publicado
- **Ferramenta:** Manual (você) + Claude (Studio) para ler o resultado · **Tamanho:** P · **Depende de:** —
- **Descrição:** Seção 2 de `docs/PERSISTENCE_TESTS.md`: entrar pela app, jogar 1 min, desligar os servidores no
  Creator Hub com você dentro, depois ler o registro e conferir `lastSave.reason` e as moedas.
- **Pronto quando:** registro com as moedas mais novas, sem `lock`, `lastSave.reason` = `shutdown` ou `leave`.
- **Prompt (Claude):**
  > Leia `docs/PERSISTENCE_TESTS.md` seção 2. Eu acabei de desligar o servidor da experiência de teste com meu
  > jogador dentro. Leia o registro `test_player_<meu UserId>` no Studio (modo de edição, só leitura) e diga se o
  > encerramento salvou corretamente. Atualize o documento com o resultado real.

#### P3 — Repetir primeiro acesso e reconexão com a versão `2570f2f`
- **Ferramenta:** Claude (Studio) · **Tamanho:** P · **Depende de:** —
- **Descrição:** Os cenários A–D do relatório de DataStore rodaram no commit anterior. Repetir A (primeiro acesso,
  numa chave limpa) e B/C (perfil completo, sair, entrar 2x) com o código atual.
- **Pronto quando:** todos os campos (moedas, Força, diamonds, upgrades, rebirths, pets, equipados, coleção,
  marcos, HammerTier) voltam iguais; marco não é pago de novo.
- **Prompt (Claude):**
  > Leia `CLAUDE.md` (seção Persistência). Na experiência de teste 111667852947708, repita os cenários de primeiro
  > acesso, persistência e reconexão com o código atual. Monte um perfil com valores identificáveis em todos os
  > campos permanentes, saia e entre 2 vezes, compare campo a campo. Escritas só pelo servidor no Play. Relate só
  > resultados reais.

#### P4 — Orçamento de requisições do DataStore
- **Ferramenta:** Codex (código) → Claude (teste) · **Tamanho:** P · **Depende de:** —
- **Arquivos:** `src/server/Persistence.luau`, `src/server/PlayerData.luau`.
- **Descrição:** Antes do autosave, checar `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)`
  e adiar o autosave de quem não couber no orçamento (sem pular o save de saída). Evita estourar o limite com muitos jogadores.
- **Pronto quando:** autosave respeita o orçamento; save de saída e de encerramento continuam sempre tentando.
- **Prompt (Codex):**
  > Leia `CLAUDE.md` e `src/server/Persistence.luau`. Adicione checagem de orçamento de requisições do DataStore no
  > autosave de `PlayerData.luau` (usar `GetRequestBudgetForRequestType`). Se não houver orçamento, adie aquele
  > jogador para o próximo ciclo e registre um aviso. Não mude save de saída nem BindToClose. Mudança mínima, sem
  > alterar o formato do registro.

#### P5 — Ligar a persistência em produção
- **Ferramenta:** Decisão + Claude (Studio) · **Tamanho:** M · **Depende de:** P1, P2, P3 (e uma experiência principal publicada)
- **Arquivos:** `src/server/Persistence.luau`, `CLAUDE.md`.
- **Descrição:** Preencher o PlaceId da experiência principal em `production`, `enabled = true`, e validar lá
  (primeiro acesso + reconexão) antes de abrir para jogadores.
- **Pronto quando:** produção grava e lê no DataStore `PlayerData_v1`; teste continua isolado.
- **Prompt (Claude):**
  > Leia `CLAUDE.md` (Persistência) e `docs/PERSISTENCE_TESTS.md`. O PlaceId da experiência principal é <ID>.
  > Habilite o ambiente `production` só para esse PlaceId e valide primeiro acesso e reconexão nela. Não altere o
  > ambiente de teste. Relate PlaceId, store e chave usados.

#### P6 — Limpar dados de teste do DataStore
- **Ferramenta:** Claude (Studio) · **Tamanho:** P · **Depende de:** P1–P3
- **Descrição:** Remover as chaves de teste (`test_player_*`, `test_concurrency_*`) do store de teste quando não
  forem mais úteis (RemoveAsync no servidor durante o Play — o modo de edição não grava).
- **Prompt (Claude):**
  > Liste e remova as chaves de teste do DataStore `Nutcracker_TEST_PlayerData_v1` na experiência de teste. Mostre a
  > lista antes de remover e só remova chaves com prefixo `test_`.

---

### Lista: Pendências e bugs conhecidos

#### B1 — Pets em multiplayer
- **Ferramenta:** Claude (Studio, 2 jogadores) · **Tamanho:** P
- **Descrição:** Pets de outro jogador (seguir, leque na noz, investida) nunca foram testados com 2 jogadores reais.
- **Prompt (Claude):**
  > Leia `CLAUDE.md` (Pets seguidores). Eu vou abrir Test → Clients and Servers com 2 jogadores. Equipe pets
  > diferentes em cada um, ataquem nozes e confirme em cada cliente que os pets do outro aparecem, seguem e atacam.
  > Corrija só o que falhar. Relate o que foi visto em captura.

#### B2 — Animação da marreta pulando golpes com Attack Speed alto
- **Ferramenta:** Codex · **Tamanho:** P · **Arquivos:** `src/client/PlayerHammers.luau`
- **Descrição:** O golpe dura ~0,19 s; com intervalo de 0,2 s, golpes podem ser "engolidos" visualmente. Encurtar a
  animação proporcionalmente ao intervalo do jogador (ou permitir reiniciar o golpe). Só visual, não mexe em dano.
- **Prompt (Codex):**
  > Em `src/client/PlayerHammers.luau`, a animação de golpe (0,07 s + 0,12 s) pode ser pulada quando o intervalo de
  > ataque fica perto de 0,2 s. Faça a duração da animação acompanhar o intervalo real do jogador
  > (`Progression.tickInterval` com os upgrades lidos do atributo `Upgrades`) sem nunca empilhar animações. Só visual.

#### B3 — Texto pequeno no Pet Index em celular em pé
- **Ferramenta:** Claude (Studio) · **Tamanho:** P · **Arquivos:** `src/client/IndexUi.luau`
- **Descrição:** Na prévia 330×586 o texto dos cards do Index fica ~9 px. Ajustar layout (1 coluna ou fonte maior) no modo em pé.
- **Prompt (Claude):**
  > Use a prévia `PreviewSize` (330×586) e deixe os cards do Pet Index legíveis no celular em pé (texto ≥ 12 px na
  > tela), sem piorar desktop. Capture antes e depois.

#### B4 — Marcos pagos ao carregar save antigo não mostram banner
- **Ferramenta:** Codex · **Tamanho:** P · **Arquivos:** `src/server/PlayerData.luau`, `src/client/IndexUi.luau`
- **Descrição:** `checkMilestones` roda no `install()` (save migrado) e paga, mas não avisa o cliente. Enviar o
  `Notify("Collection", ...)` também nesse caso (depois que a HUD existir).
- **Prompt (Codex):**
  > Em `PlayerData.luau`, os marcos de coleção pagos dentro de `install()` não geram o aviso `Notify("Collection", ...)`.
  > Faça esses pagamentos também notificarem o cliente, com atraso suficiente para a HUD já existir. Não pague duas vezes.

#### B5 — Atualizar a spec de referências
- **Ferramenta:** Codex · **Tamanho:** P · **Arquivos:** `docs/NUTCRACKER_REFERENCE_SPEC.md`
- **Descrição:** A spec ainda lista pets, rebirth, coleção e marreta como "futuro". Marcar o que já existe e apontar
  para o `CLAUDE.md`.
- **Prompt (Codex):**
  > Atualize `docs/NUTCRACKER_REFERENCE_SPEC.md` para refletir o que já foi implementado (veja `CLAUDE.md` e o
  > `git log`). Não invente sistemas; mantenha em português.

#### B6 — Aviso de asset `203785492` / `81504106` no Output
- **Ferramenta:** Claude (Studio) · **Tamanho:** P
- **Descrição:** Todo Play mostra "ContentId rbxassetid://203785492 failed" (e às vezes 81504106). Esses IDs não estão
  em `src/` — devem vir do place (Sky, Lighting, personagem padrão). Descobrir de onde vêm e remover/trocar.
- **Prompt (Claude):**
  > Procure no place aberto (Lighting, Sky, StarterPlayer, workspace) onde estão os ContentIds 203785492 e 81504106
  > que falham no Output. Explique a origem e corrija só se for do projeto.

#### B7 — Validar visualmente efeitos de impacto dos tiers 1–4 e banners 3–5
- **Ferramenta:** Claude (Studio) · **Tamanho:** P
- **Descrição:** Os impactos dos tiers 1–4 e os banners de desbloqueio dos tiers 3–5 não apareceram em captura.
- **Prompt (Claude):**
  > Para cada tier de marreta (use DevCoins/rebirth para subir), capture o impacto num golpe e o banner de desbloqueio.
  > Se a captura for rápida demais, deixe os efeitos mais lentos só durante o teste e volte ao normal depois.

#### B8 — Toque real no celular
- **Ferramenta:** Manual (você) · **Tamanho:** P
- **Descrição:** Tudo de celular foi validado só por prévia de resolução. Abrir a experiência de teste num celular e
  testar: tocar nozes, menus, loja, ovos, Index, rebirth. Anotar problemas como novos cards.

---

### Lista: Qualidade / infraestrutura

#### Q1 — Linter e formatador (Selene + StyLua)
- **Ferramenta:** Codex · **Tamanho:** P
- **Descrição:** Hoje erros de sintaxe só aparecem no Studio. Adicionar `selene.toml` (std roblox) e `stylua.toml`,
  com instruções no `CLAUDE.md`. Não reformatar o projeto inteiro no mesmo card (gera conflito); só configurar.
- **Prompt (Codex):**
  > Adicione configuração de Selene (std roblox) e StyLua ao projeto, sem reformatar os arquivos existentes. Documente
  > os comandos no `CLAUDE.md`. Liste os avisos atuais do Selene sem corrigir.

#### Q2 — Testes de lógica pura rodáveis no Studio
- **Ferramenta:** Codex (escrever) → Claude (rodar) · **Tamanho:** M · **Arquivos:** novo `src/server/Tests/`
- **Descrição:** Transformar os testes que fizemos à mão (sorte dos ovos somar 100, sanitize/migração, custos
  crescentes, tierFor das marretas, trava de sessão no armazenamento em memória) em módulos de teste que rodam no
  Studio com um atributo `DevRunTests` e imprimem passou/falhou.
- **Prompt (Codex):**
  > Crie `src/server/Tests/` com testes de lógica pura (sem DataStore real): `PetConfig.eggChances`,
  > `PlayerData.sanitize` (v1→v4, hostil), `Progression` (custos, limites), `Hammers.tierFor`,
  > `Persistence` com `memoryStore` (trava, takeover, sessão perdida). Rode quando `workspace:SetAttribute("DevRunTests", true)`
  > for setado no servidor, só no Studio. Sem dependências externas.

#### Q3 — Dividir `Hud.luau`
- **Ferramenta:** Codex → Claude (validação visual) · **Tamanho:** M · **Arquivos:** `src/client/Hud.luau` (+ novos)
- **Descrição:** `Hud.luau` tem ~500 linhas (stats, alvo, menu, loja, popup, layout). Separar a loja de Força e o
  layout responsivo em módulos próprios, sem mudar comportamento. Reduz conflito entre os dois.
- **Prompt (Codex):**
  > Refatore `src/client/Hud.luau` separando a loja de Força (`StrengthShopUi.luau`) e o layout responsivo, sem mudar
  > comportamento nem a API pública (`Hud.modal`, `toggle`, `oops`, `toast`, `addMenuButton`, `root`, `reward`).
  > Atualize o `CLAUDE.md`.
- **Validação (Claude):** abrir todos os painéis em desktop e nas prévias de celular, comparar com antes.

---

### Lista: Polimento

#### U1 — Sons próprios
- **Ferramenta:** Decisão (de onde vêm os sons) + Claude · **Tamanho:** M
- **Descrição:** Todos os sons são placeholders do Roblox (`Effects.luau`). Precisa de assets (ForgeGUI gera SFX,
  mas os créditos acabaram, ou biblioteca do Roblox). Trocar golpe, quebra, compra, UI, ovo.
- **Prompt (Claude):**
  > Os sons do jogo são placeholders em `src/client/Effects.luau`. Use os IDs de áudio que eu passar: <lista>.
  > Centralize em `Assets.luau` e teste no Studio.

#### U2 — Primeiros passos do jogador (tutorial leve)
- **Ferramenta:** Decisão + Claude (Studio) · **Tamanho:** M
- **Descrição:** Uma sequência de dicas para quem entra pela primeira vez (quebrar noz → comprar Força → abrir ovo →
  equipar pet), usando os toasts/hint existentes. Precisa de definição do fluxo antes.
- **Prompt (Claude):**
  > Implemente dicas de primeiros passos para jogador novo: <fluxo definido>. Use `Hud.toast` e o cartão de dica
  > existente; salve o progresso das dicas em `PlayerData` só se a persistência estiver ativa.

#### U3 — Painel de configurações (som on/off)
- **Ferramenta:** Qualquer um · **Tamanho:** P · **Arquivos:** novo módulo cliente + `init.client.luau`
- **Prompt:**
  > Adicione um botão SETTINGS no menu (`Hud.addMenuButton`) com um painel `Ui.panel` contendo "Sound effects: On/Off",
  > guardado só no cliente nesta sessão. Siga os padrões de `Ui.luau`.

---

### Lista: Futuro (conteúdo — cada um começa por decisão)

#### F1 — Decisão: segunda área
- **Ferramenta:** Decisão (você/ChatGPT) · **Tamanho:** P
- **Descrição:** Tema, nozes novas (vida, recompensa, resistência), preço do portão "Next Area", posição na
  progressão em relação ao rebirth. Sai daqui a spec para F2.

#### F2 — Implementar a segunda área
- **Ferramenta:** Claude (Studio) · **Tamanho:** G · **Depende de:** F1
- **Prompt (Claude):**
  > Leia `CLAUDE.md` e a spec da segunda área: <colar>. Implemente o portão pago, a nova área no `MapBuilder` e as
  > novas nozes via `Config.Nuts`, sem duplicar sistemas. Teste no Studio e faça commit local.

#### F3 — Decisão + implementação: chefe esquilo
- **Ferramenta:** Decisão → Claude (Studio) · **Tamanho:** G
- **Descrição:** Os esquilos de armadura das referências viram chefes (vida grande, recompensa em diamonds via
  `Progression.OneTimeRewards` ou nova tabela). Definir regras antes.

#### F4 — Novos ovos e pets da segunda área
- **Ferramenta:** Codex (dados + modelos) → Claude (visual) · **Tamanho:** M · **Depende de:** F1
- **Descrição:** Entradas novas em `PetConfig.Pets/Eggs` e roupas novas em `PetModel.OUTFITS`. O Pet Index e os
  marcos acompanham sozinhos (talvez novos marcos em `Collection.luau`).

#### F5 — Placar (leaderboard) global
- **Ferramenta:** Claude (Studio) · **Tamanho:** M · **Depende de:** P5
- **Descrição:** OrderedDataStore com rebirths ou Força, num painel no mapa. Só depois da persistência em produção.

#### F6 — Missões / recompensa diária
- **Ferramenta:** Decisão → Codex + Claude · **Tamanho:** G · **Depende de:** P5

#### F7 — Gamepasses / monetização
- **Ferramenta:** Decisão · **Tamanho:** — · **Depende de:** P5
- **Descrição:** Fora do escopo até a economia e a persistência estarem estáveis.
