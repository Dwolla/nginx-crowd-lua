-- string split utility
function split(pString, pPattern)
  local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
  local fpat = "(.-)" .. pPattern
  local last_end = 1

  local s, e, cap = pString:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
       table.insert(Table,cap)
    end

    last_end = e + 1
    s, e, cap = pString:find(fpat, last_end)
  end

  if last_end <= #pString then
    cap = pString:sub(last_end)
    table.insert(Table, cap)
  end

  return Table
end

-- grab auth header
local auth_header = ngx.req.get_headers().authorization

local prompt = "default"
if(ngx.var.cwd_authentication_realm ~= nil and ngx.var.cwd_authentication_realm =="") then
  prompt = string.gsub(ngx.var.cwd_authentication_realm, "\"", "")
end

-- check that the header is present, and if not sead authenticate header
if not auth_header or auth_header == '' or not string.match(auth_header, '^[Bb]asic ') then
  ngx.header['WWW-Authenticate'] = 'Basic realm="'..prompt..'"'
  ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local mime = require 'mime'

-- decode authenication header and verify its good
local userpass = split(mime.unb64(split(auth_header, ' ')[2])..'', ':')
if not userpass or #userpass ~= 2 then
  ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- define crowd client based off spore json definition
local crowd = require 'Spore'.new_from_string([[{
  "base_url" : "]] ..ngx.var.cwd_crowd_url..[[",
  "name" : "crowd",
  "authentication": true,
  "methods": {
    "authentication": {
       "path": "/rest/usermanagement/latest/authentication",
       "method": "POST",
       "required_payload": true,
       "required_params": ["username"],
       "expected_status": [200, 400]
    },
    "groups": {
       "path": "/rest/usermanagement/latest/user/group/nested",
       "method": "GET",
       "required_payload": false,
       "required_params": ["username"],
       "expected_status": [200]
    }
  }
}]])

-- setup crowd client
crowd:enable('Format.JSON')
crowd:enable('Auth.Basic', {
  username = ngx.var.cwd_crowd_user,
  password = ngx.var.cwd_crowd_pwd
})

-- authenticate against crowd
local resAuth = crowd:authentication({
  username = userpass[1]..'',
  payload = {
    value = userpass[2]..''
  }
})

-- error out if not successful
if resAuth.status ~= 200 then
  ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- if we've reached here, then the supplied user/pass is good, so set the
-- resulting cwd_user / cwd_email in nginx so it can be used again
ngx.var.cwd_user = resAuth.body.name..''
ngx.var.cwd_email = resAuth.body.email..'' 

local resGroups = crowd:groups({
  username = userpass[1]..''
})

if resGroups.status ~= 200 then
  ngx.exit(ngx.HTTP_FORBIDDEN)
end

if(ngx.var.cwd_requires_one_group_out_of == nil or ngx.var.cwd_requires_one_group_out_of =="") then
  ngx.exit(ngx.HTTP_FORBIDDEN)
end

local forbidden = true
for requiredGroup in (string.gsub(ngx.var.cwd_requires_one_group_out_of, " ", "") .. ","):gmatch("([^,]*)") do
     if(requiredGroup ~= "") then
          for _, group in pairs(resGroups.body.groups) do
               if(requiredGroup:lower() == group.name:lower()) then
                    ngx.var.cwd_group = group.name
                    forbidden = false
                    do return end
               end
          end
     end
end

if allowed == true then
  ngx.exit(ngx.HTTP_FORBIDDEN)
end
