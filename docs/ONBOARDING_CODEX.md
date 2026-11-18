# Onboarding do Codex — Nutcracker Simulator

> **Como usar:** abra o Codex na pasta do projeto e mande:
> `Leia docs/ONBOARDING_CODEX.md e execute o onboarding do começo ao fim.`
>
> Leva uns 15 minutos. No fim, o Codex entrega um relatório dizendo se o PC está pronto e mostrando
> que ele entendeu o projeto.

---

## Para o Codex: regras durante o onboarding

Este é um onboarding **só de leitura**. Enquanto estiver seguindo este arquivo:

- **Não altere, crie nem apague arquivos.** Não rode `git commit`, `git push`, `git checkout -b` nem nada que mude o repositório.
- **Não mude nada no Studio.** Não edite instâncias nem scripts, não salve o place e não publique.
- **Não grave no DataStore** e não use as ferramentas `Dev*` (`DevCoins`, `DevDiamonds`, `DevPet`, `DevTarget`, `DevReload`).
  A experiência de teste salva o progresso de verdade, e essas ferramentas sujariam o save.
- Se um passo falhar, **anote e siga para o próximo**. Não tente consertar o ambiente sozinho: o relatório final
  vai dizer o que o dono do PC precisa fazer.
- Responda sempre em **português**.

---

## Etapa 1 — Ler a documentação

Leia, nesta ordem:

1. `AGENTS.md`: regras para agentes.
2. `CLAUDE.md`: **a documentação principal** (arquitetura, regras, cada sistema do jogo). Vale para o Codex também.
3. `README.md`: visão geral e como rodar.
4. `docs/PERSISTENCE_TESTS.md`: como o save é testado.
5. `docs/NUTCRACKER_REFERENCE_SPEC.md`: referências de design (partes dele podem estar desatualizadas; o `CLAUDE.md` manda).

Guarde as regras do `CLAUDE.md`: elas valem para **toda** tarefa futura neste projeto.

---

## Etapa 2 — Conferir o ambiente

Rode e anote o resultado de cada comando:

| Verificação | Comando | Esperado |
|---|---|---|
| Git instalado | `git --version` | mostra uma versão |
| Nome e e-mail do Git | `git config user.name` e `git config user.email` | os dois preenchidos |
| Remoto certo | `git remote -v` | `origin` → `github.com/joaozitoito/nutcracker-simulator` |
| Branch e estado | `git status` | na `main`, sem alterações pendentes |
| Atualizado | `git fetch` e depois `git status` | "up to date" com `origin/main` |
| Rokit | `rokit --version` | mostra uma versão |
| Versão do Rojo fixada | conferir se existe `rokit.toml` | existe e tem `rojo-rbx/rojo@...` |
| Rojo | `rojo --version` | igual à versão do `rokit.toml` |
| Build | `rojo build -o build/NutcrackerSimulator.rbxlx` | termina sem erro (a pasta `build/` é ignorada pelo git) |

O `rojo build` é o único comando permitido que gera arquivo, porque ele escreve só em `build/`, que o git ignora.

---

## Etapa 3 — Entender o código

Leia os arquivos abaixo. Não precisa decorar: o objetivo é saber **onde fica cada coisa**.

**Configuração (os números do jogo)**
- `src/shared/Config.luau`: nozes, raridades, alcance, tick de dano.
- `src/shared/PetConfig.luau`: pets, ovos e chances.
- `src/shared/Progression.luau`: diamonds, upgrades, rebirth. É o único lugar que combina multiplicadores.
- `src/shared/Hammers.luau` e `src/shared/Collection.luau`: marretas e marcos do Pet Index.

**Servidor (quem manda no jogo)**
- `src/server/init.server.luau`: ordem em que os módulos sobem.
- `src/server/PlayerData.luau`: **único dono** do estado do jogador.
- `src/server/NutService.luau`: atribuição de alvo, `attackUnits`, dano por tick e recompensa.
- `src/server/Persistence.luau`: DataStore, ambientes (teste e produção) e trava de sessão.

**Cliente (o que o jogador vê)**
- `src/client/init.client.luau`: ordem em que as telas sobem.
- `src/client/Ui.luau`: kit de interface. Toda tela nova usa ele.
- `src/client/Hud.luau`: HUD, menu e painéis.
- `src/client/Pets.luau` e `src/client/PlayerHammers.luau`: pets e marretas (só visual).

Depois de ler, responda **com o nome do arquivo e da função** em cada caso:

