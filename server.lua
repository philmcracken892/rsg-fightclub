local RSGCore = exports['rsg-core']:GetCoreObject()


local activeFight = nil
local bets = { challenger = {}, opponent = {} } 
local function CalculateDistance(coords1, coords2)
    if not coords1 or not coords2 or not coords1.x or not coords1.y or not coords1.z or not coords2.x or not coords2.y or not coords2.z then
        print("Error: Invalid coordinates provided to CalculateDistance - coords1: " .. tostring(coords1) .. ", coords2: " .. tostring(coords2))
        return math.huge 
    end
    local dx = coords1.x - coords2.x
    local dy = coords1.y - coords2.y
    local dz = coords1.z - coords2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end


RegisterNetEvent('rsg-saloonfights:challengePlayer')
AddEventHandler('rsg-saloonfights:challengePlayer', function(targetCharId, coords)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then
        
        return
    end

    if not coords then
       
        TriggerClientEvent('ox_lib:notify', src, { title = 'Fight', description = 'Failed to challenge: Invalid location!', type = 'error' })
        return
    end

    if Player.PlayerData.money['cash'] >= Config.FightCost then
        Player.Functions.RemoveMoney('cash', Config.FightCost, 'Challenged a player to a fight')
       
        activeFight = { challenger = src, coords = coords, opponent = nil }
        bets = { challenger = {}, opponent = {} }

        local players = RSGCore.Functions.GetPlayers() 
        local saloonRadius = Config.Saloons[1] and Config.Saloons[1].radius or 10.0 
        for _, playerId in ipairs(players) do
            if playerId ~= src then
                local playerPed = GetPlayerPed(playerId)
                if playerPed and DoesEntityExist(playerPed) then
                    local playerCoords = GetEntityCoords(playerPed)
                    if playerCoords and coords then
                        local distance = CalculateDistance(playerCoords, coords)
                        if distance <= saloonRadius then
                            TriggerClientEvent('rsg-saloonfights:client:challengeReceived', playerId, coords, src)
                           
                        end
                    else
                        
                    end
                else
                    
                end
            end
        end
        TriggerClientEvent('ox_lib:notify', src, { title = 'Fight', description = 'Waiting for an opponent to accept your challenge...', type = 'inform' })
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Fight', description = 'You don\'t have enough cash ($' .. Config.FightCost .. ')!', type = 'error' })
    end
end)

RegisterServerEvent('rsg-saloonfights:getOnlinePlayers')
AddEventHandler('rsg-saloonfights:getOnlinePlayers', function()
    local src = source 
    local players = RSGCore.Functions.GetPlayers() 
    local playerList = {}

    for _, playerId in ipairs(players) do
        if playerId ~= src then 
            local player = RSGCore.Functions.GetPlayer(playerId)
            if player then
                table.insert(playerList, {
                    serverId = playerId,
                    charid = player.PlayerData.citizenid, 
                    name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
                })
            end
        end
    end

    
    TriggerClientEvent('rsg-saloonfights:client:receiveOnlinePlayers', src, playerList)
end)

RegisterServerEvent('rsg-saloonfights:challengePlayer')
AddEventHandler('rsg-saloonfights:challengePlayer', function(targetCharId, challengerCoords)
    local src = source 
    local challenger = RSGCore.Functions.GetPlayer(src)
    if not challenger then return end

    
    if challenger.PlayerData.money['cash'] >= Config.FightCost then
        challenger.Functions.RemoveMoney('cash', Config.FightCost)

        
        local players = RSGCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local target = RSGCore.Functions.GetPlayer(playerId)
            if target and target.PlayerData.citizenid == targetCharId then
                
                TriggerClientEvent('rsg-saloonfights:client:challengeReceived', playerId, challengerCoords, challenger.PlayerData.citizenid)
                TriggerClientEvent('rsg-saloonfights:client:notifyChallenger', src, "Challenge sent to " .. target.PlayerData.charinfo.firstname .. " " .. target.PlayerData.charinfo.lastname)
                return
            end
        end
        
        TriggerClientEvent('rsg-saloonfights:client:notifyChallenger', src, "Player not found or offline!")
    else
        TriggerClientEvent('rsg-saloonfights:client:notifyChallenger', src, "You don’t have enough money ($" .. Config.FightCost .. ")!")
    end
end)

RegisterServerEvent('rsg-saloonfights:acceptChallenge')
AddEventHandler('rsg-saloonfights:acceptChallenge', function(challengerCoords)
    local acceptorId = source
    local acceptorPed = GetPlayerPed(acceptorId)
    local acceptorCoords = GetEntityCoords(acceptorPed)
    
    local players = RSGCore.Functions.GetPlayers()
    local challengerId = nil
    for _, playerId in ipairs(players) do
        local challengerPed = GetPlayerPed(playerId)
        local coords = GetEntityCoords(challengerPed)
        if #(coords - challengerCoords) < 1.0 then
            challengerId = playerId
            break
        end
    end

    if not challengerId then
        TriggerClientEvent('rsg-saloonfights:client:notifyChallenger', acceptorId, "Challenger not found!")
        return
    end

    
    local fightSaloon = nil
    for _, saloon in pairs(Config.Saloons) do
        local distance = #(challengerCoords - saloon.coords)
       
        if distance <= saloon.radius then
            fightSaloon = saloon
            break
        end
    end
    if not fightSaloon then
        
        TriggerClientEvent('rsg-saloonfights:client:notifyChallenger', acceptorId, "Fight failed: Not in a saloon!")
        return
    end
    

    
    TriggerClientEvent('rsg-saloonfights:client:startPlayerFight', challengerId, acceptorId)
    TriggerClientEvent('rsg-saloonfights:client:startPlayerFight', acceptorId, challengerId)
   

    
    for _, playerId in ipairs(players) do
        if playerId ~= challengerId and playerId ~= acceptorId then
           
            TriggerClientEvent('rsg-saloonfights:client:showFightBlip', playerId, fightSaloon.coords)
        end
    end
end)


