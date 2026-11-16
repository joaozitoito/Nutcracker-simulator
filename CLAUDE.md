# Nutcracker Simulator

Simulator Roblox (Luau + Rojo). Estado atual: uma área jogável (Acorn Meadow) — quebrar nozes, ganhar moedas, comprar Força.
Referências de design e dúvidas em aberto: `docs/NUTCRACKER_REFERENCE_SPEC.md`.
Interface do jogo em inglês; documentação técnica em português.

## Comandos

```bash
rojo build -o build/NutcrackerSimulator.rbxlx   # gera o place completo; abrir no Studio e apertar Play
rojo serve                                      # sync ao vivo; conectar pelo plugin do Rojo no Studio
```

Não há linter, formatter nem test runner instalados. Validação = `rojo build` + Play no Studio.

## Estrutura

```
src/shared  -> ReplicatedStorage.Shared
  Config.luau    todos os dados de balanceamento: nozes, raridades, alcances, tick, curvas de força/custo
  Format.luau    1234 -> "1.2k"
  Remotes.luau   declara os remotes (pasta "Net"): BuyStrength (RemoteFunction), Notify (RemoteEvent)
src/server  -> ServerScriptService.Server (init.server.luau sobe os módulos em ordem)
  SelfCheck      asserts sobre o Config no boot
  MapBuilder     constrói workspace.Map com Parts e devolve os pontos de spawn das nozes
  NutModel       constrói o Model de uma noz a partir da tabela `look` do Config
  PlayerData     moedas + nível de força por jogador (só na sessão), espelhados em atributos/leaderstats
  NutService     spawn, atribuição (ClickDetector), dano automático por tick, quebra, recompensa, respawn
  ShopService    handler de BuyStrength
src/client  -> StarterPlayerScripts.Client
  Ui             kit de interface: card, button, bar, tag, iconTile, coin, nutIcon, pop, bump
  Effects        feedback no mundo: pop das nozes, números de dano, marreta, explosão de quebra, sons
  Hud            HUD montada com o kit: stats, cartão do alvo, loja, popup, toasts, moedas voando
```

## Regras da arquitetura

- O servidor é a única autoridade. O cliente lê estado replicado e nunca envia valores, ids ou preços.
  - Estado do jogador: atributos no Player (`Coins`, `Strength`, `StrengthLevel`, `TargetId`).
  - Estado da noz: atributos em cada Model de `workspace.Nuts` (`NutId`, `Health`, `MaxHealth`).
- Ciclo de ataque (decidido pelo dono do projeto, não mudar sem aprovação):
  - Clicar numa noz só **atribui** o alvo. Clicar de novo na mesma noz não faz nada.
  - O dano vem só do tick global do servidor (`Config.TickInterval`): no máximo uma rodada de golpes por jogador por tick.
  - Sair de `Config.LeashRange` cancela. Clicar em outra noz válida troca o alvo.
  - Quando a noz quebra, o jogador fica **sem alvo** e precisa escolher outra. Não há reatribuição automática.
- Todo ataque passa por `check()` no NutService (noz viva, jogador vivo, distância, força >= resistência).
- Tipo novo de noz = entrada nova em `Config.Nuts` + nome em `Config.NutOrder`. Sem código novo.
- Mapa e UI são gerados por código; não há assets externos nem instâncias que existam só no place.
- Toda tela nova usa `Ui.luau`. Não criar frames/botões soltos fora do kit.
- HUD responsiva: `layout()` em `Hud.luau` tem três arranjos (desktop, celular deitado, celular em pé).
  Para testar sem emulador: atributo `PreviewSize` (Vector2) no ScreenGui `NutHud` renderiza a HUD naquele tamanho.

## Pontos de extensão para ovos e pets (ainda não implementados)

- **Unidades de ataque:** `attackUnits(player)` em `NutService` devolve a lista de danos que batem no alvo a cada tick.
  Hoje é `{ força do jogador }`; pets equipados entram como itens extras, sem mexer em atribuição, validação ou quebra.
- **Raridades:** `Config.Rarities` (nome + cor) já é usado pelas nozes e por `Ui.tag`; ovos e pets devem reutilizar.
- **Dados do jogador:** `PlayerData` é o único dono do estado; inventário/pets equipados entram na mesma tabela por jogador.
- **Interface:** catálogo de ovos e inventário devem ser montados com `Ui.card`, `Ui.button`, `Ui.tag`, `Ui.pop`.
- **Remotes:** declarar em `Remotes.luau`; o cliente pede a ação, o servidor decide tudo.

## Fora do escopo atual

Pets, ovos, rebirth, novas áreas, chefes esquilos, eventos, gamepasses, persistência em DataStore.

## Segurança do projeto

Não publicar o jogo nem fazer push para remotos. Apenas commits locais.
