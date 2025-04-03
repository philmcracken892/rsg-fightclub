local RSGCore = exports['rsg-core']:GetCoreObject()

-- Fight and betting data
local activeFight = nil
local bets = { challenger = {}, opponent = {} } -- Separate tables for bets on each fighter

-- Event to challenge another player
RegisterNetEvent('rsg-fightclub:challengePlayer')
AddEventHandler('rsg-fightclub:challengePlayer', function(coords)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player.PlayerData.money['cash'] >= Config.FightCost then
        Player.Functions.RemoveMoney('cash', Config.FightCost, 'Challenged a player to a fight')
        print("Player " .. src .. " paid $" .. Config.FightCost .. " to challenge a player")
        activeFight = { challenger = src, coords = coords, opponent = nil }
        bets = { challenger = {}, opponent = {} }

        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local playerPed = GetPlayerPed(playerId)
            local playerCoords = GetEntityCoords(playerPed)
            if #(playerCoords - coords) <= Config.Saloons[1].radius and playerId ~= src then
                TriggerClientEvent('rsg-fightclub:client:challengeReceived', playerId, coords)
            end
        end
        TriggerClientEvent('ox_lib:notify', src, { title = ' Fight', description = 'Waiting for an opponent to accept your challenge...', type = 'inform' })
    else
        TriggerClientEvent('ox_lib:notify', src, { title = ' Fight', description = 'You don\'t have enough cash ($' .. Config.FightCost .. ')!', type = 'error' })
    end
end)

RegisterServerEvent('rsg-saloonfights:getOnlinePlayers')
AddEventHandler('rsg-saloonfights:getOnlinePlayers', function()
    local src = source -- The player requesting the list
    local players = RSGCore.Functions.GetPlayers() -- Get all online players
    local playerList = {}

    for _, playerId in ipairs(players) do
        if playerId ~= src then -- Exclude the requesting player
            local player = RSGCore.Functions.GetPlayer(playerId)
            if player then
                table.insert(playerList, {
                    serverId = playerId,
                    charid = player.PlayerData.citizenid, -- Assuming 'citizenid' is the charid in RSGCore
                    name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
                })
            end
        end
    end

    -- Send the list back to the client
    TriggerClientEvent('rsg-saloonfights:client:receiveOnlinePlayers', src, playerList)
end)

RegisterServerEvent('rsg-saloonfights:challengePlayer')
AddEventHandler('rsg-saloonfights:challengePlayer', function(targetCharId, challengerCoords)
    local src = source -- The challenger
    local challenger = RSGCore.Functions.GetPlayer(src)
    if not challenger then return end

    -- Check if challenger has enough money
    if challenger.PlayerData.money['cash'] >= Config.FightCost then
        challenger.Functions.RemoveMoney('cash', Config.FightCost)

        -- Find the target player by charid
        local players = RSGCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local target = RSGCore.Functions.GetPlayer(playerId)
            if target and target.PlayerData.citizenid == targetCharId then
                -- Notify the target player
                TriggerClientEvent('rsg-saloonfights:client:challengeReceived', playerId, challengerCoords, challenger.PlayerData.citizenid)
                TriggerClientEvent('rsg-saloonfights:client:notifyChallenger', src, "Challenge sent to " .. target.PlayerData.charinfo.firstname .. " " .. target.PlayerData.charinfo.lastname)
                return
            end
        end
        -- If target not found
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

    -- Find the saloon based on challenger coords
    local fightSaloon = nil
    for _, saloon in pairs(Config.Saloons) do
        local distance = #(challengerCoords - saloon.coords)
        print("Server: Checking saloon " .. saloon.name .. ", Distance: " .. distance .. ", Radius: " .. saloon.radius)
        if distance <= saloon.radius then
            fightSaloon = saloon
            break
        end
    end
    if not fightSaloon then
        print("Server: Error - Fight not in a saloon!")
        TriggerClientEvent('rsg-saloonfights:client:notifyChallenger', acceptorId, "Fight failed: Not in a saloon!")
        return
    end
    print("Server: Fight saloon found - " .. fightSaloon.name .. " at " .. tostring(fightSaloon.coords))

    -- Start fight for both players
    TriggerClientEvent('rsg-saloonfights:client:startPlayerFight', challengerId, acceptorId)
    TriggerClientEvent('rsg-saloonfights:client:startPlayerFight', acceptorId, challengerId)
    print("Server: Fight started between challenger " .. challengerId .. " and acceptor " .. acceptorId)

    -- Broadcast fight location to spectators
    for _, playerId in ipairs(players) do
        if playerId ~= challengerId and playerId ~= acceptorId then
            print("Server: Sending showFightBlip to spectator " .. playerId .. " at " .. tostring(fightSaloon.coords))
            TriggerClientEvent('rsg-saloonfights:client:showFightBlip', playerId, fightSaloon.coords)
        end
    end
end)

