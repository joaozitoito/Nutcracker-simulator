-- Loading and saving player state. Knows nothing about what the state means: PlayerData.sanitize validates it.
--
-- WHERE SAVING IS ON: only in a place listed in Persistence.Environments with enabled = true, matched by the exact
-- game.PlaceId. Everywhere else (unpublished files, Studio without a match, any other place) store() returns nil and
-- nothing is ever read or written. Each environment has its own DataStore name AND key prefix, so test and production
-- data can never share a key even inside the same universe (DataStores are also separated per universe by Roblox).
--
-- RECORD FORMAT (one per player, key = keyPrefix .. userId):
--   <PlayerData snapshot fields> + saves = number of saves so far + lock = { id = session id, time = os.time() } | nil
--
-- SESSION LOCK (prevents an old server from overwriting a newer one, and a new server from loading stale data):
--   * open() takes the lock in UpdateAsync. If another live session holds it (refreshed less than LOCK_STALE seconds
--     ago) it waits and retries; after LOCK_TRIES it takes the lock over (that server is gone or stuck).
--   * save() writes only if the stored lock is still this session's. If another session took over, the save is
--     dropped and the session is closed: an old copy never overwrites what a newer session wrote.
--   * save(snapshot, true) is the final save: it releases the lock so the next server can load at once.
--   * saves of one session run one at a time (autosave and leave-save never race), and after the final save the
--     session refuses further writes.
--   * a failed load returns no session: the caller must not let that player play with unsaved progress.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Persistence = {}

-- placeId = the exact game.PlaceId allowed to use the environment. Production stays disabled (no placeId, enabled =
-- false) until it has its own validation; enabling it is a deliberate edit of this table, nothing else.
Persistence.Environments = {
	{
		name = "test",
		enabled = true,
		placeId = 111667852947708, -- private test experience (universe 10777051784)
		storeName = "Nutcracker_TEST_PlayerData_v1",
		keyPrefix = "test_player_",
	},
	{
		name = "production",
		enabled = false,
		placeId = nil, -- fill in with the main experience's PlaceId when production saving is approved
		storeName = "PlayerData_v1",
		keyPrefix = "player_",
	},
}

local RETRIES = 3 -- per DataStore call
local LOCK_TRIES = 5 -- attempts to get a lock held by another live session before taking it over
local LOCK_WAIT = 3 -- seconds between those attempts
local LOCK_STALE = 300 -- a lock not refreshed for this long belongs to a dead server: take it at once

local dataStore -- cached store for this server, false if it failed

-- The environment this server is running in, or nil if saving is not allowed here.
function Persistence.environment()
	for _, environment in Persistence.Environments do
		if environment.enabled and environment.placeId ~= nil and environment.placeId == game.PlaceId then
			return environment
		end
	end
	return nil
end

-- The live store, or nil when this place is not an enabled environment or DataStores are unreachable.
function Persistence.store()
	local environment = Persistence.environment()
	if not environment then
		return nil
	end
	if dataStore == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(environment.storeName)
		end)
		dataStore = ok and result or false
		if not ok then
			warn("[Persistence] DataStore unavailable, saving is off:", result)
		end
	end
	return dataStore or nil
end

function Persistence.keyFor(userId: number, prefix: string?): string
	local environment = Persistence.environment()
	return (prefix or (environment and environment.keyPrefix) or "player_") .. userId
end

-- In-memory stand-in with the same method; `failUpdate` makes it throw, to test the error paths.
function Persistence.memoryStore()
	local store = { values = {}, failUpdate = false, calls = 0 }
	function store:UpdateAsync(key, transform)
		self.calls += 1
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

-- Loads one player's record and takes its lock. Returns (session, savedRecord) — the record is {} for a new player.
-- Returns nil if the store could not be used: the caller must not save for that player.
-- options = { prefix?, lockTries?, lockWait? } (tests use these to keep waits short)
function Persistence.open(store, userId: number, options)
	options = options or {}
	local key = Persistence.keyFor(userId, options.prefix)
	local id = HttpService:GenerateGUID(false)
	local tries = options.lockTries or LOCK_TRIES
	local record, tookOver

	for try = 1, tries do
		local blocked = false
		local ok = attempt(function()
			store:UpdateAsync(key, function(current)
				if type(current) ~= "table" then
					current = {} -- new player (or an unreadable value, which sanitize would discard anyway)
				end
				local lock = current.lock
				local live = type(lock) == "table" and lock.id ~= id and os.time() - (tonumber(lock.time) or 0) < LOCK_STALE
				if live and try < tries then
					blocked = true
					return nil -- another session still holds it: change nothing, try again shortly
				end
				blocked = false
				tookOver = live
				current.lock = { id = id, time = os.time() }
				record = current
				return current
			end)
		end)
		if not ok then
			return nil
		end
		if not blocked then
			break
		end
		task.wait(options.lockWait or LOCK_WAIT)
	end
	if not record then
		return nil
	end

	local session = { id = id, key = key, saves = record.saves or 0, tookOver = tookOver, closed = false, busy = false }

	-- Writes `snapshot` (a plain table). `final` = true releases the lock and closes the session.
	-- Returns true only if it was really stored.
	function session:save(snapshot, final: boolean?): boolean
		while self.busy do
			task.wait(0.05)
		end
		if self.closed or type(snapshot) ~= "table" then
			return false
		end
		self.busy = true
		local stored, lost = false, false
		local ok = attempt(function()
			store:UpdateAsync(key, function(current)
				local lock = type(current) == "table" and current.lock
				if type(lock) ~= "table" or lock.id ~= self.id then
					lost = true
					return nil -- another session owns this record now: never overwrite its newer data
				end
				local record = table.clone(snapshot)
				record.saves = (tonumber(current.saves) or 0) + 1
				record.lock = not final and { id = self.id, time = os.time() } or nil
				stored = true
				return record
			end)
		end)
		if ok and stored then
			self.saves += 1
		end
		if lost then
			warn(`[Persistence] {key}: another session took over this record; this session stops saving`)
			self.closed = true
		elseif final and ok and stored then
			self.closed = true
		end
		self.busy = false
		return ok and stored
	end

	return session, record
end

return Persistence
