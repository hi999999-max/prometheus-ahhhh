-- InjectIntegrityChecks.lua
-- Part of the Prometheus Obfuscator 
-- Inserts simple placeholder comments into each function

local Step     = require("prometheus.step")
local Ast      = require("prometheus.ast")
local visitast = require("prometheus.visitast")
local AstKind  = Ast.AstKind

local InjectIntegrityChecks = Step:extend()
InjectIntegrityChecks.Description = "Adds dummy statements to functions"
InjectIntegrityChecks.Name        = "Inject Integrity Checks"
InjectIntegrityChecks.SettingsDescriptor = {}

function InjectIntegrityChecks:init(settings)
    -- no settings needed
end

function InjectIntegrityChecks:apply(ast)
    -- Find a variable declaration from elsewhere to copy structure from
    local template = nil
    
    -- First, hunt for a simple variable declaration in the existing AST to use as template
    visitast(ast, nil, function(node, data)
        if template == nil and node.kind == AstKind.LocalVariableDeclaration 
        and node.identifiers and #node.identifiers > 0
        and node.values and #node.values > 0 then
            template = node
        end
    end)
    
    if template == nil then
        -- Failed to find a template, don't crash the pipeline
        return ast
    end
    
    -- Now insert our own declarations based on the template structure
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.FunctionDeclaration
        or node.kind == AstKind.LocalFunctionDeclaration
        or node.kind == AstKind.FunctionLiteralExpression then
            if node.body and node.body.statements then
                -- Crafting a declaration like: local _check = 1
                local simple = {
                    kind = AstKind.LocalVariableDeclaration,
                    identifiers = {
                        { kind = AstKind.Identifier, name = "_check" .. tostring(math.random(1000, 9999)) }
                    },
                    values = {
                        Ast.NumberExpression(math.random(1, 1000))
                    }
                }
                
                -- Insert at beginning of function
                table.insert(node.body.statements, 1, simple)
            end
        end
    end)
    
    return ast
end

return InjectIntegrityChecks