-- Handle bet placement with choice
RegisterNetEvent('rsg-fightclub:placeBet')
AddEventHandler('rsg-fightclub:placeBet', function(fightCoords, betOnChallenger)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local betAmount = Config.BetAmount

    if activeFight and #(GetEntityCoords(GetPlayerPed(src)) - fightCoords) <= Config.Saloons[1].radius and src ~= activeFight.challenger and src ~= activeFight.opponent then
        if Player.PlayerData.money['cash'] >= betAmount then
            Player.Functions.RemoveMoney('cash', betAmount, 'Placed a bet on bar fight')
            local betTable = betOnChallenger and bets.challenger or bets.opponent
            table.insert(betTable, { player = src, amount = betAmount })
            print("Player " .. src .. " placed a $" .. betAmount .. " bet on " .. (betOnChallenger and "challenger" or "opponent"))
        else
            TriggerClientEvent('ox_lib:notify', src, { title = 'Fight', description = 'You don\'t have enough cash to bet!', type = 'error' })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Fight', description = 'No active fight to bet on or you\'re a fighter!', type = 'error' })
    end
end)

-- Handle fight outcome and payouts
RegisterNetEvent('rsg-fightclub:fightOutcome')
AddEventHandler('rsg-fightclub:fightOutcome', function(outcome, opponentId)
    if activeFight and (source == activeFight.challenger or source == activeFight.opponent) then
        local challengerPool = 0
        local opponentPool = 0
        for _, bet in ipairs(bets.challenger) do challengerPool = challengerPool + bet.amount end
        for _, bet in ipairs(bets.opponent) do opponentsPool = opponentPool + bet.amount end
        local totalPool = challengerPool + opponentPool

        if outcome == true then -- Source player won
            local winner = source
            local loser = (source == activeFight.challenger) and activeFight.opponent or activeFight.challenger
            local winningBets = (winner == activeFight.challenger) and bets.challenger or bets.opponent
            local losingBets = (winner == activeFight.challenger) and bets.opponent or bets.challenger
            
            for _, bet in ipairs(winningBets) do
                local Bettor = RSGCore.Functions.GetPlayer(bet.player)
                if Bettor then
                    local payout = bet.amount * 2 -- Double the bet
                    Bettor.Functions.AddMoney('cash', payout, 'Won bet on  fight')
                    TriggerClientEvent('ox_lib:notify', bet.player, { title = 'Fight', description = 'Your fighter won! You earned $' .. payout .. '!', type = 'success' })
                end
            end
            for _, bet in ipairs(losingBets) do
                TriggerClientEvent('ox_lib:notify', bet.player, { title = 'Fight', description = 'Your fighter lost! You lost your $' .. bet.amount .. ' bet.', type = 'error' })
            end
            print("Fight ended: Player " .. winner .. " won against " .. loser)
        elseif outcome == false then -- Source player lost
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
            print("Fight ended: Player " .. winner .. " won against " .. source)
        else -- Draw
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
            print("Fight ended in a draw")
        end

        activeFight = nil
        bets = { challenger = {}, opponent = {} }
    end
end)

-- Event to reward the winner
RegisterNetEvent('rsg-fightclub:rewardWinner')
AddEventHandler('rsg-fightclub:rewardWinner', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
        print("Rewarding player " .. src .. " with $50 for winning the fight")
        Player.Functions.AddMoney('cash', 50, 'Won a  fight')
        TriggerClientEvent('ox_lib:notify', src, { title = ' Fight', description = 'You received $50 for winning!', type = 'success' })
    else
        print("Error: Player " .. src .. " not found for reward")
    end
end)

RegisterServerEvent('rsg-saloonfights:fightEnded')
AddEventHandler('rsg-saloonfights:fightEnded', function(fightCoords)
    local players = RSGCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        -- Send to all players, client will filter out fighters
        print("Server: Sending removeFightBlip to player " .. playerId)
        TriggerClientEvent('rsg-saloonfights:client:removeFightBlip', playerId)
    end
    print("Server: Fight ended, blip removal broadcasted")
end)