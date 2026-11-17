# Nutcracker Simulator

Simulator Roblox (Luau + Rojo). Estado atual: uma área jogável (Acorn Meadow) com o ciclo completo
quebrar nozes → moedas → Força / ovos → pets → pets equipados seguem o jogador e atacam junto.
Referências de design e dúvidas em aberto: `docs/NUTCRACKER_REFERENCE_SPEC.md`.
Interface do jogo em inglês; documentação técnica em português.

## Comandos

```bash
rojo build -o build/NutcrackerSimulator.rbxlx   # gera o place completo; abrir no Studio e apertar Play
rojo serve                                      # sync ao vivo; conectar pelo plugin do Rojo no Studio
```

Não há linter, formatter nem test runner instalados. Validação = `rojo build` + Play no Studio.
`rojo build` **não** checa sintaxe Luau: um erro de sintaxe só aparece no Output do Studio.

Ferramentas de desenvolvimento (só no Studio):
- Moedas: na barra de comando do **servidor**, `workspace:SetAttribute("DevCoins", 1000)` dá moedas a todos.
- Prévia de resolução: atributo `PreviewSize` (Vector2) no ScreenGui `NutHud` renderiza a HUD naquele tamanho.
- Vitrine das peças de imagem: `workspace:SetAttribute("ForgeDemo", true)` mostra o ScreenGui `ForgeDemo` (separado da HUD).

## Estrutura

```
src/shared  -> ReplicatedStorage.Shared
  Config.luau     balanceamento das nozes, raridades (Config.Rarities), alcances, tick, curvas de força/custo
  PetConfig.luau  pets (raridade, dano, aparência), ovos (preço, moeda, chances), limites, rollPet, readInventory
  PetModel.luau   modelos procedurais dos esquilos e dos ovos (usado no mundo e nos ícones 3D da interface)
  Assets.luau     IDs e medidas (recorte, 9-slice) das imagens externas enviadas ao Roblox
  Format.luau     1234 -> "1.2k"
  Remotes.luau    declara os remotes (pasta "Net"): BuyStrength, OpenEgg, EquipPet (RemoteFunction), Notify (RemoteEvent)
src/server  -> ServerScriptService.Server (init.server.luau sobe os módulos em ordem)
  SelfCheck       asserts sobre Config e PetConfig no boot (pesos dos ovos somam 100, raridades válidas...)
  MapBuilder      constrói workspace.Map com Parts (inclui a banca de ovos) e devolve os pontos de spawn das nozes
  NutModel        constrói o Model de uma noz a partir da tabela `look` do Config
  PlayerData      ÚNICO dono do estado do jogador: moedas, nível de força, pets, equipados
  NutService      spawn, atribuição (ClickDetector), dano por tick com attackUnits, quebra, recompensa, respawn
  ShopService     handler de BuyStrength
  PetService      handlers de OpenEgg e EquipPet
src/client  -> StarterPlayerScripts.Client
  Ui              kit de interface: card, button, bar, tag, panel, viewport, iconTile, coin, nutIcon, pop, bump,
                  imageButton e imageCoin (peças com arte de Assets.luau)
  Effects         feedback no mundo: pop das nozes, números de dano, marreta, explosão de quebra, sons, onHit
  Hud             HUD: stats, cartão do alvo, menu de botões, loja, popup, toasts; API modal/toggle/oops/addMenuButton
  Pets            pets seguidores (visual): formação, movimento, investida a cada golpe confirmado
  PetsUi          botões PETS/EGGS, inventário, catálogo de ovos, sequência de abertura
  ForgeDemo       vitrine de desenvolvimento das peças de imagem (só no Studio, fora da HUD)
```

## Regras da arquitetura

- O servidor é a única autoridade. O cliente lê estado replicado e pede ações; nunca envia valores, preços ou resultados.
  - Estado do jogador: atributos no Player (`Coins`, `Strength`, `StrengthLevel`, `TargetId`, `Inventory`).
  - `Inventory` é um JSON: `{ pets = [{ uid, type }], equipped = [uid] }`. Ler com `PetConfig.readInventory(player)`.
  - Estado da noz: atributos em cada Model de `workspace.Nuts` (`NutId`, `Health`, `MaxHealth`).
