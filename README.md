# lua-resty-klib

An utils-lib for openresty as common use. As auto SSL-generate, Log-info explore.
System tap and dump.
> Integrate from https://github.com/yorkane/lua-resty-dump

# usage:
#
```nginx
    location /test.lua {
      content_by_lua_block {
        local cookie = require("resty.cookie")
        local cache = require('resty.lrucache')

        ----- code list end here
        local end_list
        local say = ngx.say
        require('klib.dump').global()
        say('<pre>')
        local foo = {
         name = 'hello',
         say = function(word, bluh)
         end,
         is_bad = false,
         id = 123456,
         obj = {
          key = 'key',
          value = 119,
          is_bad = true
         },
         num_list = { 1, 2, 3, 4, 5 },
         str_list = { 'a', 'b', 'c' },
         obj_list = { { name = 1, value = 2 }, { name = 1, value = 2 }, { name = 1, value = 2 }, { name = 1, value = 2 } }
        }

        say(dump_lua(foo, 'foo'))
        say(dump_class(cache, 'lrucache'))
        dump(ngx, 'ngx')
        --- nginx log output
        dump_log(foo, 'hello')
        log('Winner Winner', 'Chicken dinner!', foo, table, ngx)
        }
    }
```
# demo result:
```lua
    foo = {
     say = function(arg1) end,			-- @./approot/test.lua @line: 25
     obj_list = {
     {
      name = 1,
      value = 2
     },
     {
      name = 1,
      value = 2
     },
     {
      name = 1,
      value = 2
     },
     {
      name = 1,
      value = 2
     }
     },
     is_bad = false,
     id = 123456,
     str_list = {"a", "b", "c"},
     obj = {
      is_bad = true,
      key = "key",
      value = 119
     },
     name = "hello",
     num_list = {1, 2, 3, 4, 5}
    }



    ---@class lrucache
    lrucache = {}

    ---@param arg string
    ---@return string @type
    function lrucache:delete(arg1) end			-- @lualib/resty/lrucache.lua @line: 171
    lrucache._VERSION = "0.07"

    ---@param arg string
    ---@return string @type
    function lrucache:set(arg1, arg2, arg3) end			-- @lualib/resty/lrucache.lua @line: 194

    ---@param arg string
    ---@return string @type
    function lrucache:new(arg1) end			-- @lualib/resty/lrucache.lua @line: 129

    ---@param arg string
    ---@return string @type
    function lrucache:get(arg1) end			-- @lualib/resty/lrucache.lua @line: 146



    ngx = {
      HTTP_PARTIAL_CONTENT = 206,
      get_now_ts = function(arg) end,			-- =[C] @line: -1
      HTTP_INSUFFICIENT_STORAGE = 507,
      HTTP_INTERNAL_SERVER_ERROR = 500,
      HTTP_METHOD_NOT_IMPLEMENTED = 501,
      time = function(arg) end,			-- =[C] @line: -1
      ERROR = -1,
      HTTP_MOVE = 256,
      HTTP_MOVED_PERMANENTLY = 301,
      print = function(arg) end,			-- =[C] @line: -1
      HTTP_REQUEST_TIMEOUT = 408,
      cookie_time = function(arg) end,			-- =[C] @line: -1
      config = {
        ngx_lua_version = 10008,
        nginx_version = 1011002,
        debug = false,
        nginx_configure = function(arg) end,				-- =[C] @line: -1
        prefix = function(arg) end,				-- =[C] @line: -1
        subsystem = "http"
      },
      get_now = function(arg) end,			-- =[C] @line: -1
      exit = function(arg) end,			-- =[C] @line: -1
      now = function(arg) end,			-- =[C] @line: -1
      crc32_long = function(arg) end,			-- =[C] @line: -1
      eof = function(arg) end,			-- =[C] @line: -1
      ...
```