RegisterNetEvent('rsg-saloonfights:placeBet')
AddEventHandler('rsg-saloonfights:placeBet', function(fightCoords, betOnChallenger)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local betAmount = Config.BetAmount

    if activeFight and #(GetEntityCoords(GetPlayerPed(src)) - fightCoords) <= Config.Saloons[1].radius and src ~= activeFight.challenger and src ~= activeFight.opponent then
        if Player.PlayerData.money['cash'] >= betAmount then
            Player.Functions.RemoveMoney('cash', betAmount, 'Placed a bet on bar fight')
            local betTable = betOnChallenger and bets.challenger or bets.opponent
            table.insert(betTable, { player = src, amount = betAmount })
           
        else
            TriggerClientEvent('ox_lib:notify', src, { title = 'Fight', description = 'You don\'t have enough cash to bet!', type = 'error' })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Fight', description = 'No active fight to bet on or you\'re a fighter!', type = 'error' })
    end
end)


RegisterNetEvent('rsg-saloonfights:fightOutcome')
AddEventHandler('rsg-saloonfights:fightOutcome', function(outcome, opponentId)
    if activeFight and (source == activeFight.challenger or source == activeFight.opponent) then
        local challengerPool = 0
        local opponentPool = 0
        for _, bet in ipairs(bets.challenger) do challengerPool = challengerPool + bet.amount end
        for _, bet in ipairs(bets.opponent) do opponentsPool = opponentPool + bet.amount end
        local totalPool = challengerPool + opponentPool

        if outcome == true then 
            local winner = source
            local loser = (source == activeFight.challenger) and activeFight.opponent or activeFight.challenger
            local winningBets = (winner == activeFight.challenger) and bets.challenger or bets.opponent
            local losingBets = (winner == activeFight.challenger) and bets.opponent or bets.challenger
            
            for _, bet in ipairs(winningBets) do
                local Bettor = RSGCore.Functions.GetPlayer(bet.player)
                if Bettor then
                    local payout = bet.amount * 2 
                    Bettor.Functions.AddMoney('cash', payout, 'Won bet on  fight')
                    TriggerClientEvent('ox_lib:notify', bet.player, { title = 'Fight', description = 'Your fighter won! You earned $' .. payout .. '!', type = 'success' })
                end
            end
            for _, bet in ipairs(losingBets) do
                TriggerClientEvent('ox_lib:notify', bet.player, { title = 'Fight', description = 'Your fighter lost! You lost your $' .. bet.amount .. ' bet.', type = 'error' })
            end
           
        elseif outcome == false then 
            local winner = (source == activeFight.challenger) and activeFight.opponent or activeFight.challenger
            local winningBets = (winner == activeFight.challenger) and bets.challenger or bets.opponent
            local losingBets = (winner == activeFight.challenger) and bets.opponent or bets.challenger
            
            for _, bet in ipairs(winningBets) do
                local Bettor = RSGCore.Functions.GetPlayer(bet.player)
                if Bettor then
                    local payout = bet.amount * 2
                    Bettor.Functions.AddMoney('cash', payout, 'Won bet on bar fight')
                    TriggerClientEvent('ox_lib:notify', bet.player, { title = ' Fight', description = 'Your fighter won! You earned $' .. payout .. '!', type = 'success' })
                end
            end
            for _, bet in ipairs(losingBets) do
                TriggerClientEvent('ox_lib:notify', bet.player, { title = ' Fight', description = 'Your fighter lost! You lost your $' .. bet.amount .. ' bet.', type = 'error' })
            end
           
        else 
            for _, bet in ipairs(bets.challenger) do
                local Bettor = RSGCore.Functions.GetPlayer(bet.player)
                if Bettor then
                    Bettor.Functions.AddMoney('cash', bet.amount, 'Bet returned due to draw')
                    TriggerClientEvent('ox_lib:notify', bet.player, { title = 'Fight', description = 'Fight was a draw! Your $' .. bet.amount .. ' bet was returned.', type = 'inform' })
                end
            end
            for _, bet in ipairs(bets.opponent) do
                local Bettor = RSGCore.Functions.GetPlayer(bet.player)
                if Bettor then
                    Bettor.Functions.AddMoney('cash', bet.amount, 'Bet returned due to draw')
                    TriggerClientEvent('ox_lib:notify', bet.player, { title = 'Fight', description = 'Fight was a draw! Your $' .. bet.amount .. ' bet was returned.', type = 'inform' })
                end
            end
           
        end

        activeFight = nil
        bets = { challenger = {}, opponent = {} }
    end
end)


RegisterNetEvent('rsg-saloonfights:rewardWinner')
AddEventHandler('rsg-saloonfights:rewardWinner', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
       
        Player.Functions.AddMoney('cash', 50, 'Won a  fight')
        TriggerClientEvent('ox_lib:notify', src, { title = ' Fight', description = 'You received $50 for winning!', type = 'success' })
    else
       
    end
end)

RegisterServerEvent('rsg-saloonfights:fightEnded')
AddEventHandler('rsg-saloonfights:fightEnded', function(fightCoords)
    local players = RSGCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        
        
        TriggerClientEvent('rsg-saloonfights:client:removeFightBlip', playerId)
    end
    
end)