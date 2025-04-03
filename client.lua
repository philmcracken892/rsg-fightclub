local RSGCore = exports['rsg-core']:GetCoreObject()

-- Prompt setup for saloon menu
local saloonPrompt = nil
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local fightBlip = nil
-- Prompt setup for betting
local betPrompt = nil
local betPromptGroup = GetRandomIntInRange(0, 0xffffff)

-- Prompt setup for accepting challenge
local acceptPrompt = nil
local acceptPromptGroup = GetRandomIntInRange(0, 0xffffff)

-- Create the saloon prompt
local function CreateSaloonPrompt()
    local str = 'Open Fight Menu'
    saloonPrompt = PromptRegisterBegin()
    PromptSetControlAction(saloonPrompt, 0xF3830D8E) -- Key: J
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(saloonPrompt, str)
    PromptSetEnabled(saloonPrompt, false)
    PromptSetVisible(saloonPrompt, false)
    PromptSetHoldMode(saloonPrompt, true)
    PromptSetGroup(saloonPrompt, promptGroup)
    PromptRegisterEnd(saloonPrompt)
end

-- Create the betting prompt
local function CreateBetPrompt()
    local str = 'Open Betting Menu (Hold K)'
    betPrompt = PromptRegisterBegin()
    PromptSetControlAction(betPrompt, 0xF84FA74F) -- Key: K
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(betPrompt, str)
    PromptSetEnabled(betPrompt, false)
    PromptSetVisible(betPrompt, false)
    PromptSetHoldMode(betPrompt, true)
    PromptSetGroup(betPrompt, betPromptGroup)
    PromptRegisterEnd(betPrompt)
end

-- Create the accept challenge prompt
local function CreateAcceptPrompt()
    local str = 'Accept Fight Challenge (Hold J)'
    acceptPrompt = PromptRegisterBegin()
    PromptSetControlAction(acceptPrompt, 0xF3830D8E) -- Key: L
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(acceptPrompt, str)
    PromptSetEnabled(acceptPrompt, false)
    PromptSetVisible(acceptPrompt, false)
    PromptSetHoldMode(acceptPrompt, true)
    PromptSetGroup(acceptPrompt, acceptPromptGroup)
    PromptRegisterEnd(acceptPrompt)
end

Citizen.CreateThread(function()
    CreateSaloonPrompt()
    CreateBetPrompt()
    CreateAcceptPrompt()

    -- Create blips for saloons (existing code)
    for _, saloon in pairs(Config.Saloons) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, saloon.coords.x, saloon.coords.y, saloon.coords.z) -- BLIP_STYLE_SHOP
        SetBlipSprite(blip, GetHashKey("blip_shop_saloon"), true) -- Saloon blip icon
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, saloon.name) -- Set blip name
        print("Saloon blip created for " .. saloon.name .. " at " .. tostring(saloon.coords))
    end

    -- Create static blip for Fight club
    local fightClub = Config.Saloons[1] -- Assuming "Fight club" is the first entry
    local fightBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, fightClub.coords.x, fightClub.coords.y, fightClub.coords.z)
    if fightBlip then
        SetBlipSprite(fightBlip, GetHashKey("blip_hat"), true) -- Use blip_hat sprite
        Citizen.InvokeNative(0x9CB1A1623062F402, fightBlip, "Fight Club") -- Set blip name
        print("Static fight blip created at " .. tostring(fightClub.coords) .. " with sprite blip_hat")
    else
        print("Failed to create static fight blip!")
    end
end)

local function CreateFightBlip(coords)
    print("Creating fight blip at coords: " .. tostring(coords))
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z) -- BLIP_STYLE_SHOP
    if blip then
        SetBlipSprite(blip, GetHashKey("blip_hat"), true) -- Use a brawl/fight blip icon
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Bar Fight in Progress") -- Set blip name
        print("Blip created successfully: " .. blip)
    else
        print("Failed to create blip!")
    end
    return blip
end

