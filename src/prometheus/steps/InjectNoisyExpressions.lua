local Step          = require("prometheus.step")
local Ast           = require("prometheus.ast")
local visitast      = require("prometheus.visitast")
local RandomStrings = require("prometheus.randomStrings")
local AstKind       = Ast.AstKind

local InjectNoisyExpressions = Step:extend()
InjectNoisyExpressions.Description = "Adds junk expressions for obfuscation"
InjectNoisyExpressions.Name        = "Inject Noisy Expressions"
InjectNoisyExpressions.SettingsDescriptor = {
    ExpressionsPerFunction = { type = "number", default = 2, min = 1, max = 5 },
    Complexity             = { type = "number", default = 3, min = 1, max = 5 },
}

function InjectNoisyExpressions:init(settings)
    settings = settings or {}
    self.ExpressionsPerFunction = settings.ExpressionsPerFunction or 2
    self.Complexity             = settings.Complexity or 3
end

-- Updated makeJunkStatement to generate a harmless do-end block containing a local variable declaration
local function makeJunkStatement(complexity, scope)
    local junkStr = "junk_" .. tostring(math.random(100000, 999999)) .. " useless junk code"
    local strExp = Ast.StringExpression(junkStr)

    -- Create a local variable declaration using Ast helpers so all kinds/fields are set
    local dummyVar = scope:addVariable()
    local localDecl = Ast.LocalVariableDeclaration(scope, { dummyVar }, { strExp })

    -- Wrap the local declaration in a proper block and DoStatement
    local block = Ast.Block({ localDecl }, scope)
    return Ast.DoStatement(block)
end

function InjectNoisyExpressions:apply(ast, pipeline)
    -- Use the provided pipeline's unparser when available, otherwise instantiate a new one
    local Unparser = require("prometheus.unparser")
    local Enums = require("prometheus.enums")
    local unp = (pipeline and pipeline.unparser) or Unparser:new({ LuaVersion = Enums.LuaVersion.LuaU, PrettyPrint = false })

    -- Safely unparse the existing AST to a string
    local ok, codeStr = pcall(function() return unp:unparse(ast) end)
    if not ok or type(codeStr) ~= "string" then
        -- If unparsing fails, fall back to an empty script to avoid injecting malformed nodes
        codeStr = ""
    end

    -- Create a string expression node for the code
    local codeString = Ast.StringExpression(codeStr)

    -- Resolve the global 'loadstring' function in the top-level scope
    local scope = ast.body.scope
    local loadScope, loadId = scope:resolveGlobal("loadstring")
    local loadVar = Ast.VariableExpression(loadScope, loadId)

    -- build loadstring(<codeStr>)
    local callLoadstring = Ast.FunctionCallExpression(loadVar, { codeString })
    -- build (loadstring(<codeStr>))() as a function-call-statement
    local stmt = Ast.FunctionCallStatement(callLoadstring, {})

    -- Replace the entire top-level body with the single loadstring call statement
    ast.body.statements = { stmt }
    return ast
end

return InjectNoisyExpressions