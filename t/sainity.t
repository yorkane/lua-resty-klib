# https://metacpan.org/pod/Test::Nginx::Socket
use Test::Nginx::Socket::Lua 'no_plan';

log_level('info');

our $HttpConfig = <<'_EOC_';
    lua_socket_log_errors off;
    lua_package_path 'lib/?.lua;/usr/local/share/lua/5.3/?.lua;/usr/share/lua/5.1/?.lua;;';
_EOC_

run_tests();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
			local ctx = require('resty.klib.dump')
			local obj = {a=1,b=2,c=3,d={1,2,3},e={i='test', ['/sse']= '232'}}
			ctx.logs({1,2,3,4})
			ctx.logs(obj)
			ngx.print('Result:',ctx.dump_lua(obj))
			ngx.say('EndOfTest')
        }
    }
--- request
GET /t
--- error_log
{
	[1] = 1,
	[2] = 2,
	[3] = 3,
	[4] = 4
}
{
	a = 1,
	b = 2,
	c = 3,
	d = {
		[1] = 1,
		[2] = 2,
		[3] = 3
	},
	e = {
		["/sse"] = "232",
		i = "test"
	}
}
--- error_code: 200
--- response_body
Result:
{
	a = 1,
	b = 2,
	c = 3,
	d = {
		[1] = 1,
		[2] = 2,
		[3] = 3
	},
	e = {
		["/sse"] = "232",
		i = "test"
	}
}EndOfTest

