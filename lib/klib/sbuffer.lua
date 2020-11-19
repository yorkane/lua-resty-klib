---@class sbuffer
local sbuffer = {}
local new_tab = require("table.new")
local ins, concat, remove, tsort, tostring = table.insert, table.concat, table.remove, table.sort, tostring

---to_array convert a dictionary or bad array to a well formatted array
---@param tab table@ dictionary or bad array
---@return table<number, table|string>
function sbuffer.to_array(tab)
	local arr, index, val = new_tab(8, 0), nil
	while true do
		index, val = next(tab, index)
		if index then
			ins(arr, val)
		else
			break
		end
	end
	return arr
end
local to_array = sbuffer.to_array

---new @create new stringbuffer
---@return sbuffer
function sbuffer:new(...)
	local sbs = {
		buffer = to_array({ ... })
	}
	setmetatable(sbs, { __index = self })
	return sbs
end

setmetatable(sbuffer, {
	__call = function(self, tab)
		return self:new(tab)
	end,
}
)

---add @add multiple string args. :add(1,2,nil,'4',5) =1,2
---@return sbuffer
function sbuffer:add(...)
	local args = to_array({ ... })
	for i = 1, #args do
		local arg = args[i]
		ins(self.buffer, tostring(arg))
	end
	return self
end

---pop @remove buffer elements at tail poistion
---@param count number @element count to remove at tail position
---@return sbuffer
function sbuffer:pop(count)
	count = count or 1
	local len = #self.buffer
	for i = 1, count do
		remove(self.buffer, len)
		len = len - 1
	end
	return self
end

---tos  @convert stringbuffer to string
---@param splitor string @ string to join buffer together
---@return string
function sbuffer:tos(splitor)
	return concat(self.buffer, splitor)
end

return sbuffer