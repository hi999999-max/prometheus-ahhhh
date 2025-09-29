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
    
    -- Replace error call with a default template if none is found
    if template == nil then
        -- Could not find a variable declaration template, using default dummy template
        template = {
            kind = AstKind.LocalVariableDeclaration,
            identifiers = { { kind = AstKind.Identifier, name = "_dummy" } },
            values = { Ast.NumberExpression(0) }
        }
    end
    
    -- Now insert our own declarations based on the template structure
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.FunctionDeclaration
        or node.kind == AstKind.LocalFunctionDeclaration
        or node.kind == AstKind.FunctionLiteralExpression then
            if node.body then
                if type(node.body.statements) ~= 'table' then
                    node.body.statements = {}
                end
                -- Use the function's scope for variable declaration
                local scope = node.body.scope or data.scope or ast.body.scope
                local varId = scope and scope.addVariable and scope:addVariable() or "_check" .. tostring(math.random(1000, 9999))
                -- Deep copy function for the template
                local function deepCopy(t)
                    local copy = {}
                    for k, v in pairs(t) do
                        if type(v) == 'table' then
                            copy[k] = deepCopy(v)
                        else
                            copy[k] = v
                        end
                    end
                    return copy
                end
                -- Crafting a new declaration based on a deep copy of the template
                local simple = deepCopy(template)
                -- Use correct field names for AST compatibility
                simple.identifiers = nil
                simple.ids = { varId }
                simple.values = nil
                simple.expressions = { Ast.NumberExpression(math.random(1, 1000)) }
                simple.scope = scope
                -- Insert at beginning of function
                table.insert(node.body.statements, 1, simple)
            end
        end
    end)
    
    return ast
end

return InjectIntegrityChecks