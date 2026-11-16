# Nutcracker Simulator — Especificação de Referências (Round 01)

Legenda: **[OBS]** = observado diretamente nos materiais. **[INT]** = interpretação/decisão minha.

## 1. Referências analisadas

| Material | Como foi analisado |
|---|---|
| `2026 11 15 15 56 43.mp4` (133 s, 1280×720) | 24 frames amostrados a cada ~5,5 s + 2 frames em resolução cheia |
| `2026 11 15 15 58 57.mp4` (138 s) | 24 frames amostrados + 1 frame em resolução cheia |
| `2026 11 15 16 01 46.mp4` (147 s) | 24 frames amostrados |
| `2026 11 15 16 04 14.mp4` (124 s) | 24 frames amostrados |
| Imagem 1 — 4 esquilos (cavaleiro, "thug life", pato, mago) | vista inteira |
| Imagem 2 — grade com 15 nozes/bolotas | vista inteira |

Limitação: os vídeos foram vistos como **frames estáticos amostrados** (não havia ffmpeg; os frames foram extraídos por um
`<video>` + canvas local). **Não ouvi o áudio** e não vi o movimento contínuo: animações rápidas (menos de ~5 s) e o timing
exato de dano foram inferidos, não medidos. Das 16 folhas de contato geradas, 8 foram inspecionadas (2 por vídeo).

Todos os 4 vídeos são gameplay de **Pet Simulator 99** [OBS: HUD, "Rank 5 – Experienced", "Rebirth 2", janelas "Pets!",
"Teleport!", "Collection!"].

## 2. Características visuais identificadas

- [OBS] Cores muito saturadas, iluminação clara e sem sombras duras; chão em blocos de cor chapada (laranja, verde-limão,
  amarelo, azul-gelo, areia).
- [OBS] Cada área é um **retângulo plano de cor única** delimitado por uma **linha branca tracejada**, cercado por um
  caminho cinza-azulado claro.
- [OBS] Decoração low-poly e exagerada nas bordas: árvores de copa em blocos/esferas, abóboras, cogumelos gigantes,
  palmeiras, casas blocadas; o centro da área fica livre para os quebráveis.
- [OBS] Quebráveis são objetos grandes (aprox. a altura do personagem ou mais): pilhas de moedas, caixotes, presentes,
  cofres, blocos de gelo, baús.
- [OBS] Feedback de quebra: flash branco, anel/onda no chão, muitas moedas voando até o jogador, texto "BONUS!".
- [OBS] Nozes da imagem 2: silhueta redonda e gorda, chapéu quadriculado, cabinho, contorno suave, brilho especular;
  variações por acessório (coroa, laço, gorro, óculos) e por material (dourada com brilhos, galáxia roxa, lava com chifres,
  rachada com núcleo brilhante).
- [OBS] Esquilos da imagem 1: corpo atarracado, cabeça grande, dentões, cauda espiral enorme, low-poly facetado; a
  identidade vem do traje (armadura + escudo de bolota, corrente de ouro + óculos pixelados, fantasia de pato, mago).

## 3. Mecânicas identificadas

- [OBS] O jogador anda até os quebráveis; os pets vão até o alvo e o cercam em anel; aparece uma barra de vida com número
  sobre o quebrável sendo atacado.
- [OBS] Vários quebráveis são atacados ao mesmo tempo (pets distribuídos).
- [OBS] Ao quebrar: moedas caem no chão e são sugadas pelo jogador; contador flutuante ("22.2k", "982").
- [OBS] Texto "Walk away to stop!" durante uma ação automática (auto-hatch) — afastar-se cancela.
- [OBS] Portão "Next Area" com preço e botão "Buy" físico no mundo; barra "Next Area" no topo.
- [OBS] Popup "Oops! You need more Diamonds to buy this upgrade!" com botão "Ok!" quando falta saldo.
- [OBS] Loja de upgrade em grade ("Equip More Pets!": Owned / preço em botão).
- [INT] O alvo é atribuído por clique/toque no quebrável ("Assign") — não vi o clique em si nos frames; é o comportamento
  conhecido do jogo de referência e a decisão já estabelecida do projeto.
- [INT] Ritmo: quebrar leva poucos segundos na área inicial; melhorias são compradas a cada punhado de quebras.

### Interpretação de "Hybrid + Assign" adotada no Round 01 [INT]

- **Assign**: clicar/tocar numa noz atribui o ataque do jogador a ela. O servidor aplica dano automático a cada tick
  enquanto o jogador estiver dentro do alcance. Afastar-se cancela ("walk away to stop"). Ao quebrar, o servidor
  atribui automaticamente a noz viva mais próxima que o jogador consiga quebrar.