- Toda mudança de estado do jogador passa por `PlayerData` (`addCoins`, `spend`, `buyLevel`, `addPet`, `setEquipped`).
  Nenhum outro módulo guarda moedas, pets ou equipados.
- Handlers de remote não têm `yield` entre validar e alterar: pedidos simultâneos são tratados um após o outro.
- Ciclo de ataque (decidido pelo dono do projeto, não mudar sem aprovação):
  - Clicar numa noz só **atribui** o alvo. Clicar de novo na mesma noz não faz nada.
  - O dano vem só do tick global do servidor (`Config.TickInterval`).
  - Sair de `Config.LeashRange` cancela. Clicar em outra noz válida troca o alvo.
  - Quando a noz quebra, o jogador fica **sem alvo**. Não há reatribuição automática.
- Todo ataque passa por `check()` no NutService (noz viva, jogador vivo, distância, força >= resistência).
  A resistência da noz é comparada só com a **Força do jogador**: pets aumentam o dano, não liberam nozes mais duras.
- Dados novos entram por configuração: noz em `Config.Nuts`, pet em `PetConfig.Pets`, ovo em `PetConfig.Eggs`
  (mais a ordem em `NutOrder` / `PetOrder` / `EggOrder`). Pet com visual novo = função nova em `OUTFITS` no `PetModel`.
- Mapa, modelos e UI são gerados por código. As únicas exceções são imagens de arte de interface (ForgeGUI):
  todo ID fica em `Assets.luau`, com o recorte da área pintada e o 9-slice medidos no arquivo original.
  Texto e valores nunca ficam pintados na imagem: a arte é fundo/ícone, o texto é TextLabel.
- ScreenGui novo precisa de `ZIndexBehavior = Sibling` (o padrão de `Instance.new` é Global e esconde o conteúdo dos cards).
- Toda tela nova usa `Ui.luau` e entra na HUD por `Hud.addMenuButton` + `Hud.modal(painel)`.

## Combate com pets: `attackUnits(player)`

`attackUnits(player)` em `NutService` devolve as unidades de ataque do jogador:

```
{ source = "player",      damage = Força do jogador }      -- sempre a primeira
{ source = "<tipo do pet>", damage = PetConfig.Pets[tipo].damage }   -- uma por pet equipado
```

- A cada tick o servidor soma o dano de todas as unidades e aplica **um** golpe na noz atribuída ao jogador.
- Unidades não têm temporizador nem alvo próprios: só existem dentro do tick. Por isso param no mesmo instante
  em que a atribuição acaba (noz quebrada, fora de alcance, troca de alvo).
- A recompensa da noz não depende do número de unidades: é paga uma vez, proporcional ao dano de cada jogador.
- Para rebalancear pets (multiplicadores, teto, bônus), mudar o dano calculado em `attackUnits`; nada mais.

## Pets seguidores

- Só visual e só no cliente (`Pets.luau`): cada cliente constrói os modelos dos pets equipados de **todos** os
  jogadores a partir do atributo `Inventory`, e os move num único `Heartbeat` (sem física, sem remotes).
- Sem alvo: formação atrás do dono. Com alvo: leque em volta da noz, do lado do dono.
- Investida: `Effects.onHit` dispara quando a noz perde `Health` (golpe confirmado pelo servidor).

## Persistência (ainda não implementada)

`PlayerData.snapshot(player)` devolve exatamente o que um DataStore deve salvar:
`{ coins, level, nextPetUid, pets = { { uid, type } }, equipped = { uid } }`.
O carregamento entra pelo segundo argumento de `add(player, saved)` em `PlayerData`. Nada depende da HUD.

## Fora do escopo atual

Rebirth, novas áreas, chefes, eventos, gamepasses, poções, encantamentos, fusão de pets, DataStore.

## Segurança do projeto

Não publicar o jogo nem fazer push para remotos. Apenas commits locais.

## Progressão: diamantes, upgrades permanentes e rebirth (resumo)