1. Onde muda o dano que um pet causa?
2. Que módulo pode alterar as moedas de um jogador? Por que nenhum outro pode?
3. O que acontece com o alvo do jogador quando a noz quebra?
4. Em que place o save funciona hoje, e o que impede ele de gravar em outro lugar?
5. Para criar uma tela nova, quais duas funções da HUD ela precisa usar?
6. Quais são os 4 "arquivos quentes" e por que dois cards que mexem neles não podem rodar ao mesmo tempo?

---

## Etapa 4 — Conferir a conexão com o Roblox Studio (MCP)

O dono do PC já deve ter aberto a **experiência de teste** no Studio, rodado `rojo serve` e conectado o plugin do Rojo.
Use só as ferramentas do **MCP do Roblox Studio**:

1. **Studio encontrado:** liste os Studios abertos. Se houver mais de um, use o que tem a experiência de teste.
2. **Place certo:** leia `game.PlaceId` (só leitura). Tem que ser `111667852947708`. Se for outro, **pare a etapa 4**
   e anote: o save só funciona nesse place.
3. **Rojo sincronizado:** confira se existem `ReplicatedStorage.Shared`, `ServerScriptService.Server` e
   `StarterPlayer.StarterPlayerScripts.Client` com os mesmos módulos da pasta `src/`.
4. **Play:** inicie o Play e espere uns 5 segundos.
5. **Console:** leia o Output e anote os erros. O erro de `rbxassetid://203785492` (às vezes `81504106`) já é conhecido
   (card 14) e pode ser ignorado. Anote qualquer outro.
6. **Jogo rodando:** só lendo, confira se `workspace.Map` e `workspace.Nuts` existem, quantas nozes há em
   `workspace.Nuts` e quais atributos o jogador tem (`Coins`, `Strength`, `Inventory`, `HammerTier`...).
7. **Captura:** tire uma captura da tela do Play.
8. **Parar:** pare o Play. Não salve o place.

Se o MCP não aparecer, anote **"MCP do Studio não conectado"** e pule para a etapa 5. A solução está no
card 03 do Trello (checklist "5. Ligar o Codex ao Studio").

---

## Etapa 5 — Como a dupla trabalha (decore isto)

- As tarefas ficam no Trello: https://trello.com/b/T5e0VdI1. Cada card tem número (01, 02...), um **prompt
  pronto** e a lista **"⚠️ Pode dar conflito com"**.
- **Um card = uma branch:** `git checkout main` → `git pull` → `git checkout -b card/<número>`.
- **Nada direto na `main`.** O trabalho termina num **pull request**, que o outro revisa antes do merge.
- Antes de começar um card, confira se o outro está num card que conflita (a mesma etiqueta "Mexe").
- **Arquivos quentes** (`Hud.luau`, `PlayerData.luau`, `init.client.luau`, `init.server.luau`): só uma pessoa por vez.
- **Teste no Studio** antes de dizer que terminou. Sempre compare com o "Como saber que terminou" do card.
- Mudou a arquitetura? Atualize o `CLAUDE.md` no mesmo pull request.
- **Nunca:** publicar o jogo, ligar o ambiente `production` em `Persistence.luau` (só no card 28) ou mudar o
  ciclo de ataque (regra do dono do projeto, descrita no `CLAUDE.md`).

---

## Etapa 6 — Relatório final

Entregue exatamente neste formato:

```
# Relatório de onboarding

## Ambiente
| Item | Resultado | OK? |
|---|---|---|
| Git | ... | ✅/❌ |
| Nome/e-mail do Git | ... | ✅/❌ |
| Remoto e branch | ... | ✅/❌ |
| Rokit | ... | ✅/❌ |
| Rojo (versão igual ao rokit.toml) | ... | ✅/❌ |
| rojo build | ... | ✅/❌ |
| MCP do Studio | ... | ✅/❌ |
| Place = 111667852947708 | ... | ✅/❌ |
| Rojo sincronizado no Studio | ... | ✅/❌ |
| Play sem erros novos | ... | ✅/❌ |

## O projeto em 5 linhas
(o que é o jogo e como servidor e cliente se dividem)

## Respostas da etapa 3
1. ...
6. ...

## O que o dono do PC precisa fazer
(um item por ❌, com o passo exato. Se não houver nenhum: "Nada, pode começar.")

## Primeira tarefa sugerida
Card 06 · Treino 1: atualizar o documento de referências. É uma tarefa fácil para treinar o fluxo
branch → pull request → revisão.
```

Depois do relatório, **não comece nenhuma tarefa**. Espere o dono do PC escolher o card.
