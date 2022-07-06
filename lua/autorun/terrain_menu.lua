AddCSLuaFile()
if SERVER then return end


CreateClientConVar("terrain_loddistance", "5000", true, false, "Distance to chunk that defines wheather to render high or low definition", 0)
cvars.AddChangeCallback("terrain_loddistance", function(_, _, val) Terrain.LODDistance = val^2 end)

local options
concommand.Add("terrain_menu", function()
    options = options or table.Copy(Terrain.Variables)
    local changedTerrain = false

    // start creating visual design
    local mainFrame = vgui.Create("DFrame")
    mainFrame:SetSize(800, 400)
    mainFrame:SetTitle("Terrain Menu")
    mainFrame:Center()
    mainFrame:MakePopup()
    function mainFrame:OnClose()
        if changedTerrain then
            for k, v in ipairs(ents.FindByClass("terrain_chunk")) do
                //v:BuildCollision()    // FUNNY MEMORY LEAK HAHAHAH
                v:GenerateMesh()
                v:GenerateTrees()
                v:SetRenderBounds(v:OBBMins(), v:OBBMaxs() + Vector(0, 0, 1000))
            end

            Terrain.Material:SetTexture("$basetexture", Terrain.Variables.material_2)
            Terrain.Material:SetTexture("$basetexture2", Terrain.Variables.material_1)
            Terrain.WaterMaterial = Material(Terrain.Variables.material_3)
        end
        Terrain.Variables.temp_waterHeight = nil
    end

    -- some helper functions to make our life easier, I hope
    local Panel = FindMetaTable("Panel")
    function Panel:meeSlider(text, min, max, option, decimals, dock) -- NOTE! 'option' is a string!
        local slider = vgui.Create("DNumSlider", self)
        slider:Dock(dock)
        slider:DockMargin(0, 5, 0, 5)
        slider:SetSize(410, 15)
        slider:SetText(text)
        slider:SetMinMax(min, max)
        slider:SetValue(options[option])
        slider:SetDecimals(decimals)
        slider:SetDark(true)
        if decimals ~= 0 then
            function slider:OnValueChanged(val)
                options[option] = val
            end
        else
            function slider:OnValueChanged(val)
                options[option] = math.Round(val) -- enforce integers
            end
        end
        return slider
    end

    function Panel:meeCheckbox(text, option, dock) -- NOTE! 'option' is a string!
        local checkbox = vgui.Create("DCheckBoxLabel", self)
        checkbox:Dock(dock)
        checkbox:DockMargin(0, 5, 0, 0)
        checkbox:SetSize(16, 16)
        checkbox:SetText(text)
        checkbox:SetValue(options[option])
        checkbox:SetTextColor(Color(0, 0, 0))
        function checkbox:OnChange(val)
            options[option] = val
        end
        return checkbox
    end

    function Panel:meeColorMixer(text, option, scale, dock)
        local mixer = vgui.Create("DColorMixer", self)
        mixer:DockMargin(0, 5, 0, 0)
        mixer:Dock(dock)
        mixer:SetSize(410, 150)	
        mixer:SetPalette(true)  	
        mixer:SetLabel(text)
        mixer:SetAlphaBar(false)
        mixer:SetWangs(true)
        mixer:SetVector(options[option] / scale) 	-- Set the default color
        local factor = scale / 255
        function mixer:ValueChanged(col)
            options[option] = Vector(col.r * factor, col.g * factor, col.b * factor)
        end
        return mixer
    end

    function Panel:fastDiv(x, y, dock)
        div = vgui.Create("DPanel", self)
        div:Dock(dock)
        div:SetSize(x, y)
        function div:Paint() end
        return div
    end


    // the tabs
    local tabsFrame = vgui.Create("DPanel", mainFrame)
    tabsFrame:SetSize(425, 365)
    tabsFrame:SetPos(370, 30)
    tabsFrame.Paint = nil

    // the mountain tab, contains the submit & test buttons & height modifiers
    local function mountainTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Mountains", scrollPanel, "icon16/world_edit.png").Tab

        -- a div to hold our docked stuff, we gotta leave space for what's below
        local normalOptions = scrollPanel:fastDiv(410,220,TOP)

        // editable sliders
        normalOptions:meeSlider("Main Mountain Height", 0, 200, "height_1", 1, TOP)
        normalOptions:meeSlider("Main Mountain Size", 1, 50, "noiseScale_1", 1, TOP)
        normalOptions:meeSlider("Secondary Mountain Height", 0, 200, "height_2", 1, TOP)
        normalOptions:meeSlider("Secondary Moutain Size", 1, 50, "noiseScale_2", 1, TOP)

        normalOptions:meeCheckbox("Leave Space for Flatgrass Building?", "spawnArea", BOTTOM)
        normalOptions:meeCheckbox("Clamp Noise? (0 to 1 instead of -1 to 1)", "clampNoise", BOTTOM)
        normalOptions:meeSlider("Terrain Seed", 0, 2^32, "seed", 0, BOTTOM)
        normalOptions:meeSlider("Terrain Z Offset", 0, 100, "offset", 1, BOTTOM)

        local material_grass = vgui.Create("DTextEntry", scrollPanel)
        material_grass:SetPos(0, 225)
        material_grass:SetSize(200, 20)
        material_grass:SetValue(options.material_1 or "gm_construct/grass1")
        material_grass:SetPlaceholderText("gm_construct/grass1")
        material_grass:SetTextColor(Color(0, 0, 0))
        material_grass:SetUpdateOnType(true)
        function material_grass:OnValueChange(val)
            if val == "" then val = material_grass:GetPlaceholderText() end
            options.material_1 = val
        end

        local material_rock = vgui.Create("DTextEntry", scrollPanel)
        material_rock:SetPos(0, 250)
        material_rock:SetSize(200, 20)
        material_rock:SetValue(options.material_2 or "nature/rockfloor005a")
        material_rock:SetPlaceholderText("nature/rockfloor005a")
        material_rock:SetTextColor(Color(0, 0, 0))
        material_rock:SetUpdateOnType(true)
        function material_rock:OnValueChange(val)
            if val == "" then val = material_rock:GetPlaceholderText() end
            options.material_2 = val
        end

        local grassText = vgui.Create("DLabel", scrollPanel)
        grassText:SetPos(205, 220)
        grassText:SetSize(250, 50)
        grassText:SetColor(Color(0, 0, 0))
        grassText:SetText("<- (Advanced) Textures used for grass\nand rock blending, used mainly for biomes\n(Must be a .vmt texture)\n(Examples in description of addon)")
    end

    // the foilage tab, contains settings for trees & grass
    local function treeTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Foliage", scrollPanel, "icon16/arrow_up.png").Tab

        local container = scrollPanel:fastDiv(410,270,FILL) -- needed since everything here is docked

        // editable sliders
        container:meeSlider("Tree Size", 1, 10, "treeHeight", 1, TOP)
        container:meeSlider("Tree Density (x*x per chunk)", 0, 10, "treeResolution", 0, TOP)
        container:meeSlider("Tree Slope Threshold", 0, 1, "treeThreshold", 3, TOP) -- TODO: invert this slider

        container:meeSlider("Grass Size", 5, 100, "grassSize", 3, BOTTOM)
        container:meeCheckbox("Generate Grass?", "generateGrass", BOTTOM)
        container:meeColorMixer("Tree Color", "treeColor", 5, BOTTOM)
    end

    local function functionTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Custom", scrollPanel, "icon16/application_xp_terminal.png").Tab

        local funcText = vgui.Create("DLabel", scrollPanel)
        funcText:SetPos(0, 30)
        funcText:SetSize(410, 16)
        funcText:SetColor(Color(0, 0, 0))
        funcText:SetText("Optional Custom GLua Height Function (Must return a number in 0-100 Range!)")

        local funcText = vgui.Create("DLabel", scrollPanel)
        funcText:SetPos(0, 255)
        funcText:SetSize(400, 16)
        function funcText:Paint(w, h)
            surface.SetDrawColor(0, 0, 0)
	        surface.DrawRect(0, 0, w, h)
        end

        local func = vgui.Create("DTextEntry", scrollPanel)
        func:SetPos(0, 50)
        func:SetSize(400, 200)
        func:SetMultiline(true)
        func:SetText(options.customFunction or "")
        function func:OnChange()
            options.customFunction = nil
            if !LocalPlayer():IsSuperAdmin() then
                funcText:SetText(" You must be Superadmin to use this!")
                funcText:SetColor(Color(255, 0, 0))
                return 
            end
            if func:GetValue() != "" then
                local compiledFunction = CompileString("local x, y, chunk = ...\n" .. func:GetValue(), "Terrain Function", false)
                if isstring(compiledFunction) then 
                    funcText:SetText(" Error: " .. compiledFunction)
                    funcText:SetColor(Color(255, 100, 100))
                else
                    local generatedFunction = setfenv(compiledFunction, Terrain.AllowedLibraries)
                    local suc, msg = pcall(function()
                        local compiled = generatedFunction(0, 0, Terrain.Chunks[1])
                        if !isnumber(compiled) then
                            funcText:SetText(" Error: Return value must be a number")
                            funcText:SetColor(Color(255, 100, 100))
                            return 
                        end
                        funcText:SetText(" Success")
                        funcText:SetColor(Color(100, 255, 100))
                        options.customFunction = func:GetValue()
                    end)
                    if !suc then
                        funcText:SetText(" Error: " .. msg)
                        funcText:SetColor(Color(255, 100, 100))
                    end
                end
            else
                funcText:SetText(" No Function Defined")
                funcText:SetColor(Color(255, 255, 255))
            end
        end
        func:OnChange()

        local customChoices = vgui.Create("DComboBox", scrollPanel)
        customChoices:SetPos(0, 0)
        customChoices:SetSize(200, 20)
        customChoices:SetText("Terrain Function Examples")
        customChoices:AddChoice("Ripple", "return (sin(sqrt((x * 5)^2 + (y * 5)^2)) + 1) * 2")
        customChoices:AddChoice("Sine and Cosine Hills", "return (sin(x * 5) + cos(y * 5)) * 5")
        customChoices:AddChoice("Volcano", "return min(1 / (((x / 15)^2 + (y / 15)^2)), 50)")
        customChoices:AddChoice("Schuh Mountain", "return -(x^2+y^2)^0.5 * 8 + 60")
        customChoices:AddChoice("Plus Shaped Valley", "return x^2 * y^2")
        customChoices:AddChoice("Big Inverse Dome", "return 2^abs(x) + 2^abs(y)")
        customChoices:AddChoice("Dome Single", "return sqrt(1 - (x^2 + y^2)) * 10")
        customChoices:AddChoice("Domes Infinite", "local a = ((x * 0.5 + 0.5) % 1) * 2 - 1\nlocal b = ((y * 0.5 + 0.5) % 1) * 2 - 1\nreturn sqrt(1 - (a^2 + b^2)) * 10")
        customChoices:AddChoice("BlackHole", "return -30 / sqrt(x^2+y^2) + 100")
        customChoices:AddChoice("Spiral", "return (60/7.5) * sqrt(x^2 + y^2) + 0.18 * cos((80/7.5) * sqrt(x^2+y^2) + atan2(x,y)) * 60/7.5")
        customChoices:AddChoice("Checkerboard", "return (Round(x)%2 + Round(y)%2) % 2 * 10")
        customChoices:AddChoice("Basic Perlin Implementation", "return (Simplex.Noise2D(x / 10, y / 10) + 1) * 20 + Simplex.Noise2D(x, y)")
        customChoices:AddChoice("Avatar: The Last Airbender", "return Simplex.Noise2D(x / 3, y / 3) * 200")
        customChoices:AddChoice("Mee Graph", "local values = \n{1,1,0,0,0,1,1,0,0,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,0,0,1,1,1,0,1,1,1,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,1,1,1,1,1,0,0,0,0,1,1,1,1,1,0,0,0,1,1,0,1,0,1,1,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,1,1,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,1,1,0,0,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,0,0}\nlocal localX = -floor(((x * 4) - 26) / 2)\nlocal localY = (floor((y + 5) * 2) * 26)\nif localX < 0 or localX > 26 then\nreturn 0\nend\nreturn (values[localX + localY] or 0) * 10")
        function customChoices:OnSelect(index, text, data)
            func:SetText(data)
            func:OnChange()
        end

        local spawnBox = vgui.Create("DCheckBoxLabel", scrollPanel)
        spawnBox:SetPos(207, 3)
        spawnBox:SetSize(16, 16)
        spawnBox:SetText("Leave Space for Flatgrass Building?")
        spawnBox:SetValue(options.spawnArea)
        spawnBox:SetTextColor(Color(0, 0, 0))
        function spawnBox:OnChange(val)
            options.spawnArea = val
        end
    end

    -- the water tab, for water stuff.
    local function waterTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Water", scrollPanel, "icon16/water.png").Tab

        local waterHeight
        local waterEnabled = scrollPanel:meeCheckbox("Enable Water?", "waterHeight", TOP)
        function waterEnabled:OnChange(val)
            if val then 
                options.waterHeight = waterHeight:GetValue()
                Terrain.Variables.temp_waterHeight = waterHeight:GetValue()
            else
                Terrain.Variables.temp_waterHeight = -math.huge
                options.waterHeight = nil
            end
        end

        waterHeight = scrollPanel:meeSlider("Water Height", -12765, 12765, "waterHeight", 0, TOP)
        function waterHeight:OnValueChanged(val) -- special
            options.waterHeight = val
            Terrain.Variables.temp_waterHeight = val
            waterEnabled:SetValue(true)
        end

        local waterText = vgui.Create("DLabel", scrollPanel)
        waterText:SetPos(0, 150)
        waterText:SetSize(250, 20)
        waterText:SetColor(Color(0, 0, 0))
        waterText:SetText("Water Material (better with transparent materials)")

        local material_water = vgui.Create("DTextEntry", scrollPanel)
        material_water:SetPos(0, 170)
        material_water:SetSize(300, 20)
        material_water:SetValue(options.material_3 or "procedural_terrain/water/water_warp")
        material_water:SetPlaceholderText("procedural_terrain/water/water_warp")
        material_water:SetTextColor(Color(0, 0, 0))
        material_water:SetUpdateOnType(true)
        function material_water:OnValueChange(val)
            if val == "" then val = material_water:GetPlaceholderText() end
            options.material_3 = val
        end

        // instant kill water
        //scrollPanel:meeCheckbox("Water = Instant Death", "water_kill", TOP)
        local water_var = vgui.Create("DCheckBoxLabel", scrollPanel)
        water_var:SetPos(0, 100)
        water_var:SetSize(16, 16)
        water_var:SetText("Water = Instant Death")
        water_var:SetValue(options.water_kill)
        water_var:SetTextColor(Color(0, 0, 0))
        function water_var:OnChange(val)
            options.water_kill = val
        end

        // ignite water
        local water_var = vgui.Create("DCheckBoxLabel", scrollPanel)
        water_var:SetPos(0, 125)
        water_var:SetSize(16, 16)
        water_var:SetText("Catch on fire if touch water? (good for lava)")
        water_var:SetValue(options.water_ignite)
        water_var:SetTextColor(Color(0, 0, 0))
        function water_var:OnChange(val)
            options.water_ignite = val
        end

        scrollPanel:meeSlider("Water Viscocity", -10, 10, "water_viscosity", 2, TOP)
        scrollPanel:meeSlider("Buoyancy Multiplier", -100, 100, "water_buoyancy", 2, TOP)
    end

    // saving & loading done here
    local function saveTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Save / Load", scrollPanel, "icon16/disk.png").Tab

        local saveButton = vgui.Create("DButton", scrollPanel)
        saveButton:SetPos(250, 10)
        saveButton:SetSize(150, 20)
        saveButton:SetText("Save Current Preset")
        function saveButton:DoClick()
            
        end

        local deleteButton = vgui.Create("DButton", scrollPanel)
        deleteButton:SetPos(250, 40)
        deleteButton:SetSize(150, 20)
        deleteButton:SetText("Delete Selected Preset")
        function deleteButton:DoClick()
            local ok = vgui.Create("DFrame")
            ok:SetTitle("Are you sure?")
            ok:SetSize(200, 100)
            ok:Center()
            ok:MakePopup()
            ok:SetBackgroundBlur(true)

            local button = vgui.Create("DButton", ok)
            button:SetPos(10, 50)
            button:SetSize(70, 30)
            button:SetText("Yes")
            function button:DoClick()
                ok:Close()
            end

            local button = vgui.Create("DButton", ok)
            button:SetPos(120, 50)
            button:SetSize(70, 30)
            button:SetText("No")
            function button:DoClick()
                ok:Close()
            end
        end
    end

    // minimap ortho view
    local zoomAmount = 1
    local renderBox = vgui.Create("DPanel", mainFrame)
	renderBox:SetSize(350, 360)
    renderBox:SetPos(10, 30)
    function renderBox:PaintOver(w, h)
        surface.SetDrawColor(100, 200, 100)
	    surface.DrawOutlinedRect(0, 0, w, h, 5)
        surface.DrawOutlinedRect(35, 340, 280, 20, 1)
        surface.SetDrawColor(50, 100, 50)
        surface.DrawRect(36, 341, 278, 18)
    end
    function renderBox:Paint(w, h)
        local x = mainFrame:GetX() + renderBox:GetX()
        local y = mainFrame:GetY() + renderBox:GetY()
        local old = DisableClipping(true)
        local orthoScale = 2^14 / zoomAmount
        render.RenderView({
            origin = Angle(45, CurTime() * 10, 0):Forward() * -2^14 + Vector(0, 0, 3000),
            angles = Angle(60, CurTime() * 10, 0),
            x = x, y = y,
            w = w, h = h,
            zfar = 2^16,
            ortho = {
                left = -orthoScale,
                right = orthoScale,
                top = -orthoScale,
                bottom = orthoScale,
            }
        })
        DisableClipping(old)
    end
    // ortho zoom slider
    local renderZoom = vgui.Create("DNumSlider", mainFrame)
	renderZoom:SetPos(50, 374)
	renderZoom:SetSize(300, 10)
	renderZoom:SetText("Zoom")
	renderZoom:SetMinMax(1, 10)
	renderZoom:SetValue(1)
	renderZoom:SetDecimals(0)
    function renderZoom:OnValueChanged(val)
        zoomAmount = val
    end

    local tabs = vgui.Create("DPropertySheet", tabsFrame)
	tabs:Dock(FILL)

    mountainTab(tabs)
    functionTab(tabs)
    treeTab(tabs)
    waterTab(tabs)
    saveTab(tabs)

    // test & submit changes button
    if LocalPlayer():IsSuperAdmin() then 
        local submitButton = vgui.Create("DButton", tabsFrame)
        submitButton:SetPos(250, 305)
        submitButton:SetSize(150, 50)
        submitButton:SetIcon("models/weapons/v_slam/new light1")
        submitButton:SetText("     Submit Changes")
        function submitButton:DoClick()
            net.Start("TERRAIN_SEND_DATA")
            net.WriteTable(options)    // writetable since value types may change during development
            net.SendToServer()
            changedTerrain = false
        end
    end

    local testButton = vgui.Create("DButton", tabsFrame)
    testButton:SetPos(10, 305)
    testButton:SetSize(150, 50)
    testButton:SetIcon("models/weapons/v_slam/new light2")
    testButton:SetText("Test Changes")
    function testButton:DoClick() 
        local newFunction = Terrain.BuildMathFunc(options)

        // reload all chunks with the new function
        for k, v in ipairs(ents.FindByClass("terrain_chunk")) do
            //v:BuildCollision(newFunction) // this shit crashes u
            v:GenerateMesh(newFunction)
            v:GenerateTrees(newFunction, options)
            v:SetRenderBounds(v:OBBMins() * Vector(1, 1, -1), v:OBBMaxs() + Vector(0, 0, 1000))
        end

        Terrain.Material:SetTexture("$basetexture", options.material_2)
        Terrain.Material:SetTexture("$basetexture2", options.material_1)
        Terrain.WaterMaterial = Material(options.material_3)

        changedTerrain = true
    end
end)