-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- EncryptStrings.lua
--
-- This Script provides a Simple Obfuscation Step that encrypts strings

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")
local AstKind = Ast.AstKind;

local EncryptStrings = Step:extend()
EncryptStrings.Description = "This Step will encrypt strings within your Program."
EncryptStrings.Name = "Encrypt Strings"

EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings) end


function EncryptStrings:CreateEncrypionService()
	local usedSeeds = {};

	local secret_key_6 = math.random(0, 63) -- 6-bit  arbitrary integer (0..63)
	local secret_key_7 = math.random(0, 127) -- 7-bit  arbitrary integer (0..127)
	local secret_key_44 = math.random(0, 17592186044415) -- 44-bit arbitrary integer (0..17592186044415)
	local secret_key_8 = math.random(0, 255); -- 8-bit  arbitrary integer (0..255)

	local floor = math.floor

	local function primitive_root_257(idx)
		local g, m, d = 1, 128, 2 * idx + 1
		repeat
			g, m, d = g * g * (d >= m and 3 or 1) % 257, m / 2, d % m
		until m < 1
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
		prev_values = {}
	end

	local function gen_seed()
		local seed;
		repeat
			seed = math.random(0, 35184372088832);
		until not usedSeeds[seed];
		usedSeeds[seed] = true;
		return seed;
	end

	local function get_random_32()
		state_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832
		repeat
			state_8 = state_8 * param_mul_8 % 257
		until state_8 ~= 1
		local r = state_8 % 32
		local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
		return floor(n % 1 * 2 ^ 32) + floor(n)
	end

	local function get_next_pseudo_random_byte()
		if #prev_values == 0 then
			local rnd = get_random_32() -- value 0..4294967295
			local low_16 = rnd % 65536
			local high_16 = (rnd - low_16) / 65536
			local b1 = low_16 % 256
			local b2 = (low_16 - b1) / 256
			local b3 = high_16 % 256
			local b4 = (high_16 - b3) / 256
			prev_values = { b1, b2, b3, b4 }
		end
		--print(unpack(prev_values))
		return table.remove(prev_values)
	end

	local function encrypt(str)
		local seed = gen_seed();
		set_seed(seed)
		local len = string.len(str)
		local out = {}
		local prevVal = secret_key_8;
		for i = 1, len do
			local byte = string.byte(str, i);
			out[i] = string.char((byte - (get_next_pseudo_random_byte() + prevVal)) % 256);
			prevVal = byte;
		end
		return table.concat(out), seed;
	end

        local function genCode()
        local code = [[
do
	local floor = math.floor
	local random = math.random;
	local remove = table.remove;
	local char = string.char;
	local state_45 = 0
	local state_8 = 2
	local digits = {}
	local charmap = {};
	local i = 0;

	local nums = {};
	for i = 1, 256 do
		nums[i] = i;
	end

	repeat
		local idx = random(1, #nums);
		local n = remove(nums, idx);
		charmap[n] = char(n - 1);
	until #nums == 0;

	local prev_values = {}
	local function get_next_pseudo_random_byte()
		if #prev_values == 0 then
			state_45 = (state_45 * ]] .. tostring(param_mul_45) .. [[ + ]] .. tostring(param_add_45) .. [[) % 35184372088832
			repeat
				state_8 = state_8 * ]] .. tostring(param_mul_8) .. [[ % 257
			until state_8 ~= 1
			local r = state_8 % 32
			local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
			local rnd = floor(n % 1 * 2 ^ 32) + floor(n)
			local low_16 = rnd % 65536
			local high_16 = (rnd - low_16) / 65536
			local b1 = low_16 % 256
			local b2 = (low_16 - b1) / 256
			local b3 = high_16 % 256
			local b4 = (high_16 - b3) / 256
			prev_values = { b1, b2, b3, b4 }
		end
		return table.remove(prev_values)
	end

	local realStrings = {};
	STRINGS = setmetatable({}, {
		__index = realStrings;
		__metatable = nil;
	});
  	function DECRYPT(str, seed)
		local realStringsLocal = realStrings;
		if(realStringsLocal[seed]) then else
			prev_values = {};
			local chars = charmap;
			state_45 = seed % 35184372088832
			state_8 = seed % 255 + 2
			local len = string.len(str);
			realStringsLocal[seed] = "";
			local prevVal = ]] .. tostring(secret_key_8) .. [[;
			for i=1, len do
				prevVal = (string.byte(str, i) + get_next_pseudo_random_byte() + prevVal) % 256
				realStringsLocal[seed] = realStringsLocal[seed] .. chars[prevVal + 1];
			end
		end
		return seed;
	end
end

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
        return code;
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

function EncryptStrings:apply(ast, pipeline)
    local Encryptor = self:CreateEncrypionService();

	local code = Encryptor.genCode();
	local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.LuaU }):parse(code);
	local doStat = newAst.body.statements[1];

	local scope = ast.body.scope;
	local decryptVar = scope:addVariable();
	local stringsVar = scope:addVariable();
	
	doStat.body.scope:setParent(ast.body.scope);

	visitast(newAst, nil, function(node, data)
		if(node.kind == AstKind.FunctionDeclaration) then
			if(node.scope:getVariableName(node.id) == "DECRYPT") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id);
				data.scope:addReferenceToHigherScope(scope, decryptVar);
				node.scope = scope;
				node.id    = decryptVar;
			end
		end
		if(node.kind == AstKind.AssignmentVariable or node.kind == AstKind.VariableExpression) then
			if(node.scope:getVariableName(node.id) == "STRINGS") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id);
				data.scope:addReferenceToHigherScope(scope, stringsVar);
				node.scope = scope;
				node.id    = stringsVar;
			end
		end
	end)

	visitast(ast, nil, function(node, data)
		if(node.kind == AstKind.StringExpression) then
			data.scope:addReferenceToHigherScope(scope, stringsVar);
			data.scope:addReferenceToHigherScope(scope, decryptVar);
			local encrypted, seed = Encryptor.encrypt(node.value);
			return Ast.IndexExpression(Ast.VariableExpression(scope, stringsVar), Ast.FunctionCallExpression(Ast.VariableExpression(scope, decryptVar), {
				Ast.StringExpression(encrypted), Ast.NumberExpression(seed),
			}));
		end
	end)


	-- Insert to Main Ast
	table.insert(ast.body.statements, 1, doStat);
	table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, util.shuffle{ decryptVar, stringsVar }, {}));
	return ast
end

return EncryptStrings