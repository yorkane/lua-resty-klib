local aes = require "resty.aes"
local dump = require('klib.dump')
local re_split = require "ngx.re".split
local ins, tonumber, fmod, tostring = table.insert, tonumber, math.fmod, tostring
local nvar, concat, nctx, nreq, nphase, hash = ngx.var, table.concat, ngx.ctx, ngx.req, ngx.get_phase, table.hash
local now, update_time, time = ngx.now, ngx.update_time, ngx.time
local nfind, nsub = ngx.re.find, ngx.re.gsub
local nmatch, gmatch, byte, char = ngx.re.match, ngx.re.gmatch, string.byte, string.char
local find, sub, lower, rep = string.find, string.sub, string.lower, string.rep
local random, randomseed, floor = math.random, math.randomseed, math.floor
local wid = ngx.worker.id() or 0

local _M = {
}

local function array(count)
	return table.new(0, count)
end
local _random_seed_nc = 1
function _M.random(startInt, endInt)
	local seed = floor((time() - ngx.req.start_time() + _random_seed_nc) * 10000) + wid
	randomseed(seed)
	_random_seed_nc = _random_seed_nc + 1
	return random(startInt, endInt)
end

---random_str
---@param count number @random chars count
---@return string @ random_text
function _M.random_text(count, seed, is_word, is_binary)
	seed = seed or 1
	local seed1 = ((now() - 1595731316) * 1000) + wid + (count * 1000)
	randomseed(seed + seed1)
	local tb = array(count)
	for i = 1, count do
		if is_binary then
			tb[i] = char(random(0, 255))
		elseif is_word then
			local nc = 0
			local cr = random(65, 122)
			while cr > 90 and cr < 97 do
				nc = nc + 1
				randomseed(cr + nc)
				cr = random(65, 122)
			end
			tb[i] = char(cr)
		else
			tb[i] = char(random(33, 126))
		end
	end
	return concat(tb, '')
end

---benchmark
---@param func fun(number_range:number)
---@param duration number @ the minimum execution milliseconds duration, the bigger the more accurate, but cost more time to complete benchmark
---@param no_dump boolean @ don't output the result by dump directly
---@return benchmark_result
---Demo: dump(_M.benchmark(string.find, str, 'insert', 1, true), 'sfind')
function _M.benchmark(func, count, duration, no_dump)
	count = count or 20000
	local nc, log, next_count, res = 0, {}, count
	update_time()
	local start_time = now()
	local tms = 1
	local t1 = now()
	for i = 1, count do
		func(i)
	end
	local tnc = 1
	update_time()
	tms = floor((now() - t1) * 1000 + 0.5)
	local first_run_mark = count / tms
	log[1] = count .. ' times in ' .. tms .. ' ms'
	if not duration or duration < 200 then
		duration = 200
	end
	while (tms < duration and nc < 10) do
		next_count = floor(next_count * (duration / tms) + 0.5)
		if tostring(next_count) == 'inf' then
			count = count * 20
			next_count = count
		else
			count = next_count
		end
		update_time()
		t1 = now()
		for i = 1, count do
			func(tnc)
			tnc = tnc + 1
		end
		update_time()
		tms = floor((now() - t1) * 1000 + 0.5)
		ins(log, count .. ' times in ' .. tms .. ' ms')
		--ngx.say(tms, '|', count)
		nc = nc + 1
	end
	res = floor(count / tms)
	update_time()
	local info = debug.getinfo(func)
	local _info
	local defined
	if info then
		local file_path = sub(info.source, 2, #info.source)
		defined = ' --' .. file_path .. ' @' .. info.linedefined + 2
		if #file_path > 20 then
			local cnt = _M.read_file(file_path)
			if cnt then
				local arr = re_split(cnt, [[[\r]?\n]])
				local txt = ''
				for i = info.linedefined + 1, info.lastlinedefined + 2 do
					if find(arr[i], '--', 1, true) then
					else
						txt = txt .. arr[i]
					end
				end
				local mc = nmatch(txt, [[\w+[\.\:]?\w*\([^\)]+\)]])
				if mc then
					_info = mc[0]
				end
			end
		end
		info.source = nil
		info.linedefined = nil
		info.currentline = nil
		info.isvararg = nil
		info.lastlinedefined = nil
		info.namewhat = nil
		info.short_src = nil
		info.nups = nil
		info.nparams = nil
	end
	defined = defined or ''
	defined = defined .. string.dump(func, true)
	
	---@class benchmark_result
	local res = {
		first_run_mark = first_run_mark,
		mark = res,
		total_duration = ((now() - start_time) * 1000) .. ' ms',
		minimum_duration = duration,
		result = func(1),
		msg = 'Benchmarks run ' .. count .. ' times and completed in ' .. tms .. ' ms (1/1000 sec) average :' .. res .. ' /ms',
		log = log,
		first_line = (_info or '') .. (defined or ''),
	}
	if not no_dump then
		dump(res)
	end
	return res
end

