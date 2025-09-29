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

local function generateExpr(depth)
    if depth <= 1 then
        return Ast.NumberExpression(math.random(1, 999))
    end
    -- Use a descriptive variable name for operators
    local operators = { "AddExpression", "SubExpression", "MulExpression", "DivExpression", "ModExpression", "PowExpression" }
    local opName = operators[math.random(#operators)]
    -- Ensure clarity in recursive calls with proper spacing
    return Ast[opName](generateExpr(depth - 1), generateExpr(depth - 1))
end

local function makeJunkStatement(complexity, scope)
    local expr = generateExpr(complexity)
    local var  = scope and scope.addVariable and scope:addVariable() or "_junk" .. tostring(math.random(1000, 9999))
    return {
        kind        = AstKind.LocalVariableDeclaration,
        ids         = { var },          -- compiler expects `ids`
        expressions = { expr },         -- correct field name for values
        scope       = scope             -- attach scope
    }
end

function InjectNoisyExpressions:apply(ast)
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.FunctionDeclaration
        or node.kind == AstKind.LocalFunctionDeclaration
        or node.kind == AstKind.FunctionLiteralExpression then
            if node.body then
                if type(node.body.statements) ~= 'table' then
                    node.body.statements = {}
                end
                for i = 1, self.ExpressionsPerFunction do
                    -- Determine the injection scope with clear fallback logic
                    local injectionScope = node.body.scope or data.scope or ast.body.scope
                    local junk = makeJunkStatement(self.Complexity, injectionScope)
                    local pos  = math.random(1, #node.body.statements + 1)
                    table.insert(node.body.statements, pos, junk)
                end
            end
        end
    end)
    return ast
end

return InjectNoisyExpressions