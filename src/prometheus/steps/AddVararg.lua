-- Optimised AddVararg.lua
-- Part of the Prometheus Obfuscator by Levno_710
-- Adds vararg to all functions (if not present)

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")

local AstKind = Ast.AstKind
local K_FN       = AstKind.FunctionDeclaration
local K_LFN      = AstKind.LocalFunctionDeclaration
local K_FLIT     = AstKind.FunctionLiteralExpression
local NewVararg  = Ast.VarargExpression

local AddVararg = Step:extend()
AddVararg.Description = "This Step Adds Vararg to all Functions"
AddVararg.Name = "Add Vararg"
AddVararg.SettingsDescriptor = {}

function AddVararg:init(settings)
    -- no-op; kept for API compatibility
end

function AddVararg:apply(ast)
    -- cache local references to avoid global table lookups inside the visitor
    local kfn, lkfn, flit = K_FN, K_LFN, K_FLIT
    local newVararg = NewVararg

    visitast(ast, nil, function(node)
        local kind = node.kind
        if kind == kfn or kind == lkfn or kind == flit then
            -- ensure args table exists
            local args = node.args
            if not args then
                args = {}
                node.args = args
            end

            -- only inspect last element once
            local n = #args
            if n == 0 or (args[n].kind ~= AstKind.VarargExpression) then
                args[n + 1] = newVararg()
            end
        end
    end)
end

return AddVararg