---benchmark_text text
---@param func fun(random_string:string, count_index:number) @function to be tested, could accept 2 parameters
---@param total_run_counts number @total execution counts
---@param random_text_length number @the length of random_text
---@param is_pure_word boolean @ the random_text only composed by alphabets
function _M.benchmark_text(func, total_run_counts, random_text_length, is_pure_word)
	local arr, res = array(total_run_counts)
	random_text_length = random_text_length or 30
	update_time()
	local t1, t2 = now()
	for i = 1, total_run_counts do
		arr[i] = _M.random_text(random_text_length, i, is_pure_word)
	end
	update_time()
	local prepare_time = math.floor((now() - t1) * 1000 + 0.5)
	update_time()
	t1 = now()
	for i = 1, total_run_counts do
		res = func(arr[i], i)
	end
	update_time()
	t2 = math.floor((now() - t1) * 1000 + 0.5)
	arr = nil
	collectgarbage('collect')
	return {
		mark = math.floor((total_run_counts / t2) + 0.5),
		run_duration = t2 .. ' ms',
		last_result = res,
		prepare_time = prepare_time .. 'ms',
		msg = 'Benchmarks run ' .. total_run_counts .. ' times and completed in ' .. t2 .. ' ms (1/1000 sec)',
	}
end

local tick_store = {}
function _M.start_tick(name)
	update_time()
	tick_store[name or 'timer'] = now()
end
function _M.end_tick(name)
	update_time()
	return 1000 * (now() - tick_store[name or name or 'timer'])
end

---aes_encrypt
---@param plain_str string @plain text to entrypt
---@return string @entryted string with system secure key
function _M.aes_encrypt(plain_str, secure_key)
	if not plain_str then
		return nil, 'empty input for aes_encrypt'
	end
	if type(plain_str) ~= 'string' then
		plain_str = plain_str .. ''
	end
	local aes_128_cbc_md5 = aes:new(secure_key)
	-- the default cipher is AES 128 CBC with 1 round of MD5
	return aes_128_cbc_md5:encrypt(plain_str)
end
---aes_decrypt
---@param encrypted_str string @encrypted text by aes_encrypt method
---@return string @plain text descrypted
function _M.aes_decrypt(encrypted_str, secure_key)
	if not encrypted_str then
		return nil, 'empty input for aes_decrypt'
	end
	if type(encrypted_str) ~= 'string' then
		return nil, 'must be sting'
	end
	local aes_128_cbc_md5 = aes:new(secure_key)
	return aes_128_cbc_md5:decrypt(encrypted_str)
end

---pack_string_args @ max 5 arguments accept for performance. more arguments using string list at first argument instead. The last argument could exceed 255 chars, other arguments must less than 255 char. Nil input will convert to empty string: ``
---@param arg1 string|string[] @ The first string argument, if it's string list, the following arguments will be ignored
---@param arg2 string @ within 255 chars
---@param arg3 string
---@param arg4 string
---@param arg5 string @ could exceed 255 chars if this is the last arguments
---@return string @serialized string
function _M.pack_string_args(arg1, arg2, arg3, arg4, arg5)
	if not arg1 then
		return
	end
	local data
	local tp = type(arg1)
	if tp == 'table' then
		local inx, key, val = 0
		while true do
			key, val = next(arg1, key)
			inx = inx + 1
			if key then
				if inx ~= key then
					arg1[inx] = '' -- fill `nil` array slot with `` empty string
				end
			else
				break
			end
		end
		local len = #arg1
		local pre = char(len)
		for i = 1, len - 1 do
			local arg = arg1[i]
			if not arg then
				arg1[i] = ''
				pre = pre .. char(0)
			else
				local n = #tostring(arg)
				if n > 255 then
					n = 255
					arg1[i] = sub(arg1[i], 1, 255)
				end
				pre = pre .. char(n)
			end
		end
		return pre .. concat(arg1)
	end
	if arg5 then
		arg5 = tostring(arg5)
		arg4 = tostring(arg4 or '')
		arg3 = tostring(arg3 or '')
		arg2 = tostring(arg2 or '')
		arg1 = tostring(arg1 or '')
		local n1, n2, n3, n4 = #arg1, #arg2, #arg3, #arg4
		if n1 > 255 then
			n1 = 255
			arg1 = sub(arg1, 1, 255)
		end
		if n2 > 255 then
			n2 = 255
			arg2 = sub(arg2, 1, 255)
		end
		if n3 > 255 then
			n3 = 255
			arg3 = sub(arg3, 1, 255)
		end
		if n4 > 255 then
			n4 = 255
			arg4 = sub(arg4, 1, 255)
		end
		data = char(5, n1, n2, n3, n4) .. arg1 .. arg2 .. arg3 .. arg4 .. arg5
	elseif arg4 then
		arg4 = tostring(arg4)
		arg3 = tostring(arg3 or '')
		arg2 = tostring(arg2 or '')
		arg1 = tostring(arg1 or '')
		local n1, n2, n3 = #arg1, #arg2, #arg3
		if n1 > 255 then
			n1 = 255
			arg1 = sub(arg1, 1, 255)
		end
		if n2 > 255 then
			n2 = 255
			arg2 = sub(arg2, 1, 255)
		end
		if n3 > 255 then
			n3 = 255
			arg3 = sub(arg3, 1, 255)
		end
		data = char(4, n1, n2, n3) .. arg1 .. arg2 .. arg3 .. arg4
	elseif arg3 then
		arg3 = tostring(arg3)
		arg2 = tostring(arg2 or '')
		arg1 = tostring(arg1 or '')
		local n1, n2 = #arg1, #arg2
		if n1 > 255 then
			n1 = 255
			arg1 = sub(arg1, 1, 255)
		end
		if n2 > 255 then
			n2 = 255
			arg2 = sub(arg2, 1, 255)
		end
		data = char(3, n1, n2) .. arg1 .. arg2 .. arg3
	elseif arg2 then
		arg2 = tostring(arg2)
		arg1 = tostring(arg1 or '')
		local n1 = #arg1
		if n1 > 255 then
			n1 = 255
			arg1 = sub(arg1, 1, 255)
		end
		data = char(2, n1) .. arg1 .. arg2
	elseif arg1 then
		arg1 = tostring(arg1)
		data = char(1) .. arg1
	end
	return data
