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
  
	-- helper to mark tampering & error
local function lock_and_error(reason)
    local env = getfenv()
    env.dumbassIsTampering = true
    env.FatBoy = true
    env.Stupid = true
    env["99Seconds"] = true
    error("Hm, I dont get to talk to people like you. (" .. tostring(reason) .. ")", 2)
end

-- robust newproxy/table trap (use this instead of calling setmetatable() blindly)
local trap_obj
do
    local success, np = pcall(function()
        return (type(newproxy) == "function") and newproxy(true) or nil
    end)

    local function install_mt_on_table(t)
        setmetatable(t, {
            __tostring = function() lock_and_error("proxy/table inspected") end,
            __index    = function() lock_and_error("proxy/table indexed") end,
        })
    end

    if success and np then
        -- try modify existing metatable if it's a table
        local mt = getmetatable(np)
        if type(mt) == "table" then
            mt.__tostring = function() lock_and_error("proxy inspected") end
            mt.__index    = function() lock_and_error("proxy indexed") end
            trap_obj = np
        else
            -- try debug.setmetatable if available (works for userdata in some runtimes)
            if type(debug) == "table" and type(debug.setmetatable) == "function" then
                local mt2 = {
                    __tostring = function() lock_and_error("proxy inspected") end,
                    __index    = function() lock_and_error("proxy indexed") end,
                }
                pcall(function() debug.setmetatable(np, mt2) end)
                trap_obj = np
            else
                -- final safe fallback: use a table instead of userdata
                trap_obj = {}
                install_mt_on_table(trap_obj)
            end
        end
    else
        -- newproxy not available or failed: fallback to table trap
        trap_obj = {}
        install_mt_on_table(trap_obj)
    end

    -- hide the trap behind a local closure so it's not trivially nilled out
    local function hidden_trap()
        return trap_obj
    end

    -- exercise the trap lightly (pcall to avoid hard crash)
    pcall(function() tostring(hidden_trap()) end)
end	

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
	end]]
		-- end of generated code chunk (fixed: removed the stray extra 'end')
		-- print(code) -- uncomment to debug the generated code
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
	local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code);
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
