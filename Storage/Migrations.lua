local _, LB = ...

-- Sequential database migrations, always applied to a copy. Pure: no WoW API.
local Migrations = {}
LB.Migrations = Migrations

local DeepCopy = LB.Tables.DeepCopy

-- steps[v] migrates a database from version v - 1 to v.
-- Returns true, migratedCopy (with migrationBackup of the original), or false, error.
-- The input table is never modified.
function Migrations.Run(db, fromVersion, toVersion, steps)
    local original = DeepCopy(db)
    original.migrationBackup = nil
    local copy = DeepCopy(original)
    local ok, err = pcall(function()
        for version = fromVersion + 1, toVersion do
            local step = steps[version]
            if not step then
                error("missing migration to v" .. version, 0)
            end
            step(copy)
            copy.dbVersion = version
        end
    end)
    if not ok then
        return false, tostring(err)
    end
    copy.migrationBackup = { fromVersion = fromVersion, data = original }
    return true, copy
end