- **Hybrid**: além do dano automático, clicar/tocar de novo na noz já atribuída dá um golpe manual extra (com cooldown no
  servidor). Ou seja: automático + ativo.
- Como não há pets no Round 01, o "atacante" é o próprio jogador. Quando os pets entrarem, eles herdam a atribuição.

## 4. Estrutura do mapa

- [OBS] Sequência linear de áreas (janela Teleport: Spawn → Colorful Forest → Castle → Green Forest → Autumn → …), cada uma
  comprada no portão da anterior.
- [OBS] Área = campo retangular central com quebráveis espalhados em grade solta + anel de caminho + decoração na borda.
- [OBS] Máquinas/lojas ficam na borda do caminho, com placa flutuante.
- [INT] Round 01: **uma** área compacta ("Acorn Meadow") com três faixas de cor no mesmo campo (bolotas → nozes → noz
  dourada), praça de spawn ao sul, banca da loja ao lado da praça e portão trancado "Next Area" ao norte para sugerir o
  mundo maior.

## 5. Direção da interface

- [OBS] Fonte arredondada grossa, texto branco com contorno escuro; painéis brancos de cantos arredondados com borda
  escura grossa; botão verde chapado ("Buy", "Claim!", "Ok!"); X vermelho no canto superior direito.
- [OBS] Moedas à **esquerda, meia altura**: ícone + número grande, e abaixo valores secundários menores.
- [OBS] **Topo central**: cartão de objetivo/contexto com barra de progresso.
- [OBS] **Base central**: botão principal (inventário de pets), que expande numa fileira de ícones.
- [OBS] Coluna esquerda de ícones (presentes, boosts) e direita de missões + botão verde "Rewards".
- [INT] Round 01: moedas e força à esquerda; cartão do alvo (nome, barra de vida, recompensa) no topo central; botão da
  loja na base central; toasts acima do botão. `UIScale` proporcional à altura da tela para celular.

## 6. Reproduzir conceitualmente

- Campo plano de cor única com borda tracejada e decoração só na borda.
- Quebráveis grandes, legíveis, com barra de vida ao serem atacados.
- Atribuição de alvo + cancelamento ao se afastar.
- Explosão de recompensa (partículas, número flutuante, contador que "pulsa").
- Portão físico de próxima área com preço.
- Popup "Oops!" para saldo insuficiente; botões verdes grossos.

## 7. Adaptar para identidade original

- Quebráveis são **nozes/bolotas/castanhas** (imagem 2), não baús/caixotes/moedas.
- Tema de bosque de outono: carvalhos, tocos, cogumelos, folhas laranja/vermelhas — nada de assets, nomes, pets, ícones ou
  layout exato de HUD do jogo de referência.
- Moeda própria (moeda dourada de bolota) e atributo **Força** em vez de diamantes/pets como eixo inicial.
- Esquilos como personagens/chefes com trajes (imagem 1) — só documentado, ver §8.
- Todos os modelos do Round 01 são construídos por código com Parts; nenhum asset externo.

## 8. Sistemas para etapas futuras (não implementados)

Pets, ovos e abertura, coleção, bônus por pets, rebirth, novas áreas (o portão existe só como cenário), chefes esquilos,
eventos, gamepasses, monetização, missões/ranks, boosts, teleporte, daycare, persistência em DataStore.

Direção dos esquilos [OBS imagem 1 + INT]: mesmo corpo-base, variação por traje. Candidatos a chefe: **Cavaleiro**
(armadura cinza, elmo com pluma vermelha, escudo com bolota dourada), **Mago** (chapéu e manto roxos, cajado com cristal),
**Rapper** (óculos pixelados, corrente de ouro com bolota), **Pato** (fantasia e boia amarelas — bom como mascote/evento).
Variações de noz da imagem 2 (coroa, gorro, lava, galáxia, rachada) servem como raridades/eventos futuros.

## 9. Dúvidas e limitações

1. Áudio não analisado; os sons do protótipo são placeholders dos sons embutidos do Roblox.
2. Timing exato de dano/respawn da referência não foi medido (frames a cada ~5 s).
3. "Hybrid" não está definido nos materiais — a interpretação está em §3 e precisa de confirmação.
4. Idioma da interface: usei inglês (como o nome do jogo e a referência). Confirmar.
5. Recompensa quando dois jogadores batem na mesma noz: dividi proporcionalmente ao dano. Confirmar.
6. As imagens 1 e 2 parecem arte conceitual gerada; não há modelos 3D correspondentes — os modelos do protótipo são
   aproximações em Parts.
