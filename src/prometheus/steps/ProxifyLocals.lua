--[[ 
    This Script is Part of the Prometheus Obfuscator by Levno_710
    
    ProxifyLocals.lua
    -----------------
    This Step wraps all locals into Proxy Objects (via metatables).
    Fixed + rewritten:
      - Removed malformed table entries/semicolons
      - Guarded against vararg function wrapping
      - Ensured safe literal insertion (no malformed/unbalanced AST)
--]]

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local visitast = require("prometheus.visitast")
local RandomLiterals = require("prometheus.randomLiterals")

local AstKind = Ast.AstKind

local ProxifyLocals = Step:extend()
ProxifyLocals.Description = "This Step wraps all locals into Proxy Objects"
ProxifyLocals.Name = "Proxify Locals"

ProxifyLocals.SettingsDescriptor = {
	LiteralType = {
		name = "LiteralType",
		description = "The type of the randomly generated literals",
		type = "enum",
		values = {
			"dictionary",
			"number",
			"string",
			"any",
		},
		default = "string",
	},
}

-- shallow copy utility
local function shallowcopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = v
        end
    else
        copy = orig
    end
    return copy
end

-- handle both function and table-based name generators
local function callNameGenerator(generatorFunction, ...)
	if type(generatorFunction) == "table" then
		generatorFunction = generatorFunction.generateName
	end
	return generatorFunction(...)
end

-- available metamethod operator mappings
local MetatableExpressions = {
    { constructor = Ast.AddExpression,    key = "__add" },
    { constructor = Ast.SubExpression,    key = "__sub" },
    { constructor = Ast.IndexExpression,  key = "__index" },
    { constructor = Ast.MulExpression,    key = "__mul" },
    { constructor = Ast.DivExpression,    key = "__div" },
    { constructor = Ast.PowExpression,    key = "__pow" },
    { constructor = Ast.StrCatExpression, key = "__concat" },
}

-- no init customisation yet
function ProxifyLocals:init(settings) end

