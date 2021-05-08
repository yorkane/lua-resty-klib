local new_tab = require("table.new")
local tab_clone = require("table.clone")
local nsplit = require("ngx.re").split
local ins, concat, remove, tsort, tostring = table.insert, table.concat, table.remove, table.sort, tostring
local print, say, find, nfind, match = ngx.print, ngx.say, string.find, ngx.re.find, ngx.re.match
local http = require("resty.http")
local klass = require("klib.klass")
local sbuffer = require("klib.sbuffer")
local dump, logs, dump_class, dump_lua, dump_doc, dump_dict = require("klib.dump").locally()
local _M = {}
local pointer = "\t\t" .. string.rep("-", 30)
local res_ok = pointer .. " ok\n"
local res_fail = pointer .. " fail\n"

---check_fun
---@param fun fun():void
---@param inst any@ parameters to inject into fun
---@param sb sbuffer
function _M.check_fun(fun, inst, sb)
    local has_buffer
    if not sb then
        sb = sbuffer.new()
        has_buffer = false
    end
    local fi = klass.parse_func(fun)
    sb:add("trying to invoke ", fi.lua_name, " : ")
    local ok, res = xpcall(fun, debug.traceback, inst)
    if ok then
        sb:add(res_ok)
    else
        sb:add(res_fail, dump_lua(res))
    end
    if has_buffer then
        return sb
    end
    return sb:tos()
end

