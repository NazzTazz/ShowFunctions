-- Petit Plugin à la con pour corriger les erreurs de montage sur kit tournée
-- Sonne les machines dans l'ordre normal du patch et demande confirmation du bon montage 
-- Corrige le patch en cas d'inversion d'adresses
-- Permute les valeurs des machines concernées dans la range de presets définie ci-dessous
-- (c) 2024 Tristan Buet <tristan.buet@gmail.com> - GNU LGPL

local sf = require("showfunctions")

local Config = {
    Fixtures = "Fixture 123 Thru 127 + 2477 Thru 2483 + 321 Thru 324 + 311 + 312 + 2484 + 2485",
    Presets = "Preset 6.1 Thru 14"
}

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

function RePatch()

	local showName = gma.show.getvar("SHOWFILE"]
    Cmd('SaveShow "' .. ShowName .. ' - Before RePatch" ') -- /0
    
    local fixtures = sf.List(Config.Fixtures)
    local presets  = sf.List(Config.FocusPresets)    
    local patch = {}
    local crossPatch = {}
    
    for _, fixture in pairs(fixtures) do
    
        if (patch[fixture]) then
            Debug("--- %s already cross-patched, skip", fixture)
            goto skip_fixture
        end
        
        ::retry_crosspatch::
		Cmd("ClearAll; Highlight On; Fixture %d", id)
		
        local check = gma.textinput(string.format("%s is ON. Which Mover is lit ?", fixture), fixture)
    
        if check == nil then 
            if (gma.gui.confirm("Patch checking aborted", "Retry checking fixture ? \nCancel will reload backup")) then
                goto retry_crosspatch
            else
                Cmd('LoadShow "%s" /nc', ShowName .. " - Before RePatch")
                return false
            end
        end
    
        if patch[check] then
			local err = ''
			if patch[check] == check then
				err = string.format("%s already marked as correctly patched", check)				
			else
				err = string.format("%s already cross-patched with %s", check, patch[check])
            end
			gma.gui.confirm("RePatch() Error !", err)
            goto retry_crosspatch
        
        else        
            patch[fixture] = check
			patch[check] = fixture
            crossPatch[fixture] = check 
        end
        ::skip_fixture::
    end
	
    Cmd("Highlight Off ; ClearAll")
    Cmd("BlindEdit On ; ClearAll")
    
	local total_progress = gma.gui.progress.start("Processing: ")
	gma.gui.progress.setrange(total_progress, 0, #crossPatch)
	local index = 0
    for k, v in pairs(crossPatch) do
		
        if (k == v) then
            Debug("%s ... [OK]", k)
        else
            Debug("%s ... cross-patched with %s", k, v)
			gma.gui.progress.settext(total_progress,string.format("Cross-Patching %s and %s", k, v))
			gma.gui.progress.set(total_progress, index)
            local pair_progress = gma.gui.progress.start("CircularCopy: ")
			gma.gui.progress.setrange(pair_progress, 0, #Presets)
            for idx, preset in pairs(Presets) do
				gma.gui.progress.settext(pair_progress, preset)
				gma.gui.progress.set(pair_progress, idx)
                Cmd("%s; %s ; At %s ; CircularCopy 1 ; Store %d /m ; ClearAll", k, v, preset, preset)
                Debug("Permuted data for %s and %s in %s", k, v, preset)
            end        
            
            local k_addr = gma.show.property.get(gma.show.getobj.handle(k), "Patch")
            local v_addr = gma.show.property.get(gma.show.getobj.handle(v), "Patch")
            Cmd("Assign %s /Patch=%s ; Assign %s /Patch=%s", k, v_addr, v, k_addr)
            Debug("Cross-Patched Fixtures %s [%s] and %s [%s]", k, k_addr, v, v_addr)
			gma.gui.progress.stop(pair_progress)
        end
		index = index + 1
    end    
	gma.gui.progress.stop(total_progress)
    Cmd("ClearAll ; BlindEdit Off")
    Cmd('SaveShow "' .. ShowName .. ' - After RePatch" ')
end

function Cleanup()
    local progressBar = gma.gui.progress.start("Cleaning up...")
    for i = 0, progressBar + 64 do
        gma.gui.progress.stop(i)
    end
end 

return RePatch, Cleanup