- Config e fórmulas: `src/shared/Progression.luau` (único lugar onde multiplicadores são combinados; ver cabeçalho).
- Estado: `PlayerData` ganhou `diamonds`, `rebirths`, `upgrades`, `claimed` (+ `addDiamonds`, `spendDiamonds`,
  `grantOnce`, `buyUpgrade`, `rebirth`, `sanitize`, `ledger`). Atributos novos no Player: `Diamonds`, `Rebirths`, `Upgrades` (JSON).
- Serviço: `ProgressionService` (remotes `BuyUpgrade(id)` e `Rebirth()`); telas em `ProgressionUi`.
- Rebirth zera moedas e nível de Força; mantém pets, diamantes, upgrades. A resistência das nozes continua comparada
  só com a Força base.
- Attack Speed: um loop único no `NutService` (passo 0,05 s) com intervalo por jogador, piso `MinTickInterval`.
- Egg Luck: `PetConfig.eggChances(eggId, luck)`; a soma é sempre 100 e nada fica negativo.
- Persistência: `Persistence.luau` está **desligada** (`Enabled = false`); só foi testada com o armazenamento em memória.
- Ferramentas só do Studio (atributos do Workspace, no servidor): `DevCoins`, `DevDiamonds`, `DevTarget` (id da noz),
  `DevReload` (salva e recarrega pelo armazenamento em memória).

## Coleção: Pet Index e recompensas (resumo)

- Config: `src/shared/Collection.luau` (marcos `{ species, coins, diamonds }`, `Collection.read(player)`).
  O catálogo é o próprio `PetConfig`; não há segunda lista de pets.
- Descoberta: acontece em `PlayerData.addPet` (único ponto por onde um pet entra no inventário). Não existe remote
  para o cliente declarar descoberta ou pedir recompensa.
- Marcos: pagos automaticamente por `checkMilestones`, uma vez só (chave em `claimed`, mesma trava das recompensas únicas).
  Também roda ao carregar um save, para quitar marcos de saves migrados.
- Estado: `discovered = { [petId] = true }` (versão 3 do save). Atributo `Collection` (JSON) no Player.
  Saves antigos ganham como descobertas as espécies que possuem.
- Tela: `IndexUi` (botão INDEX, painel com progresso, marcos e pets por raridade; não descobertos viram silhueta).
- Navegação: o menu fica acima dos painéis (`ZIndex 13`); tocar em outro botão troca de painel direto.
  `layout()` define `modalPosition` para o painel não ficar sob o menu no celular.
- Ferramenta só do Studio: `workspace:SetAttribute("DevPet", "<id do pet>")` dá o pet pelo mesmo caminho dos ovos.

## Evolução da marreta (resumo)

- Config: `src/shared/Hammers.luau` (5 tiers, requisitos, estilo de impacto); modelos em `src/shared/HammerModel.luau`.
- Requisitos: 1 desde o início; 2 Força base >= resistência da Walnut; 3 Força base >= resistência da Golden Nut;
  4 um rebirth; 5 três rebirths.
- Servidor: `PlayerData` guarda `hammer` (maior tier já alcançado, save versão 4) e o recalcula em `sync()`;
  só sobe, então rebirth não tira a marreta. Atributo `HammerTier` no Player. Nenhum remote novo.
- Cliente: `PlayerHammers.luau` desenha a marreta de **todos** os jogadores em cada cliente (como `Pets.luau`),
  a partir dos atributos replicados `HammerTier` e `TargetId`: nas costas sem alvo, ao lado da noz com alvo,
  golpe + impacto do tier a cada golpe confirmado (`Effects.onHit`). Um modelo por jogador em `workspace.Hammers`,
  criado no PlayerAdded e destruído no PlayerRemoving. O impacto em si é `Effects.impact(ponto, escala, tier)`.
- Som do golpe: o mesmo arquivo, com tom mais grave a cada tier (só nos golpes do próprio jogador).
- `HammerUi`: pílula "HAMMER: <nome>" sob os stats e banner de desbloqueio.
- Puramente visual: não muda dano, intervalo, recompensas nem rebirth.
