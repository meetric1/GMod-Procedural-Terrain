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
                //v:BuildCollision()
                v:GenerateMesh()
                v:GenerateTrees()
                v:SetRenderBounds(v:OBBMins(), v:OBBMaxs() + Vector(0, 0, 1000))
            end
        end
        Terrain.Variables.temp_waterHeight = nil
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

        // editable sliders
        local heightSlider = vgui.Create("DNumSlider", scrollPanel)
        heightSlider:SetPos(0, 0)
        heightSlider:SetSize(410, 15)
        heightSlider:SetText("Mountain Height")
        heightSlider:SetMinMax(0, 200)
        heightSlider:SetValue(options.height)
        heightSlider:SetDecimals(1)
        heightSlider:SetDark(true)
        function heightSlider:OnValueChanged(val)
            options.height = val
        end

        local noiseScaleSlider = vgui.Create("DNumSlider", scrollPanel)
        noiseScaleSlider:SetPos(0, 25)
        noiseScaleSlider:SetSize(410, 15)
        noiseScaleSlider:SetText("Mountain Size")
        noiseScaleSlider:SetMinMax(1, 50)
        noiseScaleSlider:SetValue(options.noiseScale)
        noiseScaleSlider:SetDecimals(1)
        noiseScaleSlider:SetDark(true)
        function noiseScaleSlider:OnValueChanged(val)
            options.noiseScale = val
        end

        local offsetSlider = vgui.Create("DNumSlider", scrollPanel)
        offsetSlider:SetPos(0, 50)
        offsetSlider:SetSize(410, 15)
        offsetSlider:SetText("Terrain Z Offset")
        offsetSlider:SetMinMax(0, 100)
        offsetSlider:SetValue(options.offset)
        offsetSlider:SetDecimals(1)
        offsetSlider:SetDark(true)
        function offsetSlider:OnValueChanged(val)
            options.offset = val
        end

        local seedSlider = vgui.Create("DNumSlider", scrollPanel)
        seedSlider:SetPos(0, 75)
        seedSlider:SetSize(410, 15)
        seedSlider:SetText("Terrain Seed")
        seedSlider:SetMinMax(0, 2^32)
        seedSlider:SetValue(options.seed)
        seedSlider:SetDecimals(0)
        seedSlider:SetDark(true)
        function seedSlider:OnValueChanged(val)
            options.seed = val
        end

        local clampBox = vgui.Create("DCheckBoxLabel", scrollPanel)
        clampBox:SetPos(0, 100)
        clampBox:SetSize(16, 16)
        clampBox:SetText("Clamp Noise? (0 to 1 instead of -1 to 1)")
        clampBox:SetValue(options.clampNoise)
        clampBox:SetTextColor(Color(0, 0, 0))
        function clampBox:OnChange(val)
            options.clampNoise = val
        end

        local spawnBox = vgui.Create("DCheckBoxLabel", scrollPanel)
        spawnBox:SetPos(0, 125)
        spawnBox:SetSize(16, 16)
        spawnBox:SetText("Leave Space for Flatgrass Building?")
        spawnBox:SetValue(options.spawnArea)
        spawnBox:SetTextColor(Color(0, 0, 0))
        function spawnBox:OnChange(val)
            options.spawnArea = val
        end
    end

    // the mountain tab, contains the submit & test buttons & height modifiers
    local function treeTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Foliage", scrollPanel, "icon16/arrow_up.png").Tab

        // editable sliders
        local treeHeight = vgui.Create("DNumSlider", scrollPanel)
        treeHeight:SetPos(0, 0)
        treeHeight:SetSize(410, 15)
        treeHeight:SetText("Tree Size")
        treeHeight:SetMinMax(1, 10)
        treeHeight:SetValue(options.treeHeight)
        treeHeight:SetDecimals(1)
        treeHeight:SetDark(true)
        function treeHeight:OnValueChanged(val)
            options.treeHeight = val
        end

        local treeResolution = vgui.Create("DNumSlider", scrollPanel)
        treeResolution:SetPos(0, 25)
        treeResolution:SetSize(410, 15)
        treeResolution:SetText("Tree Amount (x*x res per chunk)")
        treeResolution:SetMinMax(0, 20)
        treeResolution:SetValue(options.treeResolution)
        treeResolution:SetDecimals(0)
        treeResolution:SetDark(true)
        function treeResolution:OnValueChanged(val)
            options.treeResolution = math.Round(val)
        end

        local treeThreshold = vgui.Create("DNumSlider", scrollPanel)
        treeThreshold:SetPos(0, 50)
        treeThreshold:SetSize(410, 15)
        treeThreshold:SetText("Tree Slope Threshold")
        treeThreshold:SetMinMax(0, 1)
        treeThreshold:SetValue(options.treeThreshold)
        treeThreshold:SetDecimals(3)
        treeThreshold:SetDark(true)
        function treeThreshold:OnValueChanged(val)
            options.treeThreshold = val
        end

        local grassSize = vgui.Create("DNumSlider", scrollPanel)
        grassSize:SetPos(0, 100)
        grassSize:SetSize(410, 15)
        grassSize:SetText("Grass Size")
        grassSize:SetMinMax(5, 100)
        grassSize:SetValue(options.grassSize)
        grassSize:SetDecimals(0)
        grassSize:SetDark(true)
        function grassSize:OnValueChanged(val)
            options.grassSize = val
        end

        local grassCheckbox = vgui.Create("DCheckBoxLabel", scrollPanel)
        grassCheckbox:SetPos(0, 125)
        grassCheckbox:SetSize(16, 16)
        grassCheckbox:SetText("Generate Grass?")
        grassCheckbox:SetValue(options.generateGrass)
        grassCheckbox:SetTextColor(Color(0, 0, 0))
        function grassCheckbox:OnChange(val)
            options.generateGrass = val and true
        end
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
        customChoices:SetText("Custom Terrain Functions")
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
        customChoices:AddChoice("Basic Perlin Implementation", "return Simplex.Noise2D(x / 3, y / 3) * 10 + Simplex.Noise2D(x, y)")
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

    local function waterTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Water", scrollPanel, "icon16/water.png").Tab

        local waterEnabled
        local waterHeight = vgui.Create("DNumSlider", scrollPanel)
        waterHeight:SetPos(0, 25)
        waterHeight:SetSize(410, 15)
        waterHeight:SetText("Water Height")
        waterHeight:SetMinMax(-12765, 12765)
        waterHeight:SetValue(options.waterHeight or 0)
        waterHeight:SetDecimals(0)
        waterHeight:SetDark(true)
        function waterHeight:OnValueChanged(val)
            options.waterHeight = val
            Terrain.Variables.temp_waterHeight = val
            waterEnabled:SetValue(true)
        end

        waterEnabled = vgui.Create("DCheckBoxLabel", scrollPanel)
        waterEnabled:SetPos(0, 0)
        waterEnabled:SetSize(16, 16)
        waterEnabled:SetText("Enable Water?")
        waterEnabled:SetValue(options.waterHeight and true or false)
        waterEnabled:SetTextColor(Color(0, 0, 0))
        function waterEnabled:OnChange(val)
            if val then 
                options.waterHeight = waterHeight:GetValue()
                Terrain.Variables.temp_waterHeight = waterHeight:GetValue()
            else
                Terrain.Variables.temp_waterHeight = -math.huge
                options.waterHeight = nil
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

        changedTerrain = true
    end
end)