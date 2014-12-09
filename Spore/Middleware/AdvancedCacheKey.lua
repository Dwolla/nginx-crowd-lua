_ENV = nil
local m = {}

function m:call (req)
  if self.key then
    req.headers["x-advancedCacheKey"] = self.key
  end
end

return m