-- Function to check if player is near a saloon
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local inRange = false
        local nearestSaloon = nil

        for _, saloon in pairs(Config.Saloons) do
            local distance = #(playerCoords - saloon.coords)
            if distance <= saloon.radius then
                inRange = true
                if distance <= 1.5 then
                    nearestSaloon = saloon
                    break
                end
            end
        end

        if inRange and nearestSaloon then
            PromptSetEnabled(saloonPrompt, true)
            PromptSetVisible(saloonPrompt, true)
            local promptLabel = CreateVarString(10, 'LITERAL_STRING', nearestSaloon.name)
            PromptSetActiveGroupThisFrame(promptGroup, promptLabel)

            if PromptHasHoldModeCompleted(saloonPrompt) then
                OpenSaloonMenu(nearestSaloon.name)
                PromptSetEnabled(saloonPrompt, false)
                PromptSetVisible(saloonPrompt, false)
                Citizen.Wait(500)
            end
        else
            PromptSetEnabled(saloonPrompt, false)
            PromptSetVisible(saloonPrompt, false)
        end

        Citizen.Wait(0)
    end
end)

-- Function to open the saloon menu
function OpenSaloonMenu(saloonName)
    local playerPed = PlayerPedId()
    local health = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)
    local healthPercent = (health / maxHealth) * 100

    if healthPercent < Config.MinHealth then
        lib.notify({ title = saloonName, description = 'You\'re too weak to fight! Heal up first.', type = 'error' })
        return
    end

    -- Request online players from the server
    TriggerServerEvent('rsg-saloonfights:getOnlinePlayers')
end

RegisterNetEvent('rsg-saloonfights:client:receiveOnlinePlayers')
AddEventHandler('rsg-saloonfights:client:receiveOnlinePlayers', function(playerList)
    local saloonName = nil
    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, saloon in pairs(Config.Saloons) do
        if #(playerCoords - saloon.coords) <= saloon.radius then
            saloonName = saloon.name
            break
        end
    end
    if not saloonName then return end

    -- Build the menu options dynamically
    local options = {}
    if #playerList > 0 then
        for _, player in ipairs(playerList) do
            table.insert(options, {
                title = 'Challenge ' .. player.name,
                description = 'Fight ' .. player.name .. ' (CharID: ' .. player.charid .. ') for $' .. Config.FightCost,
                icon = 'fist-raised',
                onSelect = function()
                    TriggerServerEvent('rsg-saloonfights:challengePlayer', player.charid, GetEntityCoords(PlayerPedId()))
                end
            })
        end
    else
        table.insert(options, {
            title = 'No Players Available',
            description = 'No one is online to challenge.',
            icon = 'user-slash',
            disabled = true
        })
    end

    -- Add the "Leave" option
    table.insert(options, {
        title = 'Leave',
        description = 'Walk away peacefully.',
        icon = 'door-open',
        onSelect = function()
            lib.notify({ title = saloonName, description = 'You left the fight', type = 'success' })
        end
    })

    -- Show the menu
    lib.registerContext({
        id = 'saloon_menu',
        title = saloonName .. " - Bar Fight",
        options = options
    })
    lib.showContext('saloon_menu')
end)
RegisterNetEvent('rsg-saloonfights:client:notifyChallenger')
AddEventHandler('rsg-saloonfights:client:notifyChallenger', function(message)
    lib.notify({ title = 'Bar Fight', description = message, type = 'inform' })
end)

-- Handle challenge notification (updated to include challenger info)
RegisterNetEvent('rsg-saloonfights:client:challengeReceived')
AddEventHandler('rsg-saloonfights:client:challengeReceived', function(coords, challengerCharId)
    challengePending = true
    challengeCoords = coords
    lib.notify({ title = 'Bar Fight', description = 'Player (CharID: ' .. challengerCharId .. ') challenged you to a fight! Hold L to accept.', type = 'inform' })
end)

-- Betting prompt and menu for nearby players
local isFighting = false
local fightData = nil
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isFighting and fightData then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            for _, saloon in pairs(Config.Saloons) do
                local distance = #(playerCoords - saloon.coords)
                if distance <= saloon.radius and distance > 1.5 then -- Exclude fighters
                    PromptSetEnabled(betPrompt, true)
                    PromptSetVisible(betPrompt, true)
                    local promptLabel = CreateVarString(10, 'LITERAL_STRING', 'Bet on Bar Fight at ' .. saloon.name)
                    PromptSetActiveGroupThisFrame(betPromptGroup, promptLabel)

                    if PromptHasHoldModeCompleted(betPrompt) then
                        OpenBettingMenu(saloon.coords, saloon.name)
                        PromptSetEnabled(betPrompt, false)
                        PromptSetVisible(betPrompt, false)
                        Citizen.Wait(500)
                    end
                end
            end
        else
            PromptSetEnabled(betPrompt, false)
            PromptSetVisible(betPrompt, false)
        end
    end