-- choose random metaop info for a local
local function generateLocalMetatableInfo(pipeline)
    local usedOps, info = {}, {}
    for _, tag in ipairs({"setValue","getValue","index"}) do
        local op
        repeat
            op = MetatableExpressions[math.random(#MetatableExpressions)]
        until not usedOps[op]
        usedOps[op] = true
        info[tag] = op
    end

    info.valueName = callNameGenerator(pipeline.namegenerator, math.random(1, 4096))
    return info
end

-- generates wrapped assignment expression
function ProxifyLocals:CreateAssignmentExpression(info, expr, parentScope)
    local metatableVals = {}

    -- SET value metamethod
    local setScope = Scope:new(parentScope)
    local setSelf = setScope:addVariable()
    local setArg  = setScope:addVariable()
    local setFuncLiteral = Ast.FunctionLiteralExpression({
        Ast.VariableExpression(setScope, setSelf),
        Ast.VariableExpression(setScope, setArg),
    }, Ast.Block({
        Ast.AssignmentStatement({
            Ast.AssignmentIndexing(
                Ast.VariableExpression(setScope, setSelf),
                Ast.StringExpression(info.valueName)
            )
        }, {
            Ast.VariableExpression(setScope, setArg)
        })
    }, setScope))
    table.insert(metatableVals, Ast.KeyedTableEntry(Ast.StringExpression(info.setValue.key), setFuncLiteral))

    -- GET value metamethod
    local getScope = Scope:new(parentScope)
    local getSelf = getScope:addVariable()
    local getArg  = getScope:addVariable()
    local getExpr
    if (info.getValue.key == "__index" or info.setValue.key == "__index") then
        getExpr = Ast.FunctionCallExpression(
            Ast.VariableExpression(getScope:resolveGlobal("rawget")),
            { Ast.VariableExpression(getScope, getSelf), Ast.StringExpression(info.valueName) }
        )
    else
        getExpr = Ast.IndexExpression(
            Ast.VariableExpression(getScope, getSelf),
            Ast.StringExpression(info.valueName)
        )
    end
    local getFuncLiteral = Ast.FunctionLiteralExpression({
        Ast.VariableExpression(getScope, getSelf),
        Ast.VariableExpression(getScope, getArg),
    }, Ast.Block({
        Ast.ReturnStatement({ getExpr })
    }, getScope))
    table.insert(metatableVals, Ast.KeyedTableEntry(Ast.StringExpression(info.getValue.key), getFuncLiteral))

    -- return wrapped expression: setmetatable({ [name] = expr }, meta)
    parentScope:addReferenceToHigherScope(self.setMetatableVarScope, self.setMetatableVarId)
    return Ast.FunctionCallExpression(
        Ast.VariableExpression(self.setMetatableVarScope, self.setMetatableVarId),
        {
            Ast.TableConstructorExpression({
                Ast.KeyedTableEntry(Ast.StringExpression(info.valueName), expr)
            }),
            Ast.TableConstructorExpression(metatableVals)
        }
    )
end

-- main apply function
function ProxifyLocals:apply(ast, pipeline)
    local localInfos = {}

    local function getLocalInfo(scope, id)
        if scope.isGlobal then return nil end
        localInfos[scope] = localInfos[scope] or {}
        if localInfos[scope][id] then
            if localInfos[scope][id].locked then return nil end
            return localInfos[scope][id]
        end
        local info = generateLocalMetatableInfo(pipeline)
        localInfos[scope][id] = info
        return info
    end

    local function lockLocal(scope, id)
        if scope.isGlobal then return end
        localInfos[scope] = localInfos[scope] or {}
        localInfos[scope][id] = { locked = true }
    end

    -- prepare helper vars
    self.setMetatableVarScope = ast.body.scope
    self.setMetatableVarId    = ast.body.scope:addVariable()

    self.emptyFunctionScope   = ast.body.scope
    self.emptyFunctionId      = ast.body.scope:addVariable()
    self.emptyFunctionUsed    = false

    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(
        self.emptyFunctionScope, {self.emptyFunctionId}, {
            Ast.FunctionLiteralExpression({}, Ast.Block({}, Scope:new(ast.body.scope)))
        }
    ))

    visitast(ast, function(node, data)
        -- disable transformation in restricted contexts
        if node.kind == AstKind.ForStatement then
            lockLocal(node.scope, node.id)
        end
        if node.kind == AstKind.ForInStatement then
            for _, id in ipairs(node.ids) do lockLocal(node.scope, id) end
        end
        if node.kind == AstKind.FunctionDeclaration 
        or node.kind == AstKind.LocalFunctionDeclaration 
        or node.kind == AstKind.FunctionLiteralExpression then
            for _, expr in ipairs(node.args) do
                if expr.kind == AstKind.VariableExpression then
                    lockLocal(expr.scope, expr.id)
                end
            end
        end

        -- assignment rewriting
        if node.kind == AstKind.AssignmentStatement then
            if #node.lhs == 1 and node.lhs[1].kind == AstKind.AssignmentVariable then
                local variable = node.lhs[1]
                local info = getLocalInfo(variable.scope, variable.id)
                if info then
                    local args = shallowcopy(node.rhs)
                    local vexp = Ast.VariableExpression(variable.scope, variable.id)
                    vexp.__ignoreProxifyLocals = true
                    args[1] = info.setValue.constructor(vexp, args[1])
                    self.emptyFunctionUsed = true
                    data.scope:addReferenceToHigherScope(self.emptyFunctionScope, self.emptyFunctionId)
                    return Ast.FunctionCallStatement(
                        Ast.VariableExpression(self.emptyFunctionScope, self.emptyFunctionId), args
                    )
                end
            end
        end
    end, function(node)
        -- local variable declarations
        if node.kind == AstKind.LocalVariableDeclaration then
            for i, id in ipairs(node.ids) do
                local expr = node.expressions[i] or Ast.NilExpression()
                local info = getLocalInfo(node.scope, id)
                if info then
                    node.expressions[i] = self:CreateAssignmentExpression(info, expr, node.scope)
                end
            end
        end

        -- variable expressions
        if node.kind == AstKind.VariableExpression and not node.__ignoreProxifyLocals then
            local info = getLocalInfo(node.scope, node.id)
            if info then
                local literal
                if self.LiteralType == "dictionary" then
                    literal = RandomLiterals.Dictionary()
                elseif self.LiteralType == "number" then
                    literal = RandomLiterals.Number()
                elseif self.LiteralType == "string" then
                    literal = RandomLiterals.String(pipeline)
                elseif self.LiteralType == "any" then
                    literal = RandomLiterals.Any(pipeline)
                else
                    literal = Ast.NumberExpression(1) -- safe fallback
                end
                return info.getValue.constructor(node, literal)
            end
        end

        -- assignment variables become table indexing
        if node.kind == AstKind.AssignmentVariable then
            local info = getLocalInfo(node.scope, node.id)
            if info then
                return Ast.AssignmentIndexing(node, Ast.StringExpression(info.valueName))
            end
        end

        -- function declaration as local
        if node.kind == AstKind.LocalFunctionDeclaration then
            local info = getLocalInfo(node.scope, node.id)
            if info then
                -- skip functions with varargs to prevent malformed lua
                if #node.args > 0 and node.args[#node.args].kind == AstKind.VarargExpression then
                    return node
                end
                local funcLiteral = Ast.FunctionLiteralExpression(node.args, node.body)
                local newExpr = self:CreateAssignmentExpression(info, funcLiteral, node.scope)
                return Ast.LocalVariableDeclaration(node.scope, {node.id}, {newExpr})
            end
        end

        -- global function declaration
        if node.kind == AstKind.FunctionDeclaration then
            local info = getLocalInfo(node.scope, node.id)
            if info then
                table.insert(node.indices, 1, info.valueName)
            end
        end
    end)

    -- declare setmetatable alias
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(
        self.setMetatableVarScope, {self.setMetatableVarId}, {
            Ast.VariableExpression(self.setMetatableVarScope:resolveGlobal("setmetatable"))
        }
    ))
end

return ProxifyLocals