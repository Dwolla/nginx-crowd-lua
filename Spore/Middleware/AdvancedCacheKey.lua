local m = {}

function m:call (req)
  if self.key then
    req.headers["x-advancedCacheKey"] = key
  end
end

return m
