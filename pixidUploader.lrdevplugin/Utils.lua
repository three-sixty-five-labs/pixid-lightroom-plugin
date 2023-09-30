Utils = {}

function Utils.getOS()
	-- ask LuaJIT first
	if jit then
		return jit.os
	end

	-- Unix, Linux variants
	local fh,err = assert(io.popen("uname -o 2>/dev/null","r"))
	if fh then
		osname = fh:read()
	end

	if osname == "Darwin" then 
		return "MacOS"
	end
	
	return osname or "Windows"
end

function Utils.getHome()
	local fh,err = assert(io.popen("echo $HOME 2>/dev/null","r"))
	if fh then
		home = fh:read()
	end

	return home or ""
end 