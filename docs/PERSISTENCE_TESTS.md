# Testes de persistência — procedimentos

Todos usam só a experiência privada de teste (PlaceId 111667852947708) e o DataStore `Nutcracker_TEST_PlayerData_v1`.
O console do Studio no **modo de edição** só lê o DataStore; gravações precisam rodar no **servidor durante o Play**.

## 1. Concorrência entre dois servidores independentes (ainda NÃO executado)

Precisa de dois processos de servidor de verdade. "Clients and Servers" do Studio abre um servidor só, e o Studio não
abre o mesmo place duas vezes no mesmo processo. Opções que dão dois servidores:

- **A)** Dois computadores (ou duas contas do Windows) com o Studio aberto na experiência de teste, cada um em Play.
- **B)** Um servidor real (entrar pela app do Roblox) + um Play no Studio.

Em cada servidor, cole na barra de comando do **servidor** (troque `SERVER` por "A" ou "B"):

```lua
local server = game.ServerScriptService.Server
local copy = server.Persistence:Clone(); copy.Parent = server
local P = require(copy); copy:Destroy()
_G.session, _G.record = P.open(P.store(), -424242, { prefix = "test_concurrency_" }) -- chave sintética
print("SERVER opened, tookOver =", _G.session.tookOver)
```

Passos e resultado esperado:

1. A executa o bloco acima: abre na hora (`tookOver = false`).
2. B executa o bloco: fica ~30 s esperando e então assume (`tookOver = true`). Se A salvar dentro desses 30 s com
   `_G.session:save({ coins = 1 }, false, "A")`, a gravação de A passa (A ainda é o dono).
3. Depois que B assumiu, B grava: `_G.session:save({ coins = 2 }, false, "B")` → `true`.
4. A tenta gravar de novo: `_G.session:save({ coins = 999 }, false, "A-stale")` → `false`, `_G.session.lost == true`
   e o aviso "another session took over this record" no Output de A.
5. Leia o registro (qualquer servidor):
   `game:GetService("DataStoreService"):GetDataStore("Nutcracker_TEST_PlayerData_v1"):GetAsync("test_concurrency_-424242")`
   → `coins = 2`, `lastSave.reason = "B"`.
6. B libera: `_G.session:save({ coins = 2 }, true, "B-final")` → o registro fica sem `lock`.

## 2. BindToClose em servidor real (ainda NÃO executado)

1. Entrar na experiência de teste pela app do Roblox e jogar pelo menos 1 minuto (ganhar moedas).
2. Com o jogador ainda dentro, no Creator Hub: a experiência → ⋯ → **Shut Down All Servers**.
3. No Studio (modo de edição), ler o registro do seu UserId:
   `GetAsync("test_player_<UserId>")` → as moedas mais recentes, sem `lock`, e `lastSave.reason` igual a
   `"shutdown"` (gravado pelo BindToClose) ou `"leave"` (gravado pelo PlayerRemoving que o desligamento dispara).
   Qualquer um dos dois prova que o encerramento salvou; o motivo mostra qual caminho chegou primeiro.

No Studio, parar o Play grava pelo caminho `"leave"` (visto em teste); o caminho `"shutdown"` com jogador presente
não roda no Studio.
