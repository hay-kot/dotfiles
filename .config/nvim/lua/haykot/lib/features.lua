-- Get an environment variable
local function get_env(name, default)
  local value = os.getenv(name)
  return value ~= nil and value or default
end

-- Feature flag check
local function is_feature_enabled(feature_name, default_value)
  local env_name = "NVIM_FEATURE_" .. string.upper(feature_name)
  local env_value = get_env(env_name, tostring(default_value))

  -- Convert string to boolean
  return env_value == "true" or env_value == "1" or env_value == "yes"
end

M = {
  env = get_env,
  enabled = is_feature_enabled,
}

return M
