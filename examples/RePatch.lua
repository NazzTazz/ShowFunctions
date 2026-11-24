-- Petit Plugin à la con pour corriger les erreurs de montage sur kit tournée
-- Sonne les machines dans l'ordre normal du patch et demande confirmation du bon montage
-- Corrige le patch en cas d'inversion d'adresses
-- Permute les valeurs des machines concernées dans la range de presets définie ci-dessous
-- (c) 2024 Tristan Buet <tristan.buet@gmail.com> - GNU LGPL

local sf = require("showfunctions")

local Config = {
    Fixtures = "Fixture 123 Thru 127 + 2477 Thru 2483 + 321 Thru 324 + 311 + 312 + 2484 + 2485",
    Presets  = "Preset 6.1 Thru 14",
    DryRun   = true     -- true : affiche les commandes sans les exécuter ; false : applique réellement
}

-- Fonctions locales : elles ne remplacent pas le Cmd/Debug global de ShowFunctions.
-- (Les redéfinir en global ferait passer toute la bibliothèque en DryRun, ou l'inverse.)
local function Debug(...)
    gma.echo(string.format(...))
end

local function Cmd(...)
    if Config.DryRun then
        Debug('> ' .. string.format(...))
    else
        gma.cmd(string.format(...))
    end
end

local function RePatch()

    local showName = gma.show.getvar("SHOWFILE")
    Cmd('SaveShow "%s - Before RePatch"', showName)

    local fixtures = sf.Obj.List(Config.Fixtures)   -- { "Fixture 123", ... }
    local presets  = sf.Obj.List(Config.Presets)    -- { "Preset 6.1", ... }

    -- Ids numériques pour la logique, noms pour les commandes
    local ids, nameOf, inList = {}, {}, {}
    for _, fixture in ipairs(fixtures) do
        local _, _, id = sf.Obj.SplitName(fixture)
        ids[#ids + 1], nameOf[id], inList[id] = id, fixture, true
    end

    local answers = {}  -- answers[fixture] = machine qui s'allume quand on sonne la fixture
    local seen = {}     -- seen[machine]    = fixture qui l'a allumée

    for _, id in ipairs(ids) do

        -- Si une fixture précédente a allumé celle-ci, l'échange est proposé par défaut :
        -- Entrée suffit pour confirmer, et une permutation à trois machines devient visible.
        local default = seen[id] or id

        ::retry_crosspatch::
        Cmd("ClearAll; Highlight On; %s", nameOf[id])

        local input = gma.textinput(string.format("%s is ON. Which Mover is lit ?", nameOf[id]), tostring(default))

        if input == nil then
            if (gma.gui.confirm("Patch checking aborted", "Retry checking fixture ? \nCancel will reload backup")) then
                goto retry_crosspatch
            else
                Cmd('LoadShow "%s - Before RePatch" /nc', showName)
                return false
            end
        end

        local _, _, lit = sf.Obj.SplitName(input)  -- accepte "124" comme "Fixture 124"

        if lit == nil or not inList[lit] then
            gma.gui.confirm("RePatch() Error !", string.format("'%s' is not one of the checked fixtures", input))
            goto retry_crosspatch
        end

        if seen[lit] and seen[lit] ~= id then
            gma.gui.confirm("RePatch() Error !", string.format("%s was already lit by %s", nameOf[lit], nameOf[seen[lit]]))
            goto retry_crosspatch
        end

        answers[id] = lit
        seen[lit] = id
    end
    Cmd("Highlight Off ; ClearAll")

    -- Seuls les échanges simples A <-> B sont corrigés automatiquement.
    local swaps = {}
    for _, k in ipairs(ids) do
        local v = answers[k]
        if k ~= v and answers[v] ~= k then
            gma.gui.confirm("RePatch() Error !", string.format(
                "%s lights %s, but %s lights %s.\nMore than two fixtures are swapped: fix it by hand.\nNothing has been changed.",
                nameOf[k], nameOf[v], nameOf[v], nameOf[answers[v]]))
            return false
        elseif k < v then -- chaque paire une seule fois
            swaps[#swaps + 1] = { nameOf[k], nameOf[v] }
        else
            if k == v then Debug("%s ... [OK]", nameOf[k]) end
        end
    end

    Cmd("BlindEdit On ; ClearAll")

    local total_progress = gma.gui.progress.start("Processing: ")
    gma.gui.progress.setrange(total_progress, 0, #swaps)

    for index, pair in ipairs(swaps) do
        local k, v = pair[1], pair[2]
        Debug("%s ... cross-patched with %s", k, v)
        gma.gui.progress.settext(total_progress, string.format("Cross-Patching %s and %s", k, v))
        gma.gui.progress.set(total_progress, index)

        local pair_progress = gma.gui.progress.start("CircularCopy: ")
        gma.gui.progress.setrange(pair_progress, 0, #presets)
        for idx, preset in ipairs(presets) do
            gma.gui.progress.settext(pair_progress, preset)
            gma.gui.progress.set(pair_progress, idx)
            Cmd("%s + %s ; At %s ; CircularCopy 1 ; Store %s /m ; ClearAll", k, v, preset, preset)
            Debug("Permuted data for %s and %s in %s", k, v, preset)
        end
        gma.gui.progress.stop(pair_progress)

        local k_addr = gma.show.property.get(gma.show.getobj.handle(k), "Patch")
        local v_addr = gma.show.property.get(gma.show.getobj.handle(v), "Patch")
        Cmd("Assign %s /Patch=%s ; Assign %s /Patch=%s", k, v_addr, v, k_addr)
        Debug("Cross-Patched Fixtures %s [%s] and %s [%s]", k, k_addr, v, v_addr)
    end

    gma.gui.progress.stop(total_progress)
    Cmd("ClearAll ; BlindEdit Off")
    Cmd('SaveShow "%s - After RePatch"', showName)
end

local function Cleanup()
    local progressBar = gma.gui.progress.start("Cleaning up...")
    for i = 0, progressBar + 64 do
        gma.gui.progress.stop(i)
    end
end

return RePatch, Cleanup
