local _, LB = ...

-- Registry of illustrations: assetId -> installed texture. Books only store
-- assetIds; files come with the addon or with pack addons. Pure: no WoW API.
local Assets = {}
LB.Assets = Assets

local ID_PATTERN = "^[A-Za-z0-9][A-Za-z0-9%._:%-]*$"
local MAX_SIDE = 4096

local entries = {}

local function isPowerOfTwo(n)
    if type(n) ~= "number" or n < 1 or n > MAX_SIDE or n ~= math.floor(n) then return false end
    while n > 1 do
        if n % 2 ~= 0 then return false end
        n = n / 2
    end
    return true
end

local function validCoords(coords)
    if coords == nil then return true end
    if type(coords) ~= "table" or #coords ~= 4 then return false end
    for _, value in ipairs(coords) do
        if type(value) ~= "number" or value < 0 or value > 1 then return false end
    end
    return coords[1] < coords[2] and coords[3] < coords[4]
end

-- def = { path = "Interface\\AddOns\\<addon>\\...", width, height (powers of two),
-- coords? = { left, right, top, bottom } visible part }. Returns true or false.
function Assets.Register(assetId, def, source)
    if type(assetId) ~= "string" or #assetId > 80 or not string.find(assetId, ID_PATTERN) then return false end
    if type(def) ~= "table" or type(def.path) ~= "string" then return false end
    if not string.find(string.lower(def.path), "^interface\\addons\\") then return false end
    if not isPowerOfTwo(def.width) or not isPowerOfTwo(def.height) or not validCoords(def.coords) then
        return false
    end
    entries[assetId] = {
        path = def.path, width = def.width, height = def.height,
        coords = def.coords or { 0, 1, 0, 1 }, source = source,
    }
    return true
end

function Assets.Resolve(assetId)
    return entries[assetId]
end

function Assets.Exists(assetId)
    return entries[assetId] ~= nil
end

-- Height / width of the visible part, for layout; nil for unknown assets.
function Assets.Aspect(assetId)
    local asset = entries[assetId]
    if not asset then return nil end
    local c = asset.coords
    return (asset.height * (c[4] - c[3])) / (asset.width * (c[2] - c[1]))
end

function Assets.Count()
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    return count
end
