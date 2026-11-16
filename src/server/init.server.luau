-- Server bootstrap. Order matters: map gives the nut spawn points.
require(script.SelfCheck)()
local spawnPoints = require(script.MapBuilder).build()
require(script.PlayerData).start()
require(script.NutService).start(spawnPoints)
require(script.ShopService).start()
