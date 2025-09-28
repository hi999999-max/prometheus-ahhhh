-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- AntiTamper.lua (modified)
--
-- This Script provides an Obfuscation Step, that breaks the script, when someone tries to tamper with it.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "This Step Breaks your Script when it is modified. This is only effective when using the new VM.";
AntiTamper.Name = "Anti Tamper";

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = true,
        description = "Use debug library. (Recommended, however scripts will not work without debug library.)"
    },
    CheckUnPack = {
        type = "boolean",
        default = true, -- changed default to true
        description = "Wrap and monitor unpack/table.unpack for tampering. (This protection is always appended by the step.)"
    }
}

function AntiTamper:init(settings)
	
end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end
	local code = "do local valid = true;";
    if self.UseDebug then
        local string = RandomStrings.randomString();
            -- Append scurot anti-tamper watchdog
    code = code .. [[

-- scurot: hardened anti-tamper / integrity watchdog
do
    local real_game = game
    local real_GetService = game and game.GetService
    local real_type = type
    local real_task_wait = (task and task.wait) or function() wait(0.05) end
    local real_task_spawn = (task and task.spawn) or coroutine.wrap
    local real_math_random = math and math.random
    local real_error = error
    local real_rawget = rawget
    local real_tostring = tostring
    local real_pcall = pcall

    local function lock_and_error(msg)
        pcall(real_error, msg)
        while true do
            real_task_wait(1)
        end
    end

    local function safe_is_instance(x)
        local t = real_type(x)
        return t == "Instance" or t == "userdata" or t == "table"
    end

    local function check_integrity()
        if real_game ~= game then
            lock_and_error("tamper detected: game replaced")
        end
        if real_GetService and game and game.GetService ~= real_GetService then
            lock_and_error("tamper detected: GetService hooked")
        end
        if not safe_is_instance(real_game) then
            lock_and_error("tamper detected: game type unexpected")
        end
    end

    local function detect_hooking()
        local ok = real_pcall(function() end)
        if not ok then
            lock_and_error("tamper detected: pcall behavior changed")
        end
        if debug ~= nil then
            if real_type(debug.getinfo) ~= "function" then
                lock_and_error("tamper detected: debug.getinfo replaced")
            end
        end
    end

    local function safe_setmetatable(obj, mt)
        local t = real_type(obj)
        if t == "table" then
            return setmetatable(obj, mt)
        end
        if debug and type(debug.setmetatable) == "function" then
            local ok, res = pcall(function() return debug.setmetatable(obj, mt) end)
            return ok and res or nil
        end
        return nil
    end

    local trap_obj = nil
    if type(newproxy) == "function" then
        local ok, maybe = pcall(function() return newproxy(true) end)
        if ok and maybe ~= nil then
            trap_obj = maybe
        end
    end
    if not trap_obj then
        trap_obj = {}
    end

    local mt = {
        __tostring = function() lock_and_error("tamper detected: proxy inspected") end,
        __index = function() lock_and_error("tamper detected: proxy indexed") end,
        __newindex = function() lock_and_error("tamper detected: proxy written") end,
        __metatable = false,
    }

    safe_setmetatable(trap_obj, mt)

    local function hidden_trap() return trap_obj end
    pcall(function() real_tostring(hidden_trap()) end)

    real_task_spawn(function()
        while true do
            pcall(function()
                if real_GetService then
                    real_GetService(game, "Players")
                    real_GetService(game, "RunService")
                end
            end)
            pcall(check_integrity)
            pcall(detect_hooking)
            real_task_wait(4)
        end
    end)

    pcall(function()
        if real_rawget(_G, "a9380") then
            lock_and_error("tamper detected: bait var hit")
        end
        local v1 = real_rawget(_G, "v2354")
        local v2 = real_rawget(_G, "z937597")
        if v1 and v2 and v1 == v2 then
            lock_and_error("tamper detected: fake var triggered")
        end
    end)

    real_task_spawn(function()
        while true do
            local ok = real_pcall(function() if real_math_random then real_math_random() end end)
            if not ok then
                lock_and_error("tamper detected: math.random hooked")
            end
            local jitter = 7
            if real_math_random then
                local r = real_math_random(0, 3)
                if type(r) == "number" then jitter = jitter + r end
            end
            real_task_wait(jitter)
        end
    end)

    real_task_spawn(function()
        while true do
            local ok, _ = pcall(function() if game and type(game.GetService) ~= "function" then lock_and_error("tamper detected: GetService type changed") end end)
            real_task_wait(10)
        end
    end)
end
]]
end
    code = code .. [[
    local gmatch = string.gmatch;
    local err = function() error("Tamper Detected!") end;

    local pcallIntact2 = false;
    local pcallIntact = pcall(function()
        pcallIntact2 = true;
    end) and pcallIntact2;

    local random = math.random;
    local tblconcat = table.concat;
    local unpkg = table and table.unpack or unpack;
    local n = random(3, 65);
    local acc1 = 0;
    local acc2 = 0;
    local pcallRet = {pcall(function() local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[ return "]] .. RandomStrings.randomString() .. [[" / a; end)};
    local origMsg = pcallRet[2];
    local line = tonumber(gmatch(tostring(origMsg), ':(%d*):')());
    for i = 1, n do
        local len = math.random(1, 100);
        local n2 = random(0, 255);
        local pos = random(1, len);
        local shouldErr = random(1, 2) == 1;
        local msg = origMsg:gsub(':(%d*):', ':' .. tostring(random(0, 10000)) .. ':');
        local arr = {pcall(function()
            if random(1, 2) == 1 or i == n then
                local line2 = tonumber(gmatch(tostring(({pcall(function() local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[ return "]] .. RandomStrings.randomString() .. [[" / a; end)})[2]), ':(%d*):')());
                valid = valid and line == line2;
            end
            if shouldErr then
                error(msg, 0);
            end
            local arr = {};
            for i = 1, len do
                arr[i] = random(0, 255);
            end
            arr[pos] = n2;
            return unpkg(arr);
        end)};
        if shouldErr then
            valid = valid and arr[1] == false and arr[2] == msg;
        else
            valid = valid and arr[1];
            acc1 = (acc1 + arr[pos + 1]) % 256;
            acc2 = (acc2 + n2) % 256;
        end
    end
    valid = valid and acc1 == acc2;

    if valid then else
        repeat 
            return (function()
                while true do
                    l1, l2 = l2, l1;
                    err();
                end
            end)(); 
        until true;
        while true do
            l2 = random(1, 6);
            if l2 > 2 then
                l2 = tostring(l1);
            else
                l1 = l2;
            end
        end
        return;
    end
end

    -- Anti Function Arg Hook
    local obj = setmetatable({}, {
        __tostring = err,
    });
    obj[math.random(1, 100)] = obj;
    (function() end)(obj);

    repeat until valid;
    ]]

    -- Force append CheckUnPack protection (always enabled)
    code = code .. [[

-- CheckUnPack Protection
-- Anti-Tamper wrapper for unpack / table.unpack
-- Prints a friendly message and sends chat if someone tries to overwrite unpack

-- Save original
local original_unpack = rawget(_G, "unpack") or (table and table.unpack)
if type(original_unpack) ~= "function" then
    original_unpack = function(tbl, i, j)
        if table and table.unpack then
            return table.unpack(tbl, i, j)
        end
        error("unpack/table.unpack unavailable")
    end
end

local protected_ref = nil

-- Wrapper: just calls original
local function wrapper_unpack(tbl, i, j)
    return original_unpack(tbl, i, j)
end

protected_ref = wrapper_unpack

-- Set global safely
if rawset and _G then
    rawset(_G, "unpack", wrapper_unpack)
else
    _G["unpack"] = wrapper_unpack
end
if type(getgenv) == "function" then
    pcall(function() getgenv().unpack = wrapper_unpack end)
end

-- Anti-tamper notification
local function check_unpack()
    local current_unpack = rawget(_G, "unpack") or (table and table.unpack)
    if not rawequal(current_unpack, original_unpack) and not rawequal(current_unpack, protected_ref) then
        pcall(function()
            print("Hmm? Tried tampering? Won't work buddy.")
        end)

        -- Send chat messages safely
        local success, TextChatService = pcall(function()
            return game and game.GetService and game:GetService("TextChatService")
        end)
        if success and TextChatService and TextChatService.TextChannels then
            local RBXGeneral = TextChatService.TextChannels.RBXGeneral
            if RBXGeneral then
                pcall(function()
                    RBXGeneral:SendAsync("I'm A Skid!")
                end)
            end
        end
    end
end

-- Monitor periodically for at least 5 seconds
spawn(function()
    local ok, tick_fn = pcall(function() return tick end)
    local startTime = (ok and tick_fn) and tick() or os.time()
    while true do
        -- use task.wait if available, else fallback
        if type(task) == "table" and type(task.wait) == "function" then
            pcall(task.wait, 0.01)
        else
            pcall(function() wait(0.01) end)
        end
        pcall(check_unpack)
        -- Stop after 5 seconds
        local now = (ok and tick_fn) and tick() or os.time()
        if now - startTime >= 5 then
            break
        end
    end
end)

        ]]

    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.LuaU}):parse(code);
    local doStat = parsed.body.statements[1];
    doStat.body.scope:setParent(ast.body.scope);
    table.insert(ast.body.statements, 1, doStat);

    return ast;
end

return AntiTamper;
