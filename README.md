# About #
This repository contains a simple [Atlassian Crowd](https://www.atlassian.com/software/crowd) authentication script for [nginx](http://nginx.org/), written
in [Lua](http://www.lua.org/), for use with the [access_by_lua_file](https://github.com/chaoslawful/lua-nginx-module#access_by_lua_file) directive.

This is used in production on Debian 7.2, running the latest
[dotdeb](http://www.dotdeb.org) nginx packages. An attempt was made to use as
much "off-the-shelf" packaging as possible. This script relies
on the use of [lua-Spore](http://fperrad.github.io/lua-Spore/) REST
client/library.

## Installation and Configuration ##

- Install related packages for Lua and lua-Spore dependency:

```
aptitude install lua5.1 luarocks
luarocks install luasec
luarocks install lua-spore
```

- Copy the `crowd-auth.lua` to somewhere accessible by nginx:
- Copy the `Spore/Middleware/AdvancedCache.lua` to somewhere accessible by nginx:

```
mkdir -p /etc/nginx/lua && cp crowd-auth.lua /etc/nginx/lua
```

- [Add a new application in
  Crowd](https://confluence.atlassian.com/display/CROWD/Adding+an+Application),
  and test the connectivity with the users/groups you wish to authenticate
  with.

- Modify the `crowd-auth.lua`, replacing `<CROWD_APP_URL>`, `<CROWD_APP_NAME>`,
  `<CROWD_APP_PASS>` with the Crowd base url, the application name and the
  application password created in the previous step.

- Per restricted resource make sure to set the $cwd_requires_one_group_out_of variable. cwd_requires_one_group_out_of takes either a single entry or a comma separated list of groups. In case the authenticated user is in one of the set groups he is granted access. 

- Add a `access_by_lua_file` directive in a nginx site stanza, similar to the following. The given example shows a nginx configuration deployed via cloud foundry with static [build pack](https://github.com/MichaelStephan/staticfile-buildpack):

```
worker_processes 5;
daemon off;

error_log <%= ENV["APP_ROOT"] %>/nginx/logs/error.log;
events { worker_connections 1024; }

http {
  log_format cloudfoundry '$http_x_forwarded_for - $http_referer - [$time_local] "$request" $status $body_bytes_sent $request_time';
  access_log <%= ENV["APP_ROOT"] %>/nginx/logs/access.log cloudfoundry;
  lua_package_path '<%= ENV["APP_ROOT"] %>/nginx-crowd-lua/?.lua;;';
  default_type application/octet-stream;
  include mime.types;
  sendfile on;
  gzip on;
  tcp_nopush on;
  keepalive_timeout 30;

  proxy_cache_path <%= ENV["APP_ROOT"] %>/cache keys_zone=one:10m;

  server { 
    server_name 'testnewbuildpack.dev.cf.hybris.com'; # modify your server name to fit your needs
    listen <%= ENV["PORT"] %>;
    root <%= ENV["APP_ROOT"] %>/public;
    set $cwd_crowd_url 'http://127.0.0.1:<%= ENV["PORT"] %>'; # route all requests to crowd through the nginx cache
    set $cwd_crowd_user '<%= ENV["CROWD_USER"] %>';
    set $cwd_crowd_pwd '<%= ENV["CROWD_PWD"] %>';

    # routes all crowd requests to crowd 
    location /rest/usermanagement/latest/ {
      satisfy any;
      allow 127.0.0.1; # only allow access for requests coming from localhost 
      deny all;  
      proxy_pass <%= ENV["CROWD_URL"] %>;
      proxy_cache_key $http_advancedCacheKey$host$uri#is_args$args;
      proxy_cache one;
      proxy_cache_valid 200 5m; # cache any crowd related requests for users who were authenticated 
      proxy_cache_methods GET POST;
      proxy_ignore_headers Cache-Control Expires;
      proxy_ignore_headers Set-Cookie;
      proxy_hide_header Set-Cookie;
    }

    location / {
      # redirect all traffic to https
      if ($http_x_forwarded_proto != "https") {
        return 301 https://$host$request_uri;
      }
      
      index index.html index.htm Default.htm;
    }

    location /protected/ {
      # redirect all traffic to https
      if ($http_x_forwarded_proto != "https") {
        return 301 https://$host$request_uri;
      }
      
      index index.html index.htm Default.htm;
      set $cwd_authentication_realm '<%= ENV["AUTH_REALM"] %>';
      set $cwd_requires_one_group_out_of 'hybris'; # single group name or comma separated list of group names. An authenticated user needs to be in one of the given groups only for successful authentication 
      set $cwd_user 'unknown';
      set $cwd_group 'unknown';
      set $cwd_email 'unknown@unknown.com';
      access_by_lua_file <%= ENV["APP_ROOT"] %>/nginx-crowd-lua/crowd-auth.lua;
    }
  }
}
```

## Authenticating against Atlassian JIRA or other REST-enabled App ##
While untried, modifying this script for use authenticating against
[Atlassian JIRA](https://www.atlassian.com/software/jira) (or other app) should be fairly
straight forward, as JIRA's REST API is very similar (if not identical) to
Crowd's. Should you do that, please email me and/or provide a pull request and
I will gladly integrate the changes within this repository.

Similarly, should you find this useful in negotiating authentication against
any other apps, please let me know via email, and/or provide a pull request, so
that fellow devops teams do not need to continously reinvent the wheel ;).