end

---unpack_string_args correspond to pack_string_args, decode args from serialized string
---@param str string @ the serialized string arguments
---@param no_array boolean @Default with a string-list, set true to just return first 5 or less results
---@return string|string[], string, string, string, string
function _M.unpack_string_args(str, no_array)
	if not str then
		return nil
	end
	local len = #str
	local count = byte(str, 1)
	local last_inx = count + 1
	local end_inx = 0
	if no_array then
		if count > 5 then
			count = 5
		end
		if count == 5 then
			local n1, n2, n3, n4 = byte(str, 2, count)
			return sub(str, last_inx, last_inx + n1 - 1), sub(str, last_inx + n1, last_inx + n1 + n2 - 1), sub(str, last_inx + n1 + n2, last_inx + n1 + n2 + n3 - 1), sub(str, last_inx + n1 + n2 + n3, last_inx + n1 + n2 + n3 + n4 - 1), sub(str, last_inx + n1 + n2 + n3 + n4, len)
		elseif count == 4 then
			local n1, n2, n3, n4 = byte(str, 2, count)
			return sub(str, last_inx, last_inx + n1 - 1), sub(str, last_inx + n1, last_inx + n1 + n2 - 1), sub(str, last_inx + n1 + n2, last_inx + n1 + n2 + n3 - 1), sub(str, last_inx + n1 + n2 + n3, len)
		elseif count == 3 then
			local n1, n2, n3, n4 = byte(str, 2, count)
			return sub(str, last_inx, last_inx + n1 - 1), sub(str, last_inx + n1, last_inx + n1 + n2 - 1), sub(str, last_inx + n1 + n2, len)
		elseif count == 2 then
			local n1, n2, n3, n4 = byte(str, 2, count)
			return sub(str, last_inx, last_inx + n1 - 1), sub(str, last_inx + n1, len)
		elseif count == 1 then
			return sub(str, 2, len)
		end
	end
	local arr = array(count)
	for i = 1, count do
		arr[i] = byte(str, i + 1)
	end
	for i = 1, count - 1 do
		local arg_len = arr[i]
		end_inx = last_inx + arg_len
		arr[i] = sub(str, last_inx, end_inx - 1)
		last_inx = end_inx
	end
	arr[count] = sub(str, last_inx, len)
	return arr
end

--read all string from a file
function _M.read_file(filename, read_tail, is_binary)
	local file, err = io.open(filename, "r")
	if not file then
		return nil, err
	end
	local str, err
	if read_tail then
		local current = file:seek()
		local fileSize = file:seek("end")  --get file total size
		if fileSize > 200000 then
			file:seek('set', fileSize - 200000) --move cusor to last part
			str, err = file:read(200000)
		else
			file:seek('set', 0) --move cursor to head
			str, err = file:read(fileSize)
		end
	else
		str, err = file:read("*a")
	end
	file:close()
	str = str or ''
	return str, err
end

function _M.write_file(filename, str, is_overwrite, is_hashed, is_binary)
	local cont, err = _M.read_file(filename)
	if cont then
		if not is_overwrite then
			return 'File already exist!'
		end
		if str == cont then
			return 'File content are identical'
		end
		if is_hashed then
			if sub(cont, 1, 33) == sub(str, 1, 33) then
				return 'Same content hash'
			end
		end
	end
	local file, err = io.open(filename, is_binary and 'wb+' or 'w+')
	if not file then
		return err
	end
	local str, err = file:write(str)
	file:close()
	return err
end


function _M.main()
	_M.benchmark(function(inx) 
		return ngx.crc32_long('sssss')
	end)
end
--}}}
return _M