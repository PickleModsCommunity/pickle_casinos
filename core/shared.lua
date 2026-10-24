Templates = {}

function lerp(a, b, t) return a + (b-a) * t end

function v3(coords) return vec3(coords.x, coords.y, coords.z), coords.w end

function GetRandomInt(min, max, exclude)
    for i=1, 1000 do 
        local int = math.random(min, max)
        if exclude == nil or exclude ~= int then 
            return int
        end
    end
end

function debugPrint(...)
    if Config.Debug then
        print(...)
    end
end

function NumberWithCommas(x, noCurrency)
    local left, num, right = string.match(x, '^([^%d]*%d)(%d*)(.-)$')
    return (not noCurrency and "$" or "") .. left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())
end

function tolower(str)
    return string.lower(str)
end

function GetItemLabel(name)
    return (Inventory.Items[name] and Inventory.Items[name].label or name)
end

function GetCurrencyString(amount)
    return NumberWithCommas(amount)
end

-- Returns `value` as an integer when it is a finite whole number within
-- [min, max] (either bound optional), otherwise nil. Use this for every
-- quantity that arrives from a client (wagers, amounts, indexes, settings):
-- net events can carry any Lua type, including floats, NaN and infinity.
function SanitizeInt(value, min, max)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    if value ~= math.floor(value) then return nil end
    value = math.tointeger(value) or value
    if min and value < min then return nil end
    if max and value > max then return nil end
    return value
end
