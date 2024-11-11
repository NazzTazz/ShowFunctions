-- Petit Plugin à la con pour corriger les erreurs de montage sur kit tournée
-- Sonne les machines dans l'ordre normal du patch et demande confirmation du bon montage 
-- Corrige le patch en cas d'inversion d'adresses
-- Permute les valeurs Zoom / Focus des machines concernées dans la range de presets définie ci-dessous
-- (c) 2024 Tristan Buet <tristan.buet@gmail.com> - GNU LGPL

local Config = {
    Fixtures        =    "123 Thru 127 + 2477 Thru 2483 + 321 Thru 324 + 311 + 312 + 2484 + 2485",
    FocusPresets    =    "1 Thru 14"
}

local Fixture = {}
local Patch = {}

function Debug(...)
    if (true) then
        gma.echo(string.format(...))
    end
end

function Cmd(...)
    if(false) then
        gma.cmd(string.format(...))
    else
        Debug('> '.. string.format(...))
    end
end

function Ids(expression)
    
    local chunks = {}
    local ids = {}
    
    expression = string.gsub(string.upper(expression), "%s+", "")
    
    for element in string.gmatch(expression, "([^+]+)") do
        
        chunks[#chunks +1] =  element
        
    end
    
    for _, chunk in pairs(chunks) do
        
        if string.match(chunk, 'THRU') then    
    
            local from_id = (string.sub(chunk, 1, string.find(chunk, 'THRU') - 1))
            local to_id   = (string.sub(chunk, string.find(chunk, 'THRU') + 4))    
            
            for id = tonumber(from_id), tonumber(to_id), ((to_id > from_id) and 1 or -1) do
                ids[#ids+1] = id
            end            
        else
            ids[#ids+1] = chunk
        end            
    end
    
    return ids
end

function RePatch()

    local ShowName = gma.show.getvar("SHOWFILE")
    Cmd('SaveShow "' .. ShowName .. ' - Before RePatch" ') -- /0
    
    local Fixture_Ids = Ids(Config.Fixtures)
    local Preset_Ids  = Ids(Config.FocusPresets)
    
    
    local __ids = {}
    
    for _, id in pairs(Fixture_Ids) do
    
        if (__ids[tonumber(id)]) then
            Debug("--- Fixture %d already cross-patched, skip", id)
            goto skip_fixture
        else
            Debug("--- Fixture %d hasn't been checked", id)
        end
        
        ::retry_crosspatch::
		Cmd("ClearAll; Highlight On; Fixture %d", id)
		
        local _id = gma.textinput(string.format("Fixture %d is ON. Which Mover is lit ?", id), id)
    
        if _id == nil then 
            if (gma.gui.confirm("Patch checking aborted", "Retry checking fixture ? \nCancel will reload backup")) then
                goto retry_crosspatch
            else
                Cmd('LoadShow "%s" /nc', ShowName .. " - Before RePatch")
                return false
            end
        end
    
        if __ids[_id] then
        
            gma.gui.confirm("RePatch() Error !", string.format("Fixture %d already cross-patched with Fixture %d", _id, __ids[_id]))
            
            goto retry_crosspatch
        
        else
        
            Fixture[tonumber(id)] = tonumber(_id)
            __ids[tonumber(_id)] = tonumber(id) 
        end
        ::skip_fixture::
    end
    Cmd("Highlight Off ; ClearAll")
    Cmd("BlindEdit On ; ClearAll")
    
    for k, v in pairs(Fixture) do

        if (tonumber(k) == tonumber(v)) then
            Debug("Fixture %d ... [OK]", k)
        else
            Debug("Fixture %d ... cross-patched with Fixture %d", k, v)
                        
            for _, preset in pairs(Preset_Ids) do
                Cmd("Fixture %d + %d ; At Preset 6.%d ; CircularCopy 1 ; Store Preset 6.%d /m ; ClearAll", k, v, preset, preset)
                Debug("Permuted data for Fixtures %d and %d in preset 6.%d", k, v, preset)
            end        
            
            local k_addr = gma.show.property.get(gma.show.getobj.handle("Fixture "..k), "Patch")
            local v_addr = gma.show.property.get(gma.show.getobj.handle("Fixture "..v), "Patch")
            Cmd("Assign Fixture %d /Patch=%s ; Assign Fixture %d /Patch=%s", k, v_addr, v, k_addr)
            Debug("Cross-Patched Fixtures %d [%s] and %d [%s]", k, k_addr, v, v_addr)
            
        end
    
    end
    
    Cmd("ClearAll ; BlindEdit Off") 

    Cmd('SaveShow "' .. ShowName .. ' - After RePatch" ') -- /4


end

function Cleanup()
    local progressBar = gma.gui.progress.start("Cleaning up...")
    for i = 0, progressBar + 64 do
        gma.gui.progress.stop(i)
    end
end 

return RePatch, Cleanup

-- *********************************************
-- currently implemented functions are:
-- *********************************************
--
--
--                            gma.sleep(number:sleep_seconds)
--                            gma.echo(all kind of values)
--                            gma.feedback(all kind of values)
--
-- string:build_date        = gma.build_date()
-- string:build_time        = gma.build_time()
-- string:version_hash      = gma.git_version()
--
--                            gma.export(string:filename,table:export_data)
--                            gma.export_csv(string:filename,table:export_data)
--                            gma.export_json(string:filename,table:export_data)
-- table:import_data        = gma.import(string:filename, [string:gma_subfolder])
--
--                            gma.cmd(string:command)
--                            gma.timer(function:name,number:dt,number:max_count,[function:cleanup])
-- number:time              = gma.gettime()
-- string:result            = gma.textinput(string:title,[string:old_text])
--
-- bool:result              = gma.gui.confirm(string:title,string:message)
--                          = gma.gui.msgbox(string:title,string:message)
--
-- number:handle            = gma.gui.progress.start(string:progress_name)
--                            gma.gui.progress.stop(number:progress_handle)
--                            gma.gui.progress.settext(number:progress_handle,string:text)
--                            gma.gui.progress.setrange(number:progress_handle,number:from,number:to)
--                            gma.gui.progress.set(number:progress_handle,number:value)
--
-- number:value             = gma.show.getdmx(number:dmx_addr)
-- table:values             = gma.show.getdmx(table:recycle,number:dmx_addr,number:amount)
--
-- number:handle            = gma.show.getobj.handle(string:name)
-- string:classname         = gma.show.getobj.class(number:handle)
-- number:index             = gma.show.getobj.index(number:handle)
-- number:commandline_number= gma.show.getobj.number(number:handle)
-- string:name              = gma.show.getobj.name(number:handle)
-- string:label             = gma.show.getobj.label(number:handle)  returns nil if object has no label set
-- number:amount_children   = gma.show.getobj.amount(number:handle)
-- number:child_handle      = gma.show.getobj.child(number:handle, number:index)
-- number:parent_handle     = gma.show.getobj.parent(number:handle)
-- bool:result              = gma.show.getobj.verify(number:handle)
-- bool:result              = gma.show.getobj.compare(number:handle1,number:handle2)
--
-- number:amount            = gma.show.property.amount(number:handle)
-- string:property_name     = gma.show.property.name(number:handle,number:index)
-- string:property          = gma.show.property.get(number:handle,number:index/string:property_name)
--
-- string:value             = gma.show.getvar(string:varname)
--                            gma.show.setvar(string:varname,string:value)
--
-- string:value             = gma.user.getvar(string:varname)
--                            gma.user.setvar(string:varname,string:value")
-- number:object handle     = gma.user.getcmddest()
-- number:object_handle     = gma.user.getselectedexec()
--
-- string:type              = gma.network.gethosttype()
-- string:subtype           = gma.network.gethostsubtype()
-- string:ip                = gma.network.getprimaryip()
-- string:ip                = gma.network.getsecondaryip()
-- string:status            = gma.network.getstatus()
-- number:session_number    = gma.network.getsessionnumber()
-- string:session_name      = gma.network.getsessionname()
-- number:slot              = gma.network.getslot()
--
-- table:host_data          = gma.network.gethostdata(string:ip,[table:recycle])
-- table:slot_data          = gma.network.getmanetslot(number:slot,[table:recycle])
-- table:performance_data   = gma.network.getperformance(number:slot,[table:recycle])

-- string:type              = gma.gethardwaretype()