---check_url
---@param text string @ single url text
---@param options table @http request options
---@param sb sbuffer
function _M.check_url(text, options, sb)
    local has_buffer
    if not sb then
        sb = sbuffer.new()
        has_buffer = false
    end
    if not text then
        if ngx.get_phase() == "timer" then
            return sb:add("no url to check", res_fail)
        end
        text = ngx.req.get_body_data()
        if not text then
            return sb:add("no url to check within post", res_fail)
        end
    end
    if not options then
        if ngx.get_phase() == "timer" then
            options = {}
        else
            options = ngx.req.get_uri_args()
        end
    end
    local list = nsplit(text, [[[\r\n]+]], "jio")
    local prefix, default_prefix = options.prefix
    local host = options.host
    local ip = options.ip or '127.0.0.1'
    local schema = options.schema or "http"
    local port = options.port or ""
    local ua = options.ua
    local method = options.method or "GET"
    local showlog = options.showlog and true
    method = string.upper(method)
    local verify = options.verify and true
    local gzip = options.gzip and true
    local req_body = options.body
    if schema == "https" or port == "443" then
        port = ""
    end
    if #port > 0 then
        port = ":" .. port
    end
    if not prefix then
        default_prefix = schema .. "://" .. (ip or "127.0.0.1") .. port
    end
    -- dump(options, default_prefix)
    -- treat options as the request header
    options["User-Agent"] = options.ua
    options["Accept-Encoding"] = options.gzip and "gzip,deflate"
    options.prefix = nil
    options.ip = nil
    options.schema = nil
    options.port = nil
    options.ua = nil
    options.verify = nil
    options.method = nil
    options.showlog = nil
    options.gzip = nil
    options.body = nil
    local httpreg = [[http[s]?://([\w\.\-\_\:]+)(/.*)]]
    for i = 1, #list do
        local url = list[i]
        if #url == 0 or string.byte(url, 1, 1) == 35 then
            -- say('ignore url:	', url)
        else
            local resp, body
            local arr = nsplit(url, [[\s+]], "jio")
            if arr[2] then
                body = arr[2]
                url = arr[1]
            end
            local char = string.byte(url, 1, 1)
            if char == 47 then
                -- start with path /xxx?xxx=xxx
                if prefix then
                    url = prefix .. mc[2]
                else
                    url = default_prefix .. mc[2]
                end
                local ok, msg = _M.check_url_parse(url, options, method, body or req_body, verify, sb)
                if ok then
                    sb:add(msg)
                else
                    sb:add(msg, "-------------------->", list[i])
                end
            else
                local mc, err = ngx.re.match(url, httpreg, "jio")
                if mc then
                    local header = tab_clone(options)
                    if prefix then
                        url = prefix .. mc[2]
                    elseif ip then
                        if not host then
                            header.host = mc[1]
                        end
                        url = default_prefix .. mc[2]
                    else
                    end
                    _M.check_url_parse(url, header, method, body or req_body, verify, sb)
                else
                    -- dump('not match',url)
                end
            end
        end
    end
    if has_buffer then
        return sb
    end
    return sb:tos()
end

function _M.check_url_parse(url, header, method, body, verify_ssl, sbuff)
    if not sbuff then
        sbuff = sbuffer()
    end
    local success = {}
    local fail = {}
    local hc = http.new()
    if not url then
        return
    end
    if body and method == "GET" then
        method = "POST"
    end
    local opt = {
        method = method,
        body = body,
        verify_ssl = verify_ssl,
        headers = header
    }
    local resp, err = hc:request_uri(url, opt)
    if body then
        body = "\t" .. body
    else
        body = ""
    end
    method = " " .. method .. " "
    local headerstr = "\t" .. ngx.re.gsub(dump_lua(header), [[[\s\[\{\}\]\"]+]], "", "jio")
    local status
    if not resp then
        return sbuff("500" .. method .. " 0\t" .. url .. headerstr .. body, res_fail)
    end
    status = resp.status or 500
    local rbody = resp.body
    if not rbody then
        return sbuff(status .. method .. " 0\t" .. url .. headerstr .. body, res_fail)
    end
    if status > 205 then
        dump(url, rbody, resp.headers)
        return sbuff(status .. method .. " " .. #rbody .. "\t" .. url .. headerstr .. rbody, res_fail)
    end
    if status == 200 then
        if #rbody == 0 then
            dump(url, header, rbody, resp.headers)
            return sbuff("200" .. method .. " 0\t" .. url .. headerstr .. body, res_fail)
        else
            return sbuff("200" .. method .. #rbody .. "\t" .. url .. headerstr .. body, res_ok)
        end
    end
    --
    return sbuff
end

---check_class
---@param class_text string @ like `lualib.klib.dump`
---@param is_dump_class boolean @ true to dump all class content into string, false to run test/main/test_* methods
---@param force_reload boolean
function _M.check_class(class_text, is_dump_class, force_reload)
    local sb = sbuffer.new()
    if class_text and type(class_text) == 'string' then
        local list = nsplit(class_text, ',+', 'jo')
        for i = 1, #list do
            if force_reload then
                package.loaded[list[i]] = nil -- hot reload lua class
            end
            local ok, klass = pcall(require, list[i])
            if ok then
                if is_dump_class then
                    sb(dump_lua(klass))
                else
                    sb(_M.check(klass))
                end
            end
        end
    end
    return sb:tos()
end

---check lua-object, urls-text are acceptable
function _M.check(...)
    local sb = sbuffer()
    local len = select("#", ...)
    local nc = 1
    for i = 1, len do
        local val = select(i, ...)
        local tp = type(val)
        if tp == "table" then
            for key, obj in pairs(val) do
                if key == "test" or key == "main" or key == "sanity" or find(key, "test_", 1, true) == 1 then
                    if type(obj) == "function" then
                        _M.check_fun(obj, val, sb)
                        --dump('-------------------',sb:tos())
                    end
                end
            end
        elseif tp == "string" and #val > 10 then
            _M.check_url(val, nil, sb)
        end
    end
    return sb:tos()
end

function _M.dump(...)
    ngx.header["content-type"] = "text/plain"
    dump(...)
end

---info get nginx environment info
---@param no_flush boolean is directly flush to nginx response
function _M.info(no_flush)
    local obj = {
        ["ngx.config.subsystem"] = ngx.config.subsystem,
        ["ngx.config.debug"] = ngx.config.debug,
        ["ngx.config.nginx_configure"] = ngx.config.nginx_configure(),
        ["ngx.config.prefix"] = ngx.config.prefix(),
        ["ngx.config.ngx_lua_version"] = ngx.config.ngx_lua_version,
        ["ngx.config.nginx_version"] = ngx.config.nginx_version,
        ["ngx.worker.pid"] = ngx.worker.pid(),
        ["ngx.worker.count"] = ngx.worker.count(),
        ["ngx.timer.running_count"] = ngx.timer.running_count(),
        ["ngx.timer.pending_count"] = ngx.timer.pending_count()
    }
    if not no_flush then
        dump(obj)
    end
    return obj
end

function _M.main()
end

return _M
