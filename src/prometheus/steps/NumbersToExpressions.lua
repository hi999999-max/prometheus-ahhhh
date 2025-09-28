-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- NumbersToExpressions.lua
--
-- Converts Number Literals to Expressions safely
unpack = unpack or table.unpack

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind

local NumbersToExpressions = Step:extend()
NumbersToExpressions.Description = "This Step Converts number Literals to Expressions"
NumbersToExpressions.Name = "Numbers To Expressions"

NumbersToExpressions.SettingsDescriptor = {
    Treshold = {
        type = "number",
        default = 1,
        min = 0,
        max = 1,
    },
    InternalTreshold = {
        type = "number",
        default = 0.2,
        min = 0,
        max = 0.8,
    }
}

function NumbersToExpressions:init(settings)
    self.ExpressionGenerators = {
        function(val, depth) -- Addition
            local val2 = math.random(-2^20, 2^20)
            if val2 == nil then return false end
            local diff = val - val2
            if diff == nil then return false end
            -- prevent floating-point issues
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
                return false
            end
            return Ast.AddExpression(
                self:CreateNumberExpression(val2, depth),
                self:CreateNumberExpression(diff, depth),
                false
            )
        end,

        function(val, depth) -- Subtraction
            local val2 = math.random(-2^20, 2^20)
            if val2 == nil then return false end
            local diff = val + val2
            if diff == nil then return false end
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
                return false
            end
            return Ast.SubExpression(
                self:CreateNumberExpression(diff, depth),
                self:CreateNumberExpression(val2, depth),
                false
            )
        end
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    -- Stop deep recursion or if randomness threshold triggers
    if depth > 15 or (depth > 0 and math.random() >= self.InternalTreshold) then
        return Ast.NumberExpression(val)
    end

    local generators = util.shuffle({unpack(self.ExpressionGenerators)})
    for _, generator in ipairs(generators) do
        local ok, node = pcall(generator, self, val, depth + 1)
        if ok and node then
            return node
        end
    end

    -- fallback if no generator worked
    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
    visitast(ast, nil, function(node)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                return self:CreateNumberExpression(node.value, 0)
            end
        end
    end)
end

return NumbersToExpressions
