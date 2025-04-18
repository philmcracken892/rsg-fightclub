local RSGCore = exports['rsg-core']:GetCoreObject()


local saloonPrompt = nil
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local fightBlip = nil

local betPrompt = nil
local betPromptGroup = GetRandomIntInRange(0, 0xffffff)


local acceptPrompt = nil
local acceptPromptGroup = GetRandomIntInRange(0, 0xffffff)


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


local function CreateBetPrompt()
    local str = 'Open Betting Menu (Hold E)'
    betPrompt = PromptRegisterBegin()
    PromptSetControlAction(betPrompt, 0xCEFD9220) -- Key: E
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(betPrompt, str)
    PromptSetEnabled(betPrompt, false)
    PromptSetVisible(betPrompt, false)
    PromptSetHoldMode(betPrompt, true)
    PromptSetGroup(betPrompt, betPromptGroup)
    PromptRegisterEnd(betPrompt)
end


local function CreateAcceptPrompt()
    local str = 'Accept Fight Challenge (Hold J)'
    acceptPrompt = PromptRegisterBegin()
    PromptSetControlAction(acceptPrompt, 0xF3830D8E) -- Key: j
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

    
    for _, saloon in pairs(Config.Saloons) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, saloon.coords.x, saloon.coords.y, saloon.coords.z) 
        SetBlipSprite(blip, GetHashKey("blip_shop_saloon"), true) 
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, saloon.name) 
        
    end

    
    local fightClub = Config.Saloons[1] 
    local fightBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, fightClub.coords.x, fightClub.coords.y, fightClub.coords.z)
    if fightBlip then
        SetBlipSprite(fightBlip, GetHashKey("blip_hat"), true) 
        Citizen.InvokeNative(0x9CB1A1623062F402, fightBlip, "Fight Club") 
        
    else
        
    end
end)

local function CreateFightBlip(coords)
   
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z) 
    if blip then
        SetBlipSprite(blip, GetHashKey("blip_hat"), true) 
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Bar Fight in Progress") 
        
    else
        
    end
    return blip
end


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


function OpenSaloonMenu(saloonName)
    local playerPed = PlayerPedId()
    local health = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)
    local healthPercent = (health / maxHealth) * 600

    if healthPercent < Config.MinHealth then
        lib.notify({ title = saloonName, description = 'You\'re too weak to fight! Heal up first.', type = 'error' })
        return
    end

    
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

    
    table.insert(options, {
        title = 'Leave',
        description = 'Walk away peacefully.',
        icon = 'door-open',
        onSelect = function()
            lib.notify({ title = saloonName, description = 'You left the fight', type = 'success' })
        end
    })

    
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


RegisterNetEvent('rsg-saloonfights:client:challengeReceived')
AddEventHandler('rsg-saloonfights:client:challengeReceived', function(coords, challengerCharId)
    challengePending = true
    challengeCoords = coords
    lib.notify({ title = 'Bar Fight', description = 'Player (CharID: ' .. challengerCharId .. ') challenged you to a fight! Hold J to accept.', type = 'inform' })
end)


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
                if distance <= saloon.radius and distance > 1.5 then 
                    PromptSetEnabled(betPrompt, true)
                    PromptSetVisible(betPrompt, true)
                    local promptLabel = CreateVarString(10, 'LITERAL_STRING', 'Bet on Fight at ' .. saloon.name)
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


RegisterNetEvent('rsg-saloonfights:client:challengeReceived')
AddEventHandler('rsg-saloonfights:client:challengeReceived', function(coords)
    challengePending = true
    challengeCoords = coords
    lib.notify({ title = 'Bar Fight', description = 'Someone challenged you to a fight! Hold J to accept.', type = 'inform' })
end)

RegisterNetEvent('rsg-saloonfights:client:showFightBlip')
AddEventHandler('rsg-saloonfights:client:showFightBlip', function(coords)
    if isFighting then
        
        return
    end

    if fightBlip then
        RemoveBlip(fightBlip)
        fightBlip = nil
        
    end

    fightBlip = CreateFightBlip(coords)
    if fightBlip then
       
    else
       
    end
end)

