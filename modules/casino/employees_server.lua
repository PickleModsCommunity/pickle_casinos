print("^2[pickle_casinos] employees_server.lua loaded^0")

local function GetCasinoJobName(casinoId)
    local casino = Casinos[casinoId]
    if not casino then return nil end
    local oi = casino.owner_info
    if not oi then return nil end
    if oi.type ~= "job" then return nil end
    if type(oi.job) ~= "string" or oi.job == "" then return nil end
    return oi.job
end

-- pcall wrapper: if the inner function errors, log it and return the supplied
-- fallback so the client callback always resolves. Without this, an unexpected
-- error in the bridge (eg. accessing a nil PlayerData field) would propagate
-- up to ox_lib's callbackResponse, which logs but returns no values — leaving
-- the NUI fetch waiting forever and the EmployeesTab stuck on the spinner.
local function safe(fn, ...)
    local fallback = select(1, ...)
    local args = { select(2, ...) }
    local ok, a, b = pcall(fn, table.unpack(args))
    if not ok then
        print(("^1[pickle_casinos] employees callback error: %s^0"):format(tostring(a)))
        if type(fallback) == "table" and fallback.multi then
            return table.unpack(fallback.multi)
        end
        return fallback
    end
    return a, b
end

lib.callback.register("pickle_casinos:getEmployees", function(source, casinoId)
    return safe(function(src, cid)
        if not CanManageCasino(src, cid) then return {} end
        local jobName = GetCasinoJobName(cid)
        if not jobName or type(GetEmployees) ~= "function" then return {} end
        local employees = GetEmployees(jobName) or {}
        for _, emp in ipairs(employees) do
            if tonumber(emp.source) == tonumber(src) then
                emp.isSelf = true
            end
        end
        return employees
    end, {}, source, casinoId)
end)

lib.callback.register("pickle_casinos:getJobGrades", function(source, casinoId)
    return safe(function(src, cid)
        if not CanManageCasino(src, cid) then return {} end
        local jobName = GetCasinoJobName(cid)
        if not jobName or type(GetJobGrades) ~= "function" then return {} end
        return GetJobGrades(jobName) or {}
    end, {}, source, casinoId)
end)

-- True if `grade` is one of the job's defined grade levels (when the bridge can list them).
function JobGradeExists(jobName, grade)
    if type(GetJobGrades) ~= "function" then return true end
    local grades = GetJobGrades(jobName) or {}
    if #grades == 0 then return true end
    for _, g in ipairs(grades) do
        if tonumber(g.level) == grade then return true end
    end
    return false
end

lib.callback.register("pickle_casinos:setEmployeeGrade", function(source, casinoId, targetSource, grade)
    return safe(function(src, cid, tgt, grd)
        if not CanManageCasino(src, cid) then return false, "No access" end
        local jobName = GetCasinoJobName(cid)
        if not jobName or type(SetPlayerJob) ~= "function" then return false, "No job configured" end
        tgt = tonumber(tgt)
        grd = SanitizeInt(grd, 0)
        if not tgt or not grd then return false, "Invalid parameters" end
        if tgt == src then return false, "You can't change your own rank" end
        if type(GetPlayerJobName) ~= "function" or GetPlayerJobName(tgt) ~= jobName then
            return false, "Target is not an employee"
        end
        if not JobGradeExists(jobName, grd) then return false, "Invalid grade" end
        SetPlayerJob(tgt, jobName, grd)
        return true
    end, { multi = { false, "Error" } }, source, casinoId, targetSource, grade)
end)

lib.callback.register("pickle_casinos:fireEmployee", function(source, casinoId, targetSource)
    return safe(function(src, cid, tgt)
        if not CanManageCasino(src, cid) then return false, "No access" end
        if type(SetPlayerJob) ~= "function" then return false, "Not supported" end
        tgt = tonumber(tgt)
        if not tgt then return false, "Invalid target" end
        if tgt == src then return false, "You can't fire yourself" end
        -- Only job-owned casinos have employees, and only their own staff can be fired.
        local jobName = GetCasinoJobName(cid)
        if not jobName then return false, "No job configured" end
        if type(GetPlayerJobName) ~= "function" or GetPlayerJobName(tgt) ~= jobName then
            return false, "Target is not an employee"
        end
        SetPlayerJob(tgt, "unemployed", 0)
        ShowNotification(tgt, "You have been fired")
        return true
    end, { multi = { false, "Error" } }, source, casinoId, targetSource)
end)

lib.callback.register("pickle_casinos:hirePlayer", function(source, casinoId, targetSource)
    return safe(function(src, cid, tgt)
        if not CanManageCasino(src, cid) then return false, "No access" end
        local jobName = GetCasinoJobName(cid)
        if not jobName or type(SetPlayerJob) ~= "function" then return false, "No job configured" end
        tgt = tonumber(tgt)
        if not tgt or tgt == src then return false, "Invalid target" end
        -- Same rule the hire UI uses: the target must be standing next to the manager.
        local srcPed = GetPlayerPed(src)
        if not srcPed or srcPed == 0 or not IsPlayerNearCoords(tgt, GetEntityCoords(srcPed), 10.0) then
            return false, "Target is not nearby"
        end
        if type(GetPlayerJobName) == "function" and GetPlayerJobName(tgt) == jobName then
            return false, "Target is already an employee"
        end
        local lowestGrade = 0
        local grades = type(GetJobGrades) == "function" and GetJobGrades(jobName) or {}
        if grades[1] and grades[1].level then lowestGrade = grades[1].level end
        SetPlayerJob(tgt, jobName, lowestGrade)
        local name = (type(GetPlayerCharacterName) == "function" and GetPlayerCharacterName(tgt)) or ("Player " .. tgt)
        ShowNotification(tgt, "You have been hired!")
        return true, name
    end, { multi = { false, "Error" } }, source, casinoId, targetSource)
end)

lib.callback.register("pickle_casinos:getNearbyPlayers", function(source)
    return safe(function(src)
        local srcPed = GetPlayerPed(src)
        if not srcPed then return {} end
        local srcCoords = GetEntityCoords(srcPed)
        local players = {}
        for _, playerId in ipairs(GetPlayers()) do
            local pid = tonumber(playerId)
            if pid ~= src then
                local targetPed = GetPlayerPed(pid)
                if targetPed then
                    local targetCoords = GetEntityCoords(targetPed)
                    if #(srcCoords - targetCoords) < 10.0 then
                        local name = (type(GetPlayerCharacterName) == "function" and GetPlayerCharacterName(pid)) or GetPlayerName(pid)
                        players[#players + 1] = {
                            source = pid,
                            name = name or ("Player " .. pid),
                        }
                    end
                end
            end
        end
        return players
    end, {}, source)
end)
