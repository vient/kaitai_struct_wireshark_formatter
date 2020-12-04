<<PLACEHOLDER:_generated_parser_code>>

--
--
-- Taken from fpm.lua example
-- Dissector for TCP-based protocol, supporting assembling messages from several packets
--
--


local debug_level = {
    DISABLED = 0,
    LEVEL_1  = 1,
    LEVEL_2  = 2
}

local DEBUG = debug_level.LEVEL_1

local default_settings = {
    debug_level  = DEBUG,
    enabled      = true,    -- whether this dissector is enabled or not
    port         = <<PLACEHOLDER:tcp_port>>,   -- default TCP port number
}


local dprint = function() end
local dprint2 = function() end
local function resetDebugLevel()
    if default_settings.debug_level > debug_level.DISABLED then
        dprint = function(...)
            print(table.concat({"Lua: ", ...}," "))
        end
        if default_settings.debug_level > debug_level.LEVEL_1 then
            dprint2 = dprint
        end
    else
        dprint = function() end
        dprint2 = dprint
    end
end

resetDebugLevel()


ws_protocol.fields = proto_fields


local generic_dissect


function ws_protocol.dissector(buffer, pinfo, root)
    dprint2("ws_protocol.dissector called")
    local pktlen = buffer:len()
    local bytes_consumed = 0
    while bytes_consumed < pktlen do
        local result = generic_dissect(buffer, pinfo, root, bytes_consumed)
        if result > 0 then
            bytes_consumed = bytes_consumed + result
        elseif result == 0 then
            return 0
        else
            pinfo.desegment_offset = bytes_consumed
            result = -result
            pinfo.desegment_len = result
            return pktlen
        end
    end
    return bytes_consumed
end


generic_dissect = function (buffer, pinfo, root, offset)
    dprint2("generic_dissect function called at offset " .. offset)

    local msglen = buffer:len() - offset
    if msglen ~= buffer:reported_length_remaining(offset) then
        dprint2("Captured packet was shorter than original, can't reassemble")
        return 0
    end

    local kaitai_buffer = KaitaiStream(stringstream(buffer(offset):tvb()))
    -- local status, res = xpcall(parser_root, debug.traceback, kaitai_buffer)
    local status, res = pcall(parser_root, kaitai_buffer)
    if status then
        local parser = res
        local protocol_name_upper = string.upper(protocol_name)
        pinfo.cols.protocol:set(protocol_name_upper)
        if string.find(tostring(pinfo.cols.info), "^" .. protocol_name_upper) == nil then
            pinfo.cols.info:set(protocol_name_upper)
        end
        local consumed = parser:_apply(root)
        dprint2("Consumed " .. consumed .. " bytes")
        return consumed
    else
        dprint(res .. " at offset " .. offset)
        -- TODO: return needed length if known
        -- right now we ask for one more packet, it is O(n^2)
        return -DESEGMENT_ONE_MORE_SEGMENT
    end
end


local function enableDissector()
    DissectorTable.get("tcp.port"):add(default_settings.port, ws_protocol)
end

enableDissector()

local function disableDissector()
    DissectorTable.get("tcp.port"):remove(default_settings.port, ws_protocol)
end


local debug_pref_enum = {
    { 1,  "Disabled", debug_level.DISABLED },
    { 2,  "Level 1",  debug_level.LEVEL_1  },
    { 3,  "Level 2",  debug_level.LEVEL_2  },
}

ws_protocol.prefs.enabled = Pref.bool("Dissector enabled", default_settings.enabled,
                                                      "Whether the dissector is enabled or not")
ws_protocol.prefs.debug   = Pref.enum("Debug", default_settings.debug_level,
                                                      "Debug printing level", debug_pref_enum)

function ws_protocol.prefs_changed()
    dprint2("prefs_changed called")
    default_settings.debug_level = ws_protocol.prefs.debug
    resetDebugLevel()
    if default_settings.enabled ~= ws_protocol.prefs.enabled then
        default_settings.enabled = ws_protocol.prefs.enabled
        if default_settings.enabled then
            enableDissector()
        else
            disableDissector()
        end
        reload()
    end

end

dprint2("pcapfile Prefs registered")
