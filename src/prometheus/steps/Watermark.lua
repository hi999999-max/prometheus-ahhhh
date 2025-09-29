-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- Watermark.lua
--
-- This Script provides a Step that will add a watermark to the script
-- The watermark is constructed via string.char(...) and assigned via string.gsub(...)
-- to avoid creating a single long StringExpression literal that other steps might target.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local Parser = require("prometheus.parser");
local enums = require("prometheus.enums")

local LuaVersion = enums.LuaVersion;

local Watermark = Step:extend();
Watermark.Description = "This Step will add a watermark to the script";
Watermark.Name = "Watermark";

Watermark.SettingsDescriptor = {
  Content = {
    name = "Content",
    description = "The Content of the Watermark",
    type = "string",
    default = "hello buuddyy try not to tamper pls",
  },
  CustomVariable = {
    name = "Custom Variable",
    description = "The Variable that will be used for the Watermark",
    type = "string",
    default = "_NIGGER",
  },
  -- Optional: whether to make the watermark global (assignment) or local (local var)
  MakeLocal = {
    name = "Make Local",
    description = "Create the watermark as a local variable instead of a global",
    type = "boolean",
    default = false,
  }
}

function Watermark:init(settings)
  -- no special init needed
end

-- Helper: safely create a parser for the project's Lua version (fallbacks included)
local function makeParser()
  local target = LuaVersion.Lua52;
  -- try to prefer LuaU if available in enums
  if LuaVersion.LuaU then
    target = LuaVersion.LuaU
  else
    -- use Lua52 as a reasonable default if LuaU isn't present
    target = LuaVersion.Lua52
  end
  return Parser:new({ LuaVersion = target });
end

function Watermark:apply(ast)
  local body = ast.body;
  local content = tostring(self.Content or "");
  if #content == 0 then
    return
  end

  -- Variable name and local/global preference
  local varName = tostring(self.CustomVariable or "_WATERMARK")
  local makeLocal = (self.MakeLocal == true)

  -- Direct assignment of watermark string, no obfuscation
  local decl
  if makeLocal then
    decl = string.format("local %s = %q", varName, content)
  else
    decl = string.format("%s = %q", varName, content)
  end

  -- Parse the chunk and insert its statements at the top of the AST
  local parser = makeParser()
  local ok, parsed = pcall(function() return parser:parse(decl) end)
  if not ok or not parsed or not parsed.body then
    -- Fallback: try using a simpler Lua52 parser invocation if available
    local parser2 = Parser:new({ LuaVersion = LuaVersion.Lua52 })
    parsed = parser2:parse(decl)
  end

  if parsed.body and parsed.body.scope then
    parsed.body.scope:setParent(ast.body.scope)
  end

  for i = #parsed.body.statements, 1, -1 do
    local stmt = parsed.body.statements[i]
    table.insert(ast.body.statements, 1, stmt)
  end
end

return Watermark;
