local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)
local Signal = require(script.Parent.Signal)

local PlayerDataAdapter = {}
PlayerDataAdapter.__index = PlayerDataAdapter

function PlayerDataAdapter.new(profileStoreKey, playerBaseKey, defaultData)
    local self = setmetatable({}, PlayerDataAdapter)

    -- Defaults
    self._baseKey = playerBaseKey
    self._defaultData = defaultData

    -- State
    self._loadedProfiles = {}
    self._profileStore = ProfileService.GetProfileStore(profileStoreKey, defaultData)

    -- Signals
    self._dataLoaded = Signal.new()
    self._dataUnloaded = Signal.new()

    return self
end

function PlayerDataAdapter:_onPlayerAdded(player)
    -- Load Profile
    local profileKey = self._baseKey .. tostring(player.UserId)
    local profile = self._profileStore:LoadProfileAsync(profileKey, "ForceLoad")

    -- Handle Load Failure
    if not profile then
        player:Kick("Failed to load player profile...")
        return
    end

    -- Handle Player Leaving
    if not player:IsDescendantOf(Players) then
        profile:Release()
        return
    end

    -- Handle Profile Release
    profile:ListenToRelease(function()
        self._loadedProfiles[player] = nil
        self._dataUnloaded:Fire(player)
        player:Kick()
    end)

    -- Reconcile Profile
    profile:Reconcile(self._defaultData)

    -- Store & Fire
    self._loadedProfiles[player] = profile
    self._dataLoaded:Fire(player)
end

function PlayerDataAdapter:Get(player, key)
    if self._loadedProfiles[player] == nil then
        error("Player data is not loaded")
        return
    end
    return self._loadedProfiles[player].Data[key]
end

function PlayerDataAdapter:Set(player, key, value)
    if self._loadedProfiles[player] == nil then
        error("Player data is not loaded")
        return
    end
    self._loadedProfiles[player].Data[key] = value
end

function PlayerDataAdapter:BindToDataLoaded(fn)
    for player, _ in self._loaded_profiles do
        task.spawn(fn, player)
    end

    self._dataLoaded:Connect(fn)
end

function PlayerDataAdapter:BindToDataUnloaded(fn)
    self._dataUnloaded:Connect(fn)
end

function PlayerDataAdapter:Start()
    for _, player in Players:GetPlayers() do
        self:_onPlayerAdded(player)
    end

    Players.PlayerAdded:Connect(function(player)
        self:_onPlayerAdded(player)
    end)
end

return PlayerDataAdapter