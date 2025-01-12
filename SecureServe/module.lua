local createEntity = function(originalFunction, ...)
	local entity = originalFunction(...)
	if entity then
		if IsDuplicityVersion() then
			TriggerClientEvent('entity2', -1, GetEntityModel(entity))
			TriggerEvent("entityCreatedByScript", entity, 'fdgfd', true, GetEntityModel(entity))
		else
			TriggerEvent('entityCreatedByScriptClient', entity)
			TriggerServerEvent("entityCreatedByScript", entity, 'fdgfd', true, GetEntityModel(entity))
		end
		return entity
	end
end

local _CreateObject = CreateObject
local _CreateObjectNoOffset = CreateObjectNoOffset
local _CreateVehicle = CreateVehicle
local _CreatePed = CreatePed
local _CreatePedInsideVehicle = CreatePedInsideVehicle
local _CreateRandomPed = CreateRandomPed
local _CreateRandomPedAsDriver = CreateRandomPedAsDriver
local _CreateScriptVehicleGenerator = CreateScriptVehicleGenerator
local _CreateVehicleServerSetter = CreateVehicleServerSetter

CreateObject = function(...) return createEntity(_CreateObject, ...) end
CreateObjectNoOffset = function(...) return createEntity(_CreateObjectNoOffset, ...) end
CreateVehicle = function(...) return createEntity(_CreateVehicle, ...) end
CreatePed = function(...) return createEntity(_CreatePed, ...) end
CreatePedInsideVehicle = function(...) return createEntity(_CreatePedInsideVehicle, ...) end
CreateRandomPed = function(...) return createEntity(_CreateRandomPed, ...) end
CreateRandomPedAsDriver = function(...) return createEntity(_CreateRandomPedAsDriver, ...) end
CreateScriptVehicleGenerator = function(...) return createEntity(_CreateScriptVehicleGenerator, ...) end
CreateVehicleServerSetter = function(...) return createEntity(_CreateVehicleServerSetter, ...) end

local encryption_key = "c4a2ec5dc103a3f730460948f2e3c01df39ea4212bc2c82f"

local xor_encrypt = function(text, key)
    local res = {}
    local key_len = #key
    for i = 1, #text do
        local xor_byte = string.byte(text, i) ~ string.byte(key, (i - 1) % key_len + 1)
        res[i] = string.char(xor_byte)
    end
    return table.concat(res)
end

local encryptEventName = function(event_name, key)
    local encrypted = xor_encrypt(event_name, key)
    local result = ""
    for i = 1, #encrypted do
        result = result .. string.format("%03d", string.byte(encrypted, i))
    end
    return result
end

local xor_decrypt = function(encrypted_text, key)
    local res = {}
    local key_len = #key
    for i = 1, #encrypted_text do
        local xor_byte = string.byte(encrypted_text, i) ~ string.byte(key, (i - 1) % key_len + 1)
        res[i] = string.char(xor_byte)
    end
    return table.concat(res)
end

