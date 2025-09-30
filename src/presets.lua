return {
    ["Medium"] = {
        -- Targeting Roblox LuaU
        LuaVersion = "LuaU";
        -- No VarNamePrefix for minified output
        VarNamePrefix = "";
        -- Name Generator for Variables
        NameGenerator = "MangledShuffled";
        -- No pretty printing
        PrettyPrint = false;
        -- Seed (0 uses current time)
        Seed = 0;

        -- Obfuscation steps
        Steps = {
            -- Encrypt strings first so splits happen on original strings
            { Name = "EncryptStrings"; Settings = {} },

            -- Optional: split strings (before or after encrypt depending on desired effect).
            { Name = "SplitStrings"; Settings = {
                Treshold = 1;                    -- default: 1 (apply to all string nodes relatively)
                MinLength = 5;                   -- default minimal chunk length
                MaxLength = 50;                   -- default maximal chunk length
                ConcatenationType = "custom";    -- "strcat", "table" or "custom"
                CustomFunctionType = "global";   -- "global", "local" or "inline"
                CustomLocalFunctionsCount = 2;   -- number of local functions per scope if using local
            }},

            -- Tamper-protection layer
            { Name = "AntiTamper"; Settings = { UseDebug = false } },

            { Name = "Vmify"; Settings = {} },

            -- ConstantArray restored
            { Name = "ConstantArray"; Settings = {
                Treshold    = 1;
                StringsOnly = true;
                Shuffle     = true;
                Rotate      = true;
                LocalWrapperTreshold = 0;
            }},

            { Name = "AddVararg"; Settings = {} },
            { Name = "NumbersToExpressions"; Settings = {} },
            { Name = "WrapInFunction"; Settings = {} },
            { Name = "InjectIntegrityChecks"; Settings = {} },
        }
    };
}