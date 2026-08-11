local path = ...
if not path:find("init") then
  binser = require(path .. ".binser")
  mlib = require(path .. ".mlib")
  -- if not web then clipper = require(path .. ".clipper") end
  ripple = require(path .. ".ripple")
  local nop = function() end
  local dummy_meta
  dummy_meta = {
    __index = function(t, k)
      return setmetatable({}, dummy_meta)
    end,
    __call = function(t, ...)
      return nil
    end
  }
  dummy_steam = setmetatable({
    init = function() return false end,
    shutdown = nop,
    runCallbacks = nop,
  }, dummy_meta)

  local ok, res = pcall(require, 'luasteam')
  if ok then
    steam = res
  else
    steam = dummy_steam
  end
end
