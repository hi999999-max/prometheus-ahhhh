-- Part of the Prometheus Obfuscator by Levno_710
-- Provides enums used by the Obfuscator with modern enum-like patterns.

local chararray = require("prometheus.util").chararray

-- Little helper to build "enum-like" immutable tables
local function Enum(name, values)
    local enum = {}
    for _, v in ipairs(values) do
        enum[v] = v
    end
    return setmetatable(enum, {
        __name = name,
        __index = function(_, key)
            error(("Invalid %s enum key: %s"):format(name, tostring(key)), 2)
        end,
        __newindex = function()
            error(("Attempt to modify read-only enum %s"):format(name), 2)
        end,
        __pairs = function(tbl)
            return function(_, k)
                local nextk, nextv = next(values, k)
                return nextk, nextv
            end, values, nil
        end,
    })
end

local Enums = {}

-- Add Lua52 and Lua53 here
Enums.LuaVersion = Enum("LuaVersion", { "LuaU", "Lua51", "Lua52", "Lua53" })

Enums.Conventions = {
    [Enums.LuaVersion.Lua51] = {
        Keywords = {
            "and", "break", "do", "else", "elseif",
            "end", "false", "for", "function", "if",
            "in", "local", "nil", "not", "or",
            "repeat", "return", "then", "true", "until", "while"
        },
        SymbolChars = chararray("+-*/%^#=~<>(){}[];:,."),
        MaxSymbolLength = 3,
        Symbols = {
            "+", "-", "*", "/", "%", "^", "#",
            "==", "~=", "<=", ">=", "<", ">", "=",
            "(", ")", "{", "}", "[", "]",
            ";", ":", ",", ".", "..", "...",
        },
        IdentChars = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"),
        NumberChars = chararray("0123456789"),
        HexNumberChars = chararray("0123456789abcdefABCDEF"),
        BinaryNumberChars = { "0", "1" },
        DecimalExponent = { "e", "E" },
        HexadecimalNums = { "x", "X" },
        BinaryNums = { "b", "B" },
        DecimalSeperators = false,
        EscapeSequences = {
            ["a"] = "\a"; ["b"] = "\b"; ["f"] = "\f"; ["n"] = "\n";
            ["r"] = "\r"; ["t"] = "\t"; ["v"] = "\v";
            ["\\"] = "\\"; ["\""] = "\""; ["\'"] = "\'";
        },
        NumericalEscapes = true,
        EscapeZIgnoreNextWhitespace = true,
        HexEscapes = true,
        UnicodeEscapes = true,
    },

    -- Lua52 conventions (copied from Lua51 for now, can be tweaked)
    [Enums.LuaVersion.Lua52] = {
        Keywords = {
            "and", "break", "do", "else", "elseif",
            "end", "false", "for", "function", "if",
            "in", "local", "nil", "not", "or",
            "repeat", "return", "then", "true", "until", "while", "goto"
        },
        SymbolChars = chararray("+-*/%^#=~<>(){}[];:,."),
        MaxSymbolLength = 3,
        Symbols = {
            "+", "-", "*", "/", "%", "^", "#",
            "==", "~=", "<=", ">=", "<", ">", "=",
            "(", ")", "{", "}", "[", "]",
            ";", ":", ",", ".", "..", "...",
        },
        IdentChars = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"),
        NumberChars = chararray("0123456789"),
        HexNumberChars = chararray("0123456789abcdefABCDEF"),
        BinaryNumberChars = { "0", "1" },
        DecimalExponent = { "e", "E" },
        HexadecimalNums = { "x", "X" },
        BinaryNums = { "b", "B" },
        DecimalSeperators = false,
        EscapeSequences = {
            ["a"] = "\a"; ["b"] = "\b"; ["f"] = "\f"; ["n"] = "\n";
            ["r"] = "\r"; ["t"] = "\t"; ["v"] = "\v";
            ["\\"] = "\\"; ["\""] = "\""; ["\'"] = "\'";
        },
        NumericalEscapes = true,
        EscapeZIgnoreNextWhitespace = true,
        HexEscapes = true,
        UnicodeEscapes = true,
    },

    -- Lua53 conventions (copied from Lua52, with bitwise operators added)
    [Enums.LuaVersion.Lua53] = {
        Keywords = {
            "and", "break", "do", "else", "elseif",
            "end", "false", "for", "function", "if",
            "in", "local", "nil", "not", "or",
            "repeat", "return", "then", "true", "until", "while", "goto"
        },
        SymbolChars = chararray("+-*/%^#=~<>(){}[];:,.&|~"),
        MaxSymbolLength = 3,
        Symbols = {
            "+", "-", "*", "/", "%", "^", "#",
            "==", "~=", "<=", ">=", "<", ">", "=",
            "&", "|", "~", "<<", ">>", "//",
            "(", ")", "{", "}", "[", "]",
            ";", ":", ",", ".", "..", "...",
        },
        IdentChars = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"),
        NumberChars = chararray("0123456789"),
        HexNumberChars = chararray("0123456789abcdefABCDEF"),
        BinaryNumberChars = { "0", "1" },
        DecimalExponent = { "e", "E" },
        HexadecimalNums = { "x", "X" },
        BinaryNums = { "b", "B" },
        DecimalSeperators = false,
        EscapeSequences = {
            ["a"] = "\a"; ["b"] = "\b"; ["f"] = "\f"; ["n"] = "\n";
            ["r"] = "\r"; ["t"] = "\t"; ["v"] = "\v";
            ["\\"] = "\\"; ["\""] = "\""; ["\'"] = "\'";
        },
        NumericalEscapes = true,
        EscapeZIgnoreNextWhitespace = true,
        HexEscapes = true,
        UnicodeEscapes = true,
    },

    [Enums.LuaVersion.LuaU] = {
        Keywords = {
            "and", "break", "do", "else", "elseif", "continue",
            "end", "false", "for", "function", "if",
            "in", "local", "nil", "not", "or",
            "repeat", "return", "then", "true", "until", "while"
        },
        SymbolChars = chararray("+-*/%^#=~<>(){}[];:,."),
        MaxSymbolLength = 3,
        Symbols = {
            "+", "-", "*", "/", "%", "^", "#",
            "==", "~=", "<=", ">=", "<", ">", "=",
            "+=", "-=", "/=", "%=", "^=", "..=", "*=",
            "(", ")", "{", "}", "[", "]",
            ";", ":", ",", ".", "..", "...",
            "::", "->", "?", "|", "&",
        },
        IdentChars = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"),
        NumberChars = chararray("0123456789"),
        HexNumberChars = chararray("0123456789abcdefABCDEF"),
        BinaryNumberChars = { "0", "1" },
        DecimalExponent = { "e", "E" },
        HexadecimalNums = { "x", "X" },
        BinaryNums = { "b", "B" },
        DecimalSeperators = { "_" },
        EscapeSequences = {
            ["a"] = "\a"; ["b"] = "\b"; ["f"] = "\f"; ["n"] = "\n";
            ["r"] = "\r"; ["t"] = "\t"; ["v"] = "\v";
            ["\\"] = "\\"; ["\""] = "\""; ["\'"] = "\'";
        },
        NumericalEscapes = true,
        EscapeZIgnoreNextWhitespace = true,
        HexEscapes = true,
        UnicodeEscapes = true,
    },
}

return Enums
