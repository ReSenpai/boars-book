local _, LB = ...

-- Library storage over the SavedVariables tables. Pure: the tables and the clock
-- are passed in; Bootstrap assigns the results back to the globals.
--
-- LoreBookDB (account-wide): books[bookId] = { current, previous?, source, addedAt, updatedAt },
--   drafts, collections, favorites, recent, readingPositions, bookmarks,
--   clientProfiles, settings, seeded[bookId], migrationBackup?
-- LoreBookCharacterDB: checklists, notes, ui.
local Storage = {}
LB.Storage = Storage

local DeepCopy = LB.Tables.DeepCopy

Storage.CURRENT_VERSION = 1
Storage.CURRENT_CHARACTER_VERSION = 1

-- MIGRATIONS[v] migrates the account database from v - 1 to v.
-- v0 = a table without dbVersion; defaults are filled in after migration.
Storage.MIGRATIONS = {
    [1] = function() end,
}
Storage.CHARACTER_MIGRATIONS = {
    [1] = function() end,
}

local ACCOUNT_TABLES = { "books", "drafts", "collections", "favorites", "recent",
    "readingPositions", "bookmarks", "clientProfiles", "settings", "seeded" }
local CHARACTER_TABLES = { "checklists", "notes", "ui" }

local function ensureTables(db, keys)
    for _, key in ipairs(keys) do
        if type(db[key]) ~= "table" then
            db[key] = {}
        end
    end
end

local function readOnlyError()
    return false, { { code = "STORAGE_READ_ONLY" } }
end

-- Opens one database: returns db, status, error.
-- status: fresh | ok | migrated | newer | failed.
local function openDatabase(raw, currentVersion, migrations)
    if type(raw) ~= "table" or next(raw) == nil then
        return { dbVersion = currentVersion }, "fresh"
    end
    local version = type(raw.dbVersion) == "number" and raw.dbVersion or 0
    if version > currentVersion then
        return raw, "newer"
    end
    if version < currentVersion then
        local ok, result = LB.Migrations.Run(raw, version, currentVersion, migrations)
        if not ok then
            return raw, "failed", result
        end
        return result, "migrated"
    end
    return raw, "ok"
end

local function isWritable(status)
    return status ~= "newer" and status ~= "failed"
end

local function seedBuiltinBooks(store, builtinBooks)
    local db = store.account
    local keys = {}
    for key in pairs(builtinBooks or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local book = builtinBooks[key]
        if not db.seeded[book.bookId] then
            if not db.books[book.bookId] then
                Storage.PutEdition(store, book, "builtin")
            end
            db.seeded[book.bookId] = true
        end
    end
end

-- options: now (function -> unix time), builtinBooks, migrations, currentVersion (tests).
function Storage.Open(rawAccount, rawCharacter, options)
    options = options or {}
    local store = { now = options.now or os.time, readOnly = false }

    local account, status, err = openDatabase(rawAccount,
        options.currentVersion or Storage.CURRENT_VERSION, options.migrations or Storage.MIGRATIONS)
    local character, characterStatus, characterErr = openDatabase(rawCharacter,
        Storage.CURRENT_CHARACTER_VERSION, Storage.CHARACTER_MIGRATIONS)

    store.account, store.status, store.error = account, status, err
    store.character, store.characterStatus, store.characterError = character, characterStatus, characterErr
    store.readOnly = not (isWritable(status) and isWritable(characterStatus))

    if isWritable(status) then
        ensureTables(account, ACCOUNT_TABLES)
    end
    if isWritable(characterStatus) then
        ensureTables(character, CHARACTER_TABLES)
    end
    if not store.readOnly then
        seedBuiltinBooks(store, options.builtinBooks)
    end
    return store
end

function Storage.GetBook(store, bookId)
    local entry = store.account.books[bookId]
    return entry and entry.current
end

function Storage.GetEntry(store, bookId)
    return store.account.books[bookId]
end

-- Validates and stores a deep copy of `book` as the current edition; the
-- replaced edition is kept as `previous`. Returns true or false, errors.
function Storage.PutEdition(store, book, source)
    if store.readOnly then
        return readOnlyError()
    end
    local valid, errors = LB.BookValidator.Validate(book)
    if not valid then
        return false, errors
    end
    local books = store.account.books
    local existing = books[book.bookId]
    local now = store.now()
    books[book.bookId] = {
        current = DeepCopy(book),
        previous = existing and existing.current or nil,
        source = source or (existing and existing.source) or "imported",
        addedAt = existing and existing.addedAt or now,
        updatedAt = now,
    }
    return true
end

-- Swaps the current and previous editions (rollback that can itself be undone).
function Storage.SwapEditions(store, bookId)
    local entry = store.account.books[bookId]
    if store.readOnly or not entry or not entry.previous then
        return false
    end
    entry.current, entry.previous = entry.previous, entry.current
    entry.updatedAt = store.now()
    return true
end

-- New unique local ID with a monotonic counter; `exists(id)` defaults to book IDs.
function Storage.NewId(store, prefix, exists)
    exists = exists or function(id) return store.account.books[id] ~= nil end
    local settings = store.account.settings
    local id
    repeat
        settings.idCounter = (settings.idCounter or 0) + 1
        id = LB.Ids.Generate(prefix, store.now(), settings.idCounter)
    until not exists(id)
    return id
end

-- Removes a book and references to it. Reading positions and bookmarks are kept
-- so that re-importing the book restores them.
function Storage.RemoveBook(store, bookId)
    if store.readOnly then
        return false
    end
    local db = store.account
    db.books[bookId] = nil
    db.favorites[bookId] = nil
    local recent = {}
    for _, id in ipairs(db.recent) do
        if id ~= bookId then recent[#recent + 1] = id end
    end
    db.recent = recent
    for _, collection in pairs(db.collections) do
        if type(collection.bookIds) == "table" then
            for i = #collection.bookIds, 1, -1 do
                if collection.bookIds[i] == bookId then
                    table.remove(collection.bookIds, i)
                end
            end
        end
    end
    return true
end

-- Book summaries sorted by title (bytewise), then bookId.
function Storage.ListBooks(store)
    local list = {}
    for bookId, entry in pairs(store.account.books) do
        local book = entry.current
        list[#list + 1] = {
            bookId = bookId,
            title = book.title,
            authorName = book.authorName,
            revision = book.revision,
            source = entry.source,
        }
    end
    table.sort(list, function(a, b)
        if a.title ~= b.title then
            return LB.Tables.BytewiseLess(a.title, b.title)
        end
        return LB.Tables.BytewiseLess(a.bookId, b.bookId)
    end)
    return list
end

function Storage.CountBooks(store)
    local count = 0
    for _ in pairs(store.account.books) do count = count + 1 end
    return count
end