RegisterNetEvent('rsg-saloonfights:client:removeFightBlip')
AddEventHandler('rsg-saloonfights:client:removeFightBlip', function()
    if fightBlip then
        RemoveBlip(fightBlip)
        fightBlip = nil
       
    else
        
    end
end)

RegisterNetEvent('rsg-saloonfights:client:startPlayerFight')
AddEventHandler('rsg-saloonfights:client:startPlayerFight', function(opponentServerId)
    local playerPed = PlayerPedId()
    local opponentPed = GetPlayerPed(GetPlayerFromServerId(opponentServerId))
    
    if not DoesEntityExist(playerPed) or not DoesEntityExist(opponentPed) then
        
        lib.notify({ title = 'Bar Fight', description = 'Fight failed: Opponent not found!', type = 'error' })
        return
    end

    isFighting = true
    fightData = { challenger = GetPlayerServerId(PlayerId()), opponent = opponentServerId }
    lib.notify({ title = 'Bar Fight', description = 'Fight started! Knock out your opponent!', type = 'inform' })

    
    local fightCoords = GetEntityCoords(playerPed)
    local fightSaloon = nil
    for _, saloon in pairs(Config.Saloons) do
        local distance = #(fightCoords - saloon.coords)
        
        if distance <= saloon.radius then
            fightSaloon = saloon
            break
        end
    end
    if not fightSaloon then
        
        lib.notify({ title = 'Bar Fight', description = 'Fight failed: Not in a saloon!', type = 'error' })
        return
    end
   

    
    SetPedCombatAttributes(playerPed, 46, true)
    SetPedCombatAttributes(opponentPed, 46, true)
    SetPedCombatAttributes(playerPed, 5, true)
    SetPedCombatAttributes(opponentPed, 5, true)

    
    local playerGroup = GetPedRelationshipGroupHash(playerPed)
    local opponentGroup = GetPedRelationshipGroupHash(opponentPed)
    SetRelationshipBetweenGroups(5, playerGroup, opponentGroup)
    SetRelationshipBetweenGroups(5, opponentGroup, playerGroup)
    

    
    ClearPedTasks(playerPed)
    ClearPedTasks(opponentPed)
    TaskCombatPed(playerPed, opponentPed, 0, 16)
    TaskCombatPed(opponentPed, playerPed, 0, 16)
    

    
    local fightStart = GetGameTimer()
    local fightEnded = false
    local playerKnockedOut = false
    local opponentKnockedOut = false
    
    
    local function ApplyExtendedRagdoll(ped)
        local ragdollDuration = 5000 
        local ragdollStart = GetGameTimer()
        
        CreateThread(function()
            
            SetPedToRagdoll(ped, ragdollDuration, ragdollDuration, 0, 0, 0, 0)
            
            
            while (GetGameTimer() - ragdollStart) < ragdollDuration do
                if not IsEntityDead(ped) and not IsPedRagdoll(ped) then
                    SetPedToRagdoll(ped, 1000, 1000, 0, 0, 0, 0)
                end
                Citizen.Wait(100)
            end
           
        end)
    end

    CreateThread(function()
        while not fightEnded and (GetGameTimer() - fightStart) < Config.FightDuration do
            Citizen.Wait(100)
            
            
            if not DoesEntityExist(playerPed) or not DoesEntityExist(opponentPed) then
               
                fightEnded = true
                break
            end
            
            local playerHealth = GetEntityHealth(playerPed)
            local opponentHealth = GetEntityHealth(opponentPed)
            local playerMaxHealth = GetEntityMaxHealth(playerPed)
            local opponentMaxHealth = GetEntityMaxHealth(opponentPed)
            local playerHealthPercent = (playerHealth / playerMaxHealth) * 100
            local opponentHealthPercent = (opponentHealth / opponentMaxHealth) * 100

            
            if playerHealthPercent <= 50 and not playerKnockedOut then
                Citizen.InvokeNative(0x1913FE4CBF41C463, playerPed, 11, true) 
                playerKnockedOut = true
                DisablePlayerFiring(PlayerId(), true)
                ApplyExtendedRagdoll(playerPed) 
                lib.notify({ title = 'Bar Fight', description = 'You got knocked out!', type = 'error' })
            end

            if opponentHealthPercent <= 50 and not opponentKnockedOut then
                Citizen.InvokeNative(0x1913FE4CBF41C463, opponentPed, 11, true) 
                opponentKnockedOut = true
                ApplyExtendedRagdoll(opponentPed) 
                lib.notify({ title = 'Bar Fight', description = 'You knocked out your opponent!', type = 'success' })
            end

            
            if playerKnockedOut and not opponentKnockedOut and not fightEnded then
                
                TriggerServerEvent('rsg-saloonfights:fightOutcome', false, opponentServerId)
                fightEnded = true
            elseif opponentKnockedOut and not playerKnockedOut and not fightEnded then
               
                lib.notify({ title = 'Bar Fight', description = 'You knocked out your opponent! You win $50!', type = 'success' })
                TriggerServerEvent('rsg-saloonfights:fightOutcome', true, opponentServerId)
                TriggerServerEvent('rsg-saloonfights:rewardWinner')
                fightEnded = true
            elseif playerKnockedOut and opponentKnockedOut and not fightEnded then
               
                lib.notify({ title = 'Bar Fight', description = 'Both fighters got knocked out! It\'s a draw!', type = 'inform' })
                TriggerServerEvent('rsg-saloonfights:fightOutcome', nil, opponentServerId)
                fightEnded = true
            elseif not DoesEntityExist(opponentPed) or opponentHealth <= 200 and not fightEnded then
               
                lib.notify({ title = 'Bar Fight', description = 'You knocked out your opponent! You win $50!', type = 'success' })
                TriggerServerEvent('rsg-saloonfights:fightOutcome', true, opponentServerId)
                TriggerServerEvent('rsg-saloonfights:rewardWinner')
                fightEnded = true
            elseif playerHealth <= 0 and not fightEnded then
                
                lib.notify({ title = 'Bar Fight', description = 'You got knocked out!', type = 'error' })
                TriggerServerEvent('rsg-saloonfights:fightOutcome', false, opponentServerId)
                fightEnded = true
            end
        end

        
        Citizen.Wait(7000)

        if not fightEnded then
            local playerHealth = GetEntityHealth(playerPed)
            local opponentHealth = GetEntityHealth(opponentPed)
            
            lib.notify({ title = 'Bar Fight', description = 'The fight ended in a draw!', type = 'inform' })
            TriggerServerEvent('rsg-saloonfights:fightOutcome', nil, opponentServerId)
        end

        -- Clean up
        ClearPedTasks(playerPed)
        if DoesEntityExist(opponentPed) then
            ClearPedTasks(opponentPed)
        end
        
        -- Reset relationship groups
        if playerGroup and opponentGroup then
            SetRelationshipBetweenGroups(1, playerGroup, opponentGroup)
            SetRelationshipBetweenGroups(1, opponentGroup, playerGroup)
        end
        
        
        if playerKnockedOut and DoesEntityExist(playerPed) then
            Citizen.InvokeNative(0x1913FE4CBF41C463, playerPed, 11, false) 
            
        end
        if opponentKnockedOut and DoesEntityExist(opponentPed) then
            Citizen.InvokeNative(0x1913FE4CBF41C463, opponentPed, 11, false) 
            
        end

        
        if playerKnockedOut then
            DisablePlayerFiring(PlayerId(), false)
        end

        isFighting = false
        fightData = nil

        
        if fightSaloon then
            TriggerServerEvent('rsg-saloonfights:fightEnded', fightSaloon.coords)
        end
    end)
end)