local decryptEventName = function(encrypted_name, key)
    if not encrypted_name:match("^%d+$") or (#encrypted_name % 3 ~= 0) then
        -- print("Decryption failed: invalid encrypted_name format ->", encrypted_name)
        return encrypted_name
    end

    local encrypted = {}
    for i = 1, #encrypted_name, 3 do
        local byte_str = encrypted_name:sub(i, i + 2)
        local byte = tonumber(byte_str)
        if byte and byte >= 0 and byte <= 255 then
            table.insert(encrypted, string.char(byte))
        else
            -- print("Decryption failed: invalid byte detected ->", byte_str)
            return nil
        end
    end

    local concatenated = table.concat(encrypted)
    -- print("Concatenated Encrypted String:", concatenated) -- Debugging
    local decrypted = xor_decrypt(concatenated, key)
    -- print("Decrypted Event Name:", decrypted) -- Debugging

    return decrypted
end


local fxEvents = {
    ["onResourceStart"] = true,
    ["onResourceStarting"] = true,
    ["onResourceStop"] = true,
    ["onServerResourceStart"] = true,
    ["onServerResourceStop"] = true,
    ["gameEventTriggered"] = true,
    ["populationPedCreating"] = true,
    ["rconCommand"] = true,
    ["playerConnecting"] = true,
    ["playerDropped"] = true,
    ["onResourceListRefresh"] = true,
    ["weaponDamageEvent"] = true,
    ["vehicleComponentControlEvent"] = true,
    ["respawnPlayerPedEvent"] = true,
    ["explosionEvent"] = true,
    ["fireEvent"] = true,
    ["entityRemoved"] = true,
    ["playerJoining"] = true,
    ["startProjectileEvent"] = true,
    ["playerEnteredScope"] = true,
    ["playerLeftScope"] = true,
    ["ptFxEvent"] = true,
    ["removeAllWeaponsEvent"] = true,
    ["giveWeaponEvent"] = true,
    ["removeWeaponEvent"] = true,
    ["clearPedTasksEvent"] = true,
	["msk_core:server:triggerCallback"] = true,
}


if IsDuplicityVersion() then
    local _AddEventHandler = AddEventHandler
    local _RegisterNetEvent = RegisterNetEvent

	local eventsToRegister = {}

	RegisterNetEvent = function(event_name, ...)
        local encrypted_event_name = encryptEventName(event_name, encryption_key)
		if select("#", ...) == 0 then
			eventsToRegister[encrypted_event_name] = {}
			CancelEvent()
			return
		else
			-- print(event_name, encrypted_event_name)
			_RegisterNetEvent(encrypted_event_name, ...)
			_RegisterNetEvent(encrypted_event_name,  function()
				if not (GetCurrentResourceName() == "monitor" or GetCurrentResourceName() == "SecureServe") then
					exports['SecureServe']:CheckTime(event_name, os.time(), source)
				end
			end)

			_RegisterNetEvent(event_name, ...)

			_RegisterNetEvent(event_name, function(...)
				if not event_name or type(event_name) ~= "string" then
					local TE = TriggerEvent
					local rencrypted_event_namea = encryptEventName("SecureServe:Server:Methods:PunishPlayer", encryption_key)
					TE(rencrypted_event_namea, source, "Triggerd server event via excutor: ".. event_name, webhook, 2147483647)
				end
				exports['SecureServe']:IsEventWhitelisted(decryptEventName(event_name, encryption_key), source)
			end)
		end
	end
	
	AddEventHandler = function(event_name, handler)
        local encrypted_event_name = encryptEventName(event_name, encryption_key)
		if not fxEvents[event_name] and not event_name:find("__cfx_") then
			if tonumber(event_name) == nil then
				if handler and type(handler) == 'function' and eventsToRegister[encrypted_event_name] then
					_AddEventHandler(event_name, handler)
					eventsToRegister[encrypted_event_name][#eventsToRegister[encrypted_event_name] + 1] = handler
				else
					_AddEventHandler(event_name, handler)
				end
			else
				_AddEventHandler(event_name, handler)
			end
		else
			_AddEventHandler(event_name, handler)
		end
	end

    Citizen.CreateThread(function ()
        for event_name, handlers in pairs(eventsToRegister) do
			_RegisterNetEvent(event_name, table.unpack(handlers))
            local decrypted_name = decryptEventName(event_name, encryption_key)
            if decrypted_name then
				_RegisterNetEvent(decrypted_name, function(...)
					if not event_name or type(event_name) ~= "string" then
						local TE = TriggerEvent
						local rencrypted_event_namea = encryptEventName("SecureServe:Server:Methods:PunishPlayer", encryption_key)
						TE(rencrypted_event_namea, source, "Triggerd server event via excutor: " .. (event_name or "nice try"), webhook, 2147483647)
					end
					exports['SecureServe']:IsEventWhitelisted(decrypted_name, source) 
				end)
            else
                -- print("Failed to decrypt event name: " .. event_name .. "Event wont be protected and will be needed to chnage manully to use only RegisterNetEvent")
            end
        end
    end)

	RegisterServerEvent = RegisterNetEvent

else
	local whitelistedEvents = {}

	Citizen.CreateThread(function()
		if GetCurrentResourceName() == "monitor" or GetCurrentResourceName() == "SecureServe" then
			whitelistedEvents = {}
		else
			local success, events = pcall(function()
				return exports['SecureServe']:GetEventWhitelist()
			end)
	
			if success and events then
				whitelistedEvents = {}
	
				for _, eventName in ipairs(events) do
					local encryptedEventName = encryptEventName(eventName, encryption_key)
					whitelistedEvents[eventName] = true
					whitelistedEvents[encryptedEventName] = true
				end
			else
				whitelistedEvents = {}
			end
		end
	end)
	
	local allowed = false
	RegisterNetEvent('allowed', function ()
		allowed = true
	end)

	local _TriggerServerEvent = TriggerServerEvent
	TriggerServerEvent = function(event_name, ...)
		local value = false
		if GetCurrentResourceName() == "monitor" or GetCurrentResourceName() == "SecureServe" then
			value = false
		elseif whitelistedEvents[event_name] or fxEvents[event_name] then
			value = true
		else
			value = false
		end
		if not value then
			local encrypted_event_name = encryptEventName(event_name, encryption_key)
			_TriggerServerEvent(encrypted_event_name, ...)
			if not  (GetCurrentResourceName() == "monitor" or GetCurrentResourceName() == "SecureServe") then
				if allowed then
					exports['SecureServe']:TriggeredEvent(event_name, GlobalState.SecureServe)
				end
			end
		else
			_TriggerServerEvent(event_name, ...)
		end
	end

	local function isValidResource(resourceName)
		local invalidResources = {
			nil, 
			"fivem", 
			"gta", 
			"citizen", 
			"system" 
		}
	
		for _, invalid in ipairs(invalidResources) do
			if resourceName == invalid then
				return false
			end
		end
	
		return true
	end
	
	local _AddExplosion = AddExplosion
	AddExplosion = function(x, y, z, explosionType, damageScale, isAudible, isInvisible, cameraShake)
		local resourceName = GetCurrentResourceName()
		if isValidResource(resourceName) then
			TriggerServerEvent("SecureServe:Explosions:Whitelist", {
				source = GetPlayerServerId(PlayerId()),
				resource = resourceName
			})
		end
		_AddExplosion(x, y, z, explosionType, damageScale, isAudible, isInvisible, cameraShake)
	end
	
	local _AddExplosionWithUserVfx = AddExplosionWithUserVfx
	AddExplosionWithUserVfx = function(x, y, z, explosionType, damageScale, isAudible, isInvisible, cameraShake)
		local resourceName = GetCurrentResourceName()
		if isValidResource(resourceName) then
			TriggerServerEvent("SecureServe:Explosions:Whitelist", {
				source = GetPlayerServerId(PlayerId()),
				resource = resourceName
			})
		end
		_AddExplosionWithUserVfx(x, y, z, explosionType, damageScale, isAudible, isInvisible, cameraShake)
	end
	
	local _ExplodeVehicle = ExplodeVehicle
	ExplodeVehicle = function(vehicle, isAudible, isInvisible)
		local resourceName = GetCurrentResourceName()
		if isValidResource(resourceName) then
			TriggerServerEvent("SecureServe:Explosions:Whitelist", {
				source = GetPlayerServerId(PlayerId()),
				resource = resourceName
			})
		end
		_ExplodeVehicle(vehicle, isAudible, isInvisible)
	end
	
	local _NetworkExplodeVehicle = NetworkExplodeVehicle
	NetworkExplodeVehicle = function(vehicle, isAudible, isInvisible, damageScale)
		local resourceName = GetCurrentResourceName()
		if isValidResource(resourceName) then
			TriggerServerEvent("SecureServe:Explosions:Whitelist", {
				source = GetPlayerServerId(PlayerId()),
				resource = resourceName
			})
		end
		_NetworkExplodeVehicle(vehicle, isAudible, isInvisible, damageScale)
	end
	
	local _ShootSingleBulletBetweenCoords = ShootSingleBulletBetweenCoords
	ShootSingleBulletBetweenCoords = function(x1, y1, z1, x2, y2, z2, damage, isAudible, weaponHash, owner, isExplosiveAmmo, ignoreEntity, speed)
		local resourceName = GetCurrentResourceName()
		if isValidResource(resourceName) then
			TriggerServerEvent("SecureServe:Explosions:Whitelist", {
				source = GetPlayerServerId(PlayerId()),
				resource = resourceName
			})
		end
		_ShootSingleBulletBetweenCoords(x1, y1, z1, x2, y2, z2, damage, isAudible, weaponHash, owner, isExplosiveAmmo, ignoreEntity, speed)
	end
	

end