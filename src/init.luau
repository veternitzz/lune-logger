-- // Lune Std
local fs = require("@lune/fs") -- https://lune-org.github.io/docs/api-reference/fs
local stdio = require("@lune/stdio") -- https://lune-org.github.io/docs/api-reference/stdio
local datetime = require("@lune/datetime") -- https://lune-org.github.io/docs/api-reference/datetime
local process = require("@lune/process") -- https://lune-org.github.io/docs/api-reference/process

-- // Signal Setup
local signal = require("./signal")
local Signal = signal.new()

-- // Public Types
export type LogType = "info" | "log" | "warn" | "error" | "fatal"

-- // Class Types
type LoggerImpl = {
    __index: LoggerImpl,
    onLogPosted: any,
    log: (self: Logger, message: string) -> (),
    info: (self: Logger, message: string) -> (),
    warn: (self: Logger, message: string) -> (),
    error: (self: Logger, message: string) -> (),
    fatal: (self: Logger, message: string) -> (),
    setLogFile: (self: Logger, message: string) -> (),
}

type Logger = typeof(setmetatable({} :: {}, {} :: LoggerImpl))

-- // Types (these types are private and are not documented)
type StyleType = "bold" | "dim" | "reset"
type ColorType = "red" | "yellow" | "blue" | "white" | "green"
type TitleType = "WARN" | "ERROR" | "INFO" | "LOG" | "FATAL"
type PaddingType = " " | "  " | nil | ""

-- // Local Variables
local halted = false

local self = {}
self.__path = nil
self.__logs = 0

-- // Local Functions (functions that should not be public and are not documented)

local function halt()
    halted = true
end

local function getTimeDatestampIn8601()
    local now = datetime.now()
    local utc = now:toLocalTime()

    return `{utc.year}-{utc.month}-{utc.day}T{utc.hour}:{utc.minute}:{utc.second}`
end

local function getTimestampIn8601()
    local now = datetime.now()
    local utc = now:toLocalTime()

    return `{utc.hour}:{utc.minute}:{utc.second}`
end

local function logToFile(logType: LogType, path: string | nil, message: string, title: TitleType, padding: PaddingType)
    if not path then
        return
    end

    if not padding then
        padding = ""
    end

    if not fs.isFile(path) then
        fs.writeFile(path, "")
    end

    local contents = fs.readFile(path :: string)

    if contents == "" then
        fs.writeFile(path :: string, `{contents}{getTimeDatestampIn8601()} [{title}]:{padding} {message}`)
        return
    end

    fs.writeFile(path :: string, `{contents}\n{getTimeDatestampIn8601()} [{title}]:{padding} {message}`)

    return
end

local function resetConsole()
   stdio.write(stdio.style("reset")); stdio.write(stdio.color("reset")) 
end

local function logToConsole(style: StyleType, color: ColorType, title: TitleType, message: string, padding: PaddingType)

    if not padding then
        padding = ""
    end

    resetConsole()
    stdio.write(`{getTimestampIn8601()} [`)
    stdio.write(stdio.style(style)); stdio.write(stdio.color(color))
    stdio.write(title)
    resetConsole()
    stdio.write(`]:{padding} {message} \n`)
end

-- ============================================================================= --
-- LOGGER CLASS                                                                  --
-- ============================================================================= --

-- // Logger Class Definition
local module: LoggerImpl = {} :: LoggerImpl
module.__index = module


-- // Public Functions & Variables

module.onLogPosted = Signal

function module:log(message: string)
    self.__logs += 1

    if halted then
        halted = false
        return
    end

    logToConsole("bold", "white", "LOG", message, "  ")
    logToFile("log", self.__path, message, "LOG", "  ")
    Signal:Fire("log", message, halt)
end

function module:info(message: string)
    self.__logs += 1

    Signal:Fire("info", message, halt)

    if not halted then
        logToConsole("bold", "green", "INFO", message, " ")
        logToFile("info", self.__path, message, "INFO", " ")
    end

    halted = false
end

function module:warn(message: string)
    self.__logs += 1

    Signal:Fire("warn", message, halt)

    if not halted then
        logToConsole("bold", "yellow", "WARN", message, " ")
        logToFile("warn", self.__path, message, "WARN", " ")
    end

    halted = false
end

function module:error(message: string)
    self.__logs += 1

    Signal:Fire("error", message, halt)

    if not halted then
        logToConsole("bold", "red", "ERROR", message)
        logToFile("error", self.__path, message, "ERROR")
    end

    halted = false
end

function module:fatal(message: string)
    self.__logs += 1

    Signal:Fire("fatal", message, halt)

    if not halted then
        logToConsole("bold", "red", "FATAL", message)
        logToFile("fatal", self.__path, `{message}\n`, "FATAL")
        process.exit(1)
    end

    halted = false
end

function module:setLogFile(path: string | nil)
    self.__path = path
    print(self.__path)
end

-- // Returning
return setmetatable(self, module)