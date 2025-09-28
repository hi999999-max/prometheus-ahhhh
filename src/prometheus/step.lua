-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- step.lua
--
-- This file Provides the base class for Obfuscation Steps

local logger = require("logger");
local util = require("prometheus.util");

local lookupify = util.lookupify;

local Step = {};

Step.SettingsDescriptor = {}

function Step:new(settings)
	local instance = {};
	setmetatable(instance, self);
	self.__index = self;
	
	if type(settings) ~= "table" then
		settings = {};
	end
	
	-- settings validation
	for key, data in pairs(self.SettingsDescriptor) do
		if settings[key] == nil then
			instance[key] = data.default
		elseif data.type == "enum" then
			local lookup = lookupify(data.values);
			if lookup[settings[key]] then
				instance[key] = settings[key];
			else
				logger:warn(string.format(
					"Invalid value for \"%s\" of Step \"%s\". Using default.",
					key, self.Name or "Unnamed"
				))
				instance[key] = data.default
			end
		elseif type(settings[key]) ~= data.type then
			logger:warn(string.format(
				"Wrong type for setting \"%s\" in Step \"%s\". Expected %s, using default.",
				key, self.Name or "Unnamed", data.type
			))
			instance[key] = data.default
		else
			-- within min/max boundaries if given
			local v = settings[key]
			if data.min and v < data.min then
				v = data.min
			end
			if data.max and v > data.max then
				v = data.max
			end
			instance[key] = v
		end
	end
	
	instance:init();
	return instance;
end

-- Previously: error
function Step:init()
	-- Just allow init, subclasses can override
	-- If base Step is used directly, log and continue
	if self.Name == "Abstract Step" then
		logger:info("Base Step initialised — will act as a generic transform.");
	end
end

function Step:extend()
	local ext = {};
	setmetatable(ext, self);
	self.__index = self;
	return ext;
end

-- Previously: error
function Step:apply(ast, pipeline)
	-- Now it is allowed to act.
	-- Default behaviour: identity transform (just return AST)
	if self.Name == "Abstract Step" then
		logger:info("Applying base Step — no default transformation defined, AST returned as-is.");
	end
	return ast
end

Step.Name = "Abstract Step";
Step.Description = "Abstract Step";

return Step;