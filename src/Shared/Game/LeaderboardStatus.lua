--[[
    LeaderboardStatus

    Chooses one compact People-list title from already-cached leaderboard snapshots.
    This is deliberately pure: LeaderboardService owns publication/caching and this module only
    resolves the best visible placement. A lower rank wins; config order breaks exact ties.
]]

local LeaderboardStatus = {}

function LeaderboardStatus.bestForUser(userId, boards, entriesByBoard, rankLimit)
    local numericUserId = tonumber(userId)
    local limit = math.max(1, math.floor(tonumber(rankLimit) or 10))
    local best = nil

    for boardOrder, board in ipairs(boards or {}) do
        local title = board.status_title
        if type(title) == "string" and title ~= "" then
            for index, entry in ipairs(entriesByBoard[board.id] or {}) do
                local rank = math.max(1, math.floor(tonumber(entry.rank) or index))
                if rank > limit then
                    break
                end
                if tonumber(entry.userId) == numericUserId then
                    if
                        not best
                        or rank < best.rank
                        or (rank == best.rank and boardOrder < best.boardOrder)
                    then
                        best = {
                            title = title,
                            rank = rank,
                            boardId = board.id,
                            boardOrder = boardOrder,
                        }
                    end
                    break
                end
            end
        end
    end

    return best
end

return LeaderboardStatus
