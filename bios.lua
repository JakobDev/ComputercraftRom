
-- Install the new os api
local nativeOS = os
os = {}

function os.version()
	return "CraftOS 1.1"
end

function os.startTimer( ... )
	return nativeOS.startTimer( ... )
end

function os.pullEvent()
	return coroutine.yield()
end

function os.getComputerID()
	return nativeOS.getComputerID()
end

-- Install globals
function sleep( _nTime )
    local timer = os.startTimer( _nTime )
	repeat
		local sEvent, param = os.pullEvent()
	until sEvent == "timer" and param == timer
end

function write( sText )
	local w,h = term.getSize()		
	local x,y = term.getCursorPos()
		
	local function newLine()
		if y + 1 <= h then
			term.setCursorPos(1, y + 1)
		else
			term.scroll(1)
			term.setCursorPos(1, h)
		end
		x, y = term.getCursorPos()
	end
	
	-- Print the line with proper word wrapping
	while string.len(sText) > 0 do
		local whitespace = string.match( sText, "^[ \t]+" )
		if whitespace then
			-- Print whitespace
			term.write( whitespace )
			x,y = term.getCursorPos()
			sText = string.sub( sText, string.len(whitespace) + 1 )
		end
		
		local newline = string.match( sText, "^\n" )
		if newline then
			-- Print newlines
			newLine()
			sText = string.sub( sText, 2 )
		end
		
		local text = string.match( sText, "^[^ \t\n]+" )
		if text then
			sText = string.sub( sText, string.len(text) + 1 )
			if string.len(text) > w then
				-- Print a multiline word				
				while string.len( text ) > 0 do
				if x > w then
					newLine()
				end
					term.write( text )
					text = string.sub( text, (w-x) + 2 )
					x,y = term.getCursorPos()
				end
			else
				-- Print a word normally
				if x + string.len(text) > w then
					newLine()
				end
				term.write( text )
				x,y = term.getCursorPos()
			end
		end
	end
end

function print( ... )
	for n,v in ipairs( { ... } ) do
		write( tostring( v ) )
	end
	write( "\n" )
end

function read( _sReplaceChar, _tHistory )	
	term.setCursorBlink( true )
    local sLine = ""
	local nHistoryPos = nil
    if _sReplaceChar then
		_sReplaceChar = string.sub( _sReplaceChar, 1, 1 )
	end
	while true do
		local sEvent, param = os.pullEvent()
		if sEvent == "char" then
			sLine = sLine..param
			term.write( _sReplaceChar or param )
			
		elseif sEvent == "key" then
		    if param == 28 then
				-- Enter
				print()
				break
			elseif param == 200 or param == 208 then
                -- Up or down
				if _tHistory then
					if param == 200 then
						-- Up
						if nHistoryPos == nil then
							nHistoryPos = #_tHistory
						elseif nHistoryPos > 1 then
							nHistoryPos = nHistoryPos - 1
						end
					else
						-- Down
						if nHistoryPos == #_tHistory then
							nHistoryPos = nil
						elseif nHistoryPos ~= nil then
							nHistoryPos = nHistoryPos + 1
						end						
					end
                    local x, y = term.getCursorPos()
                    term.setCursorPos( x - string.len(sLine), y )
                    term.write( string.rep(" ", string.len(sLine)) )
                    term.setCursorPos( x - string.len(sLine), y )

					if nHistoryPos then
                    	sLine = _tHistory[nHistoryPos]
                    else
						sLine = ""
					end
					
					if _sReplaceChar then
	                    term.write( string.rep(_sReplaceChar, string.len(sLine)) )
					else
                    	term.write( sLine )
                    end
                end
			elseif param == 14 then
				-- Backspace
				if string.len( sLine ) > 0 then
					sLine = string.sub( sLine, 1, string.len( sLine ) - 1 )
					local x, y = term.getCursorPos()
					term.setCursorPos( x - 1, y )
					term.write( " " )
					term.setCursorPos( x - 1, y )
				end
			end
		end
	end
	term.setCursorBlink( false )
	return sLine
end

-- Install the new io api
io = {
	["read"] = function( _sFormat )
		return read()
	end,
	["write"] = function( _sText )
		write( _sText )
	end,
	["type"] = function( _handle )
		if type( _handle ) == "table" and _handle.bFile == true then
			if _handle.bClosed then
				return "closed file"
			else
				return "file"
			end
		end
		return nil
	end,
	["open"] = function( _sPath, _sMode )
		local sMode = _sMode or "r"
		local file = fs.open( _sPath, sMode )
		if not file then
			return nil
		end
		
		if sMode == "r" then
			return {
				bFile = true,
				bClosed = false,				
				["close"] = function( self )
					file.close();
					self.bClosed = true;
				end,
				["read"] = function( self, _sFormat )
					local sFormat = _sFormat or "*l"
					if sFormat == "*l" then
						return file.readLine()
					elseif sFormat == "*a" then
						return file.readAll()
					end
					return nil
				end,
			}
		else
			return {
				bFile = true,
				bClosed = false,				
				["close"] = function( self )
					file.close();
					self.bClosed = true;
				end,
				["write"] = function( self, _sText )
					file.write( _sText )
				end,
			}
		end
	end,
}

-- Install dofile and loadfile
loadfile = function( _sFile )
	local file = fs.open( _sFile, "r" )
	if file then
		local func, err = loadstring( file.readAll(), _sFile )
		file.close()
		return func, err
	end 
	return nil, "File not found"
end

dofile = function( _sFile )
	local fnFile, e = loadfile( _sFile )
	if fnFile then
		fnFile()
	else
		error( e )
	end
end

-- Install some more of the OS api
function os.run( _tEnv, _sPath, ... )
    local tArgs = { ... }
    local fnFile, error = loadfile( _sPath )
    if fnFile then
        local tEnv = _tEnv
        setmetatable( tEnv, { __index = _G } )
        setfenv( fnFile, tEnv )
        local ok, error = pcall( function()
        	fnFile( unpack( tArgs ) )
        end )
        if not ok then
        	print( error )
        	return false
        end
        return true
    end
    print( error )
    return false
end

function os.sleep( _nTime )
	sleep( _nTime )
end

function os.shutdown()
	nativeOS.shutdown()
	while true do
		coroutine.yield()
	end
end

-- Ammend the HTTP api if enabled
if http then
	http.get = function( _url )
		local requestID = http.request( _url )
		while true do
			local event, param1, param2 = os.pullEvent()
			if event == "http_success" and param1 == _url then
				return param2
			elseif event == "http_failure" and param1 == _url then
				return nil
			end
		end
	end
end

-- Protect the global table against further modifications
local function protect( _t )
	setmetatable( _t, { __newindex = function()
		error( "Attempt to write to global" )
	end } )
end

protect( _G )
for k,v in pairs( _G ) do
	if type(v) == "table" then
		protect( v )
	end
end
	
-- Run the shell
local ok = nil
if fs.exists( "startup" ) and not fs.isDir( "startup" ) then
	ok = os.run( {}, "rom/programs/shell", "startup" )
else
	ok = os.run( {}, "rom/programs/shell" )
end

if not ok then
	error( "Error running shell" )
else
	os.run( {}, "rom/programs/shutdown" )
end