end)

-- Function to open the betting menu with saloon name
function OpenBettingMenu(saloonCoords, saloonName)
    lib.registerContext({
        id = 'betting_menu',
        title = 'Bet on Bar Fight - ' .. saloonName,
        options = {
            {
                title = 'Bet on Challenger',
                description = 'Bet $10 on the player who started the fight.',
                icon = 'user',
                onSelect = function()
                    TriggerServerEvent('rsg-saloonfights:placeBet', saloonCoords, true)
                    lib.notify({ title = 'Bar Fight', description = 'You bet $10 on the challenger at ' .. saloonName .. '!', type = 'success' })
                end
            },
            {
                title = 'Bet on Opponent',
                description = 'Bet $10 on the player who accepted the fight.',
                icon = 'user',
                onSelect = function()
                    TriggerServerEvent('rsg-saloonfights:placeBet', saloonCoords, false)
                    lib.notify({ title = 'Bar Fight', description = 'You bet $10 on the opponent at ' .. saloonName .. '!', type = 'success' })
                end
            }
        }
    })
    lib.showContext('betting_menu')
end

-- Accept challenge prompt
local challengePending = false
local challengeCoords = nil
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if challengePending then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - challengeCoords)
            if distance <= Config.Saloons[1].radius and distance > 1.5 then -- Exclude challenger
                PromptSetEnabled(acceptPrompt, true)
                PromptSetVisible(acceptPrompt, true)
                local promptLabel = CreateVarString(10, 'LITERAL_STRING', 'Bar Fight Challenge')
                PromptSetActiveGroupThisFrame(acceptPromptGroup, promptLabel)

                if PromptHasHoldModeCompleted(acceptPrompt) then
                    TriggerServerEvent('rsg-saloonfights:acceptChallenge', challengeCoords)
                    PromptSetEnabled(acceptPrompt, false)
                    PromptSetVisible(acceptPrompt, false)
                    challengePending = false
                    Citizen.Wait(500)
                end
            end
        else
            PromptSetEnabled(acceptPrompt, false)
            PromptSetVisible(acceptPrompt, false)
        end
    end
end)

-- Handle challenge notification
RegisterNetEvent('rsg-saloonfights:client:challengeReceived')
AddEventHandler('rsg-saloonfights:client:challengeReceived', function(coords)
    challengePending = true
    challengeCoords = coords
    lib.notify({ title = 'Bar Fight', description = 'Someone challenged you to a fight! Hold L to accept.', type = 'inform' })
end)

RegisterNetEvent('rsg-saloonfights:client:showFightBlip')
AddEventHandler('rsg-saloonfights:client:showFightBlip', function(coords)
    if isFighting then
        print("Player is fighting, not showing blip")
        return
    end

    if fightBlip then
        RemoveBlip(fightBlip)
        fightBlip = nil
        print("Old fight blip removed")
    end

    fightBlip = CreateFightBlip(coords)
    if fightBlip then
        print("Fight blip assigned to global variable: " .. fightBlip)
    else
        print("Failed to assign fight blip!")
    end
end)

RegisterNetEvent('rsg-saloonfights:client:removeFightBlip')
AddEventHandler('rsg-saloonfights:client:removeFightBlip', function()
    if fightBlip then
        RemoveBlip(fightBlip)
        fightBlip = nil
        print("Fight blip removed")
    else
        print("No fight blip to remove!")
    end
end)

