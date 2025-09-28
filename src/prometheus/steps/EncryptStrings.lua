-- Optimised & slightly harder-to-read EncryptStrings.lua
-- Part of the Prometheus Obfuscator by Levno_710
-- Encrypts strings and injects a runtime decryptor

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")
local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()
EncryptStrings.Description = "This Step will encrypt strings within your Program."
EncryptStrings.Name = "Encrypt Strings"
EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings) end

-- Keep API identical but optimize internals and localize frequently used functions
function EncryptStrings:CreateEncrypionService()
    local usedSeeds = {}

    local floor, random, char, byte, concat = math.floor, math.random, string.char, string.byte, table.concat

    local secret_key_6  = random(0, 63)                       -- 6-bit
    local secret_key_7  = random(0, 127)                      -- 7-bit
    local secret_key_44 = random(0, 17592186044415)           -- 44-bit
    local secret_key_8  = random(0, 255)                      -- 8-bit

    -- small deterministic generator (kept simple and deterministic-ish)
    local function primitive_root_257(idx)
        local g, m, d = 1, 128, 2 * idx + 1
        while m >= 1 do
            g = (g * g * (d >= m and 3 or 1)) % 257
            m = m / 2
            d = d % m
        end
        return g
    end

    local param_mul_8 = primitive_root_257(secret_key_7)
    local param_mul_45 = secret_key_6 * 4 + 1
    local param_add_45 = secret_key_44 * 2 + 1

    local state_45 = 0
    local state_8 = 2

    local prev_values = {}

    local function set_seed(seed_53)
        state_45 = seed_53 % 35184372088832
        state_8 = seed_53 % 255 + 2
        -- clear in-place
        for i = 1, #prev_values do prev_values[i] = nil end
    end

    local function gen_seed()
        local seed
        repeat
            seed = random(0, 35184372088832)
        until not usedSeeds[seed]
        usedSeeds[seed] = true
        return seed
    end

    -- compact PRNG step; semantics kept equivalent to original implementation
    local function get_random_32()
        state_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832
        repeat
            state_8 = (state_8 * param_mul_8) % 257
        until state_8 ~= 1
        local r = state_8 % 32
        -- match original arithmetic exactly; avoid creating intermediate tables
        local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
        local rnd = floor(n % 1 * 2 ^ 32) + floor(n)
        return rnd
    end

    -- returns 0..255 bytes using cached 4-bytes buffer (pop from end)
    local function get_next_pseudo_random_byte()
        if #prev_values == 0 then
            local rnd = get_random_32()
            local low_16 = rnd % 65536
            local high_16 = (rnd - low_16) / 65536
            prev_values[1] = low_16 % 256
            prev_values[2] = (low_16 - prev_values[1]) / 256
            prev_values[3] = high_16 % 256
            prev_values[4] = (high_16 - prev_values[3]) / 256
        end
        return table.remove(prev_values)
    end

    -- encrypt: returns encrypted string and the seed for runtime decrypt
    local function encrypt(str)
        local seed = gen_seed()
        set_seed(seed)
        local len = #str
        local out = {}
        local prevVal = secret_key_8
        for i = 1, len do
            local b = byte(str, i)
            out[i] = char((b - (get_next_pseudo_random_byte() + prevVal)) % 256)
            prevVal = b
        end
        return concat(out), seed
    end

    -- generate the runtime decryption chunk (semantics identical; micro-optimized & shorter)
    local function genCode()
        local pm45, pa45, pm8, sk8 = param_mul_45, param_add_45, param_mul_8, secret_key_8

        -- produce a compact runtime that reconstructs random stream and a cached table of real strings
        local code = [[
do
    local floor, random, remove, char = math.floor, math.random, table.remove, string.char
    local nums = {}
    for i=1,256 do nums[i]=i end
    local charmap = {}
    repeat
        local idx = random(1,#nums)
        local n = remove(nums, idx)
        charmap[n] = char(n-1)
    until #nums==0

    local state_45, state_8 = 0, 2
    local prev_values = {}

    local function get_next_pseudo_random_byte()
        if #prev_values==0 then
            state_45 = (state_45 * ]] .. tostring(pm45) .. [[ + ]] .. tostring(pa45) .. [[) % 35184372088832
            repeat state_8 = state_8 * ]] .. tostring(pm8) .. [[ % 257 until state_8~=1
            local r = state_8 % 32
            local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
            local rnd = floor(n % 1 * 2 ^ 32) + floor(n)
            local low_16 = rnd % 65536
            local high_16 = (rnd - low_16) / 65536
            local b1 = low_16 % 256
            local b2 = (low_16 - b1) / 256
            local b3 = high_16 % 256
            local b4 = (high_16 - b3) / 256
            prev_values = {b1,b2,b3,b4}
        end
        return remove(prev_values)
    end

    local realStrings = {}
    STRINGS = setmetatable({}, { __index = realStrings, __metatable = nil })

    function DECRYPT(str, seed)
        if realStrings[seed] then return seed end
        prev_values = {}
        state_45 = seed % 35184372088832
        state_8 = seed % 255 + 2
        local len = #str
        local t = {}
        local pv = ]] .. tostring(sk8) .. [[
        for i=1,len do
            pv = (string.byte(str,i) + get_next_pseudo_random_byte() + pv) % 256
            t[i] = charmap[pv+1]
        end
        realStrings[seed] = table.concat(t)
        return seed
    end
end
]]
        return code
    end

    return {
        encrypt = encrypt,
        param_mul_45 = param_mul_45,
        param_mul_8 = param_mul_8,
        param_add_45 = param_add_45,
        secret_key_8 = secret_key_8,
        genCode = genCode,
    }
end

-- Apply step (behaviour preserved)
function EncryptStrings:apply(ast, pipeline)
    local Encryptor = self:CreateEncrypionService()

    local code = Encryptor.genCode()
    local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code)
    local doStat = newAst.body.statements[1]

    local scope = ast.body.scope
    local decryptVar = scope:addVariable()
    local stringsVar = scope:addVariable()

    -- attach runtime block scope to main scope
    doStat.body.scope:setParent(ast.body.scope)

    -- rewrite references in injected runtime chunk so they point to top-scope vars
    visitast(newAst, nil, function(node, data)
        if node.kind == AstKind.FunctionDeclaration then
            if node.scope:getVariableName(node.id) == "DECRYPT" then
                data.scope:removeReferenceToHigherScope(node.scope, node.id)
                data.scope:addReferenceToHigherScope(scope, decryptVar)
                node.scope = scope
                node.id = decryptVar
            end
        end
        if node.kind == AstKind.AssignmentVariable or node.kind == AstKind.VariableExpression then
            if node.scope:getVariableName(node.id) == "STRINGS" then
                data.scope:removeReferenceToHigherScope(node.scope, node.id)
                data.scope:addReferenceToHigherScope(scope, stringsVar)
                node.scope = scope
                node.id = stringsVar
            end
        end
    end)

    -- replace string literals with STRINGS[DECRYPT(encrypted, seed)]
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.StringExpression then
            data.scope:addReferenceToHigherScope(scope, stringsVar)
            data.scope:addReferenceToHigherScope(scope, decryptVar)
            local encrypted, seed = Encryptor.encrypt(node.value)
            return Ast.IndexExpression(
                Ast.VariableExpression(scope, stringsVar),
                Ast.FunctionCallExpression(
                    Ast.VariableExpression(scope, decryptVar),
                    {
                        Ast.StringExpression(encrypted),
                        Ast.NumberExpression(seed)
                    }
                )
            )
        end
    end)

    -- insert decrypt runtime and declaration at top of program
    table.insert(ast.body.statements, 1, doStat)
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, util.shuffle{ decryptVar, stringsVar }, {}))

    return ast
end

return EncryptStrings
