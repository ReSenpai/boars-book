local _, LB = ...

local L = LB.L
local commands = {}
local defaultHandler
local output = function(line) print(line) end
local slash, headerKey = "/lb", "CMD_HELP_HEADER"

local Commands = {}
LB.Commands = Commands

function Commands.SetOutput(fn)
    output = fn
end

-- The slash command and header shown in help (a book addon has its own).
function Commands.SetSlash(name, header)
    slash = name
    headerKey = header or headerKey
end

function Commands.Print(line)
    output(line)
end

function Commands.Register(name, handler, helpKey)
    commands[string.lower(name)] = { handler = handler, helpKey = helpKey }
end

function Commands.SetDefault(handler)
    defaultHandler = handler
end

function Commands.PrintHelp()
    output(L(headerKey))
    local names = {}
    for name in pairs(commands) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        output(string.format("  %s %s - %s", slash, name, L(commands[name].helpKey)))
    end
end

function Commands.Dispatch(message)
    message = string.gsub(message or "", "^%s+", "")
    message = string.gsub(message, "%s+$", "")
    if message == "" then
        if defaultHandler then
            defaultHandler()
        else
            Commands.PrintHelp()
        end
        return
    end
    local name, args = string.match(message, "^(%S+)%s*(.*)$")
    local command = commands[string.lower(name)]
    if not command then
        output(L("CMD_UNKNOWN", name))
        Commands.PrintHelp()
        return
    end
    command.handler(args)
end

Commands.Register("help", function() Commands.PrintHelp() end, "CMD_HELP_HELP")
