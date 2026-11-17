# Nutcracker Simulator

Simulator para Roblox, escrito em **Luau** e sincronizado com **Rojo**. O jogador quebra nozes para ganhar moedas,
compra Força, abre ovos, equipa pets (esquilos) que atacam junto, evolui a marreta e faz rebirth.

Interface do jogo em inglês; documentação técnica em português.

## O que já existe

| Sistema | Resumo |
|---|---|
| Área Acorn Meadow | Mapa gerado por código, 3 nozes (Acorn, Walnut, Golden Nut) com vida e resistência |
| Ciclo de ataque | Clicar numa noz só atribui o alvo; o dano vem do tick do servidor |
| Economia | Moedas, loja de Força, Diamonds, 6 upgrades permanentes, Rebirth |
| Ovos e pets | 3 ovos com chances, 10 pets, inventário (50), até 3 equipados que seguem e atacam |
| Coleção | Pet Index com silhuetas, descobertas e 3 marcos com recompensa |
| Marreta evolutiva | 5 tiers (Starter → Cosmic), visível para todos os jogadores |
| Interface | HUD responsiva (desktop, celular deitado e em pé), kit `Ui.luau`, arte do ForgeGUI |
| Persistência | DataStore com trava de sessão e migração de saves; **ligada só na experiência de teste** |

## Como rodar

Pré-requisitos: [Rojo](https://rojo.space) e Roblox Studio com o plugin do Rojo.

```bash
rojo build -o build/NutcrackerSimulator.rbxlx   # gera o place completo; abrir no Studio e apertar Play
rojo serve                                      # sync ao vivo; conectar pelo plugin do Rojo no Studio
```

Não há linter nem testes automatizados ainda. A validação é `rojo build` + Play no Studio
(`rojo build` não acusa erro de sintaxe Luau; ele aparece no Output do Studio).

### Ferramentas de teste (só no Studio, barra de comando do servidor)

```lua
workspace:SetAttribute("DevCoins", 1000)     -- moedas para todos
workspace:SetAttribute("DevDiamonds", 100)   -- diamonds para todos
workspace:SetAttribute("DevPet", "<id>")     -- dá um pet pelo mesmo caminho dos ovos
workspace:SetAttribute("DevTarget", "<id>")  -- atribui uma noz
workspace:SetAttribute("DevReload", true)    -- salva e recarrega pelo armazenamento em memória
```

## Estrutura

```
src/shared  -> ReplicatedStorage.Shared              configuração, fórmulas, modelos procedurais, remotes
src/server  -> ServerScriptService.Server            estado do jogador, nozes, lojas, pets, persistência
src/client  -> StarterPlayer.StarterPlayerScripts    HUD, telas, efeitos, pets e marretas (visual)
docs/                                                spec de referências, testes de persistência, roadmap
```

O servidor é a única autoridade: o cliente só lê estado replicado e pede ações.
Arquitetura completa e regras do projeto: [`CLAUDE.md`](CLAUDE.md).

## Documentação

- [`CLAUDE.md`](CLAUDE.md): arquitetura, regras e detalhes de cada sistema (lido pelo Claude Code e pelo Codex).
- [`docs/ROADMAP_TRELLO.md`](docs/ROADMAP_TRELLO.md): histórico, plano e todos os cards de trabalho, com prompts prontos.
- [`docs/PERSISTENCE_TESTS.md`](docs/PERSISTENCE_TESTS.md): procedimentos de teste do DataStore.
- [`docs/NUTCRACKER_REFERENCE_SPEC.md`](docs/NUTCRACKER_REFERENCE_SPEC.md): referências de design.

## Como trabalhar no projeto

O backlog fica no quadro **Nutcracker Simulator** do Trello (mesmos cards de `docs/ROADMAP_TRELLO.md`).

1. Pegue um card e mova para **Fazendo**.
2. Crie uma branch `card/<número>-nome` a partir de `main`. Nada direto em `main`.
3. Não peguem ao mesmo tempo dois cards que mexem nos mesmos arquivos quentes
   (`Hud.luau`, `PlayerData.luau`, `init.client.luau`, `init.server.luau`).
4. Abra um pull request; depois do merge, mova o card para **Feito**.

## Segurança

- Não publicar o jogo pelo Studio sem combinar antes.
- A persistência em produção está **desligada** (`production.enabled = false` em `Persistence.luau`) e só
  deve ser ligada pelo card P5, depois dos testes P1–P3.
