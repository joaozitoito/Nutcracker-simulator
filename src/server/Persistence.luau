-- Loading and saving player state. Knows nothing about what the state means: PlayerData.sanitize validates it.
--
-- STATUS: real DataStore saving is OFF (Persistence.Enabled = false). It has only been exercised against the in-memory
-- store below, never against Roblox DataStores. Turn it on only after testing in a published place with
-- "Enable Studio Access to API Services".
--
-- A store is anything with GetAsync(key) and UpdateAsync(key, transform) — a GlobalDataStore or memoryStore().
-- Safety rules:
--   * a failed load returns no session, so the caller never saves over data it could not read
--   * every save carries a counter; if the stored counter is not the one this session loaded, another server wrote
--     in between and the save is abandoned instead of overwriting newer data
--   * the transform refuses to store anything that is not a table
local DataStoreService = game:GetService("DataStoreService")

local Persistence = {}

Persistence.Enabled = false
Persistence.StoreName = "PlayerData_v1"
local RETRIES = 3

local dataStore

-- The live store, or nil when saving is disabled / unavailable (unpublished place, API access off).
function Persistence.store()
	if not Persistence.Enabled then
		return nil
	end
	if dataStore == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Persistence.StoreName)
		end)
		dataStore = ok and result or false
		if not ok then
			warn("[Persistence] DataStore unavailable, saving is off:", result)
		end
	end
	return dataStore or nil
end

-- In-memory stand-in with the same two methods; `failGet` / `failUpdate` make it throw, to test the error paths.
function Persistence.memoryStore()
	local store = { values = {}, failGet = false, failUpdate = false }
	function store:GetAsync(key)
		if self.failGet then
			error("simulated GetAsync failure")
		end
		return self.values[key]
	end
	function store:UpdateAsync(key, transform)
		if self.failUpdate then
			error("simulated UpdateAsync failure")
		end
		local value = transform(self.values[key])
		if value ~= nil then
			self.values[key] = value
		end
		return value
	end
	return store
end

local function attempt(action)
	local ok, result
	for try = 1, RETRIES do
		ok, result = pcall(action)
		if ok then
			return true, result
		end
		if try < RETRIES then
			task.wait(try)
		end
	end
	return false, result
end

-- Loads one player's data. Returns (session, saved) — `saved` is nil for a new player.
-- Returns nil if the store could not be read: the caller must not save for that player.
function Persistence.open(store, userId: number)
	local key = "player_" .. userId
	local ok, saved = attempt(function()
		return store:GetAsync(key)
	end)
	if not ok then
		return nil
	end
	if saved ~= nil and type(saved) ~= "table" then
		saved = nil -- unreadable value: treat as new, the counter check below still protects newer writes
	end

	local session = { saves = saved and saved.saves or 0 }
	-- Writes `snapshot`. Returns true only if it was really stored.
	function session:save(snapshot): boolean
		if type(snapshot) ~= "table" then
			return false
		end
		local stored = false
		local saveOk = attempt(function()
			store:UpdateAsync(key, function(current)
				local currentSaves = type(current) == "table" and current.saves or 0
				if currentSaves ~= self.saves then
					return nil -- someone else saved after we loaded: keep theirs
				end
				snapshot.saves = self.saves + 1
				stored = true
				return snapshot
			end)
		end)
		if saveOk and stored then
			self.saves += 1
			return true
		end
		return false
	end
	return session, saved
end

return Persistence
