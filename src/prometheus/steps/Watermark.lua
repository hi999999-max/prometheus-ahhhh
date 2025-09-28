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

  -- Build byte list for the watermark content
  local bytes = {}
  for i = 1, #content do
    table.insert(bytes, tostring(string.byte(content, i)))
  end
  local bytesConcat = table.concat(bytes, ",")

  -- Variable name and local/global preference
  local varName = tostring(self.CustomVariable or "_WATERMARK")
  local makeLocal = (self.MakeLocal == true)

  -- Construct the Lua source that will create and assign the watermark via string.gsub
  -- Example when global: string.gsub(string.char(65,66,67), ".+", function(s) _WATERMARK = s end)
  -- Example when local: local _WATERMARK; string.gsub(string.char(...), ".+", function(s) _WATERMARK = s end)
  local decl
  if makeLocal then
    decl = "local " .. varName .. ";\n"
  else
    -- ensure variable exists (nil) so later steps that check references can see it as early assignment
    decl = varName .. " = nil\n"
  end

  -- Build the gsub assignment line
  -- note: the pattern ".+" is a small string literal which is unavoidable for gsub pattern matching
  local gsubLine = string.format('string.gsub(string.char(%s), ".+", function(s) %s = s end)', bytesConcat, varName)

  local src = decl .. gsubLine

  -- Parse the chunk and insert its statements at the top of the AST
  local parser = makeParser()
  local ok, parsed = pcall(function() return parser:parse(src) end)
  if not ok or not parsed or not parsed.body then
    -- Fallback: try using a simpler Lua52 parser invocation if available
    local parser2 = Parser:new({ LuaVersion = LuaVersion.Lua52 })
    parsed = parser2:parse(src)
  end

  -- Ensure scopes of parsed chunk integrate with the file scope.
  -- If parser created fresh scopes, set their parent to the file body scope so references behave.
  if parsed.body and parsed.body.scope then
    parsed.body.scope:setParent(ast.body.scope)
  end

  -- Insert parsed statements at the top (reverse order to keep original sequence)
  for i = #parsed.body.statements, 1, -1 do
    local stmt = parsed.body.statements[i]
    table.insert(ast.body.statements, 1, stmt)
  end
end

return Watermark;
