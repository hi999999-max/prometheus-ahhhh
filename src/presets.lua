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
                MaxLength = 5;                   -- default maximal chunk length
                ConcatenationType = "custom";    -- "strcat", "table" or "custom"
                CustomFunctionType = "global";   -- "global", "local" or "inline"
                CustomLocalFunctionsCount = 2;   -- number of local functions per scope if using local
            }},

            { Name = "AntiTamper"; Settings = { UseDebug = false } },
            { Name = "Vmify"; Settings = {} },
            { Name = "ConstantArray"; Settings = {
                Treshold    = 1;
                StringsOnly = true;
                Shuffle     = true;
                Rotate      = true;
                LocalWrapperTreshold = 0;
            }},
            { Name = "ProxifyLocals"; Settings = {} },
            { Name = "AddVararg"; Settings = {} },
            { Name = "NumbersToExpressions"; Settings = {} },
            { Name = "WrapInFunction"; Settings = {} },

            -- WatermarkCheck: placed last so it is less likely to be modified by previous steps.
            { Name = "WatermarkCheck"; Settings = {
                Content = "fuck black ass niggers";
                CustomVariable = "_WATERMARK";
                MakeLocal = false; -- set true to create a local variable instead
            } },
        }
    };
}