RegisterNetEvent('rsg-saloonfights:client:startPlayerFight')
AddEventHandler('rsg-saloonfights:client:startPlayerFight', function(opponentServerId)
    local playerPed = PlayerPedId()
    local opponentPed = GetPlayerPed(GetPlayerFromServerId(opponentServerId))
    
    if not DoesEntityExist(playerPed) or not DoesEntityExist(opponentPed) then
        print("Error: Player or opponent PED not found!")
        lib.notify({ title = 'Bar Fight', description = 'Fight failed: Opponent not found!', type = 'error' })
        return
    end

    isFighting = true
    fightData = { challenger = GetPlayerServerId(PlayerId()), opponent = opponentServerId }
    lib.notify({ title = 'Bar Fight', description = 'Fight started! Knock out your opponent!', type = 'inform' })

    -- Determine the saloon where the fight is happening
    local fightCoords = GetEntityCoords(playerPed)
    local fightSaloon = nil
    for _, saloon in pairs(Config.Saloons) do
        local distance = #(fightCoords - saloon.coords)
        print("Checking saloon: " .. saloon.name .. ", Distance: " .. distance .. ", Radius: " .. saloon.radius)
        if distance <= saloon.radius then
            fightSaloon = saloon
            break
        end
    end
    if not fightSaloon then
        print("Error: Fight not in a saloon!")
        lib.notify({ title = 'Bar Fight', description = 'Fight failed: Not in a saloon!', type = 'error' })
        return
    end
    print("Fight saloon found: " .. fightSaloon.name .. " at " .. tostring(fightSaloon.coords))

    -- Set combat attributes
    SetPedCombatAttributes(playerPed, 46, true)
    SetPedCombatAttributes(opponentPed, 46, true)
    SetPedCombatAttributes(playerPed, 5, true)
    SetPedCombatAttributes(opponentPed, 5, true)

    -- Make players hostile
    local playerGroup = GetPedRelationshipGroupHash(playerPed)
    local opponentGroup = GetPedRelationshipGroupHash(opponentPed)
    SetRelationshipBetweenGroups(5, playerGroup, opponentGroup)
    SetRelationshipBetweenGroups(5, opponentGroup, playerGroup)
    print("Relationship set: Player group " .. playerGroup .. " vs Opponent group " .. opponentGroup)

    -- Start combat
    ClearPedTasks(playerPed)
    ClearPedTasks(opponentPed)
    TaskCombatPed(playerPed, opponentPed, 0, 16)
    TaskCombatPed(opponentPed, playerPed, 0, 16)
    print("Combat tasks assigned: Player vs Opponent " .. opponentServerId)

    -- Fight loop
    local fightStart = GetGameTimer()
    local fightEnded = false
    local initialPlayerHealth = GetEntityHealth(playerPed)
    local initialOpponentHealth = GetEntityHealth(opponentPed)
    print("Initial Health - Player: " .. initialPlayerHealth .. ", Opponent: " .. initialOpponentHealth)

    while not fightEnded and (GetGameTimer() - fightStart) < Config.FightDuration do
        Citizen.Wait(100)
        local playerHealth = GetEntityHealth(playerPed)
        local opponentHealth = GetEntityHealth(opponentPed)

        print("Player Health: " .. playerHealth .. ", Opponent Health: " .. opponentHealth)

        if not DoesEntityExist(opponentPed) or opponentHealth <= 0 then
            print("Player won - Opponent health depleted or PED gone")
            lib.notify({ title = 'Bar Fight', description = 'You knocked out your opponent! You win $50!', type = 'success' })
            TriggerServerEvent('rsg-saloonfights:fightOutcome', true, opponentServerId)
            TriggerServerEvent('rsg-saloonfights:rewardWinner')
            fightEnded = true
        elseif playerHealth <= 0 then
            print("Player lost - Player health depleted")
            lib.notify({ title = 'Bar Fight', description = 'You got knocked out!', type = 'error' })
            TriggerServerEvent('rsg-saloonfights:fightOutcome', false, opponentServerId)
            fightEnded = true
        end
    end

    if not fightEnded then
        local playerHealth = GetEntityHealth(playerPed)
        local opponentHealth = GetEntityHealth(opponentPed)
        print("Fight timed out - Draw, Player Health: " .. playerHealth .. ", Opponent Health: " .. opponentHealth)
        lib.notify({ title = 'Bar Fight', description = 'The fight ended in a draw!', type = 'inform' })
        TriggerServerEvent('rsg-saloonfights:fightOutcome', nil, opponentServerId)
    end

    -- Clean up
    ClearPedTasks(playerPed)
    ClearPedTasks(opponentPed)
    SetRelationshipBetweenGroups(1, playerGroup, opponentGroup)
    SetRelationshipBetweenGroups(1, opponentGroup, playerGroup)
    isFighting = false
    fightData = nil

    -- Notify server to remove blip for spectators
    TriggerServerEvent('rsg-saloonfights:fightEnded', fightSaloon.coords)
end)