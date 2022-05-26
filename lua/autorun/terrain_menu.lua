AddCSLuaFile()
if SERVER then return end

concommand.Add("terrain_menu", function()
    local changedTerrain = false
    local editedValues = Terrain.MathFuncVariables

    -- start creating visual design
    local mainFrame = vgui.Create("DFrame")
    mainFrame:SetSize(800, 400)
    mainFrame:SetTitle("Terrain Menu")
    mainFrame:Center()
    mainFrame:MakePopup()
    function mainFrame:OnClose()
        if changedTerrain then
            for k, v in ipairs(ents.FindByClass("terrain_chunk")) do
                --v:BuildCollision()
                v:GenerateMesh()
                v:GenerateTrees()
            end
        end
        Terrain.MathFuncVariables = editedValues
    end

    -- the tabs
    local tabsFrame = vgui.Create("DPanel", mainFrame)
    tabsFrame:SetSize(425, 365)
    tabsFrame:SetPos(370, 30)
    tabsFrame.Paint = nil

    -- the mountain tab, contains the submit & test buttons & height modifiers
    local function mountainTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Mountains", scrollPanel, "icon16/world_edit.png").Tab

        -- editable sliders
        local heightSlider = vgui.Create("DNumSlider", scrollPanel)
        heightSlider:SetPos(0, 0)
        heightSlider:SetSize(410, 15)
        heightSlider:SetText("Mountain Height")
        heightSlider:SetMinMax(0, 200)
        heightSlider:SetValue(editedValues.height)
        heightSlider:SetDecimals(1)
        heightSlider:SetDark(true)
        function heightSlider:OnValueChanged(val)
            editedValues.height = val
        end

        local noiseScaleSlider = vgui.Create("DNumSlider", scrollPanel)
        noiseScaleSlider:SetPos(0, 25)
        noiseScaleSlider:SetSize(410, 15)
        noiseScaleSlider:SetText("Mountain Size")
        noiseScaleSlider:SetMinMax(1, 25)
        noiseScaleSlider:SetValue(editedValues.noiseScale)
        noiseScaleSlider:SetDecimals(1)
        noiseScaleSlider:SetDark(true)
        function noiseScaleSlider:OnValueChanged(val)
            editedValues.noiseScale = val
        end

        local offsetSlider = vgui.Create("DNumSlider", scrollPanel)
        offsetSlider:SetPos(0, 50)
        offsetSlider:SetSize(410, 15)
        offsetSlider:SetText("Terrain Z Offset")
        offsetSlider:SetMinMax(0, 100)
        offsetSlider:SetValue(editedValues.offset)
        offsetSlider:SetDecimals(1)
        offsetSlider:SetDark(true)
        function offsetSlider:OnValueChanged(val)
            editedValues.offset = val
        end

        local seedSlider = vgui.Create("DNumSlider", scrollPanel)
        seedSlider:SetPos(0, 75)
        seedSlider:SetSize(410, 15)
        seedSlider:SetText("Terrain Seed")
        seedSlider:SetMinMax(0, 2^32)
        seedSlider:SetValue(editedValues.seed)
        seedSlider:SetDecimals(0)
        seedSlider:SetDark(true)
        function seedSlider:OnValueChanged(val)
            editedValues.seed = val
        end

        local clampBox = vgui.Create("DCheckBoxLabel", scrollPanel)
        clampBox:SetPos(0, 100)
        clampBox:SetSize(16, 16)
        clampBox:SetText("Clamp Noise? (0 to 1 instead of -1 to 1)")
        clampBox:SetValue(editedValues.clampNoise)
        clampBox:SetTextColor(Color(0, 0, 0))
        function clampBox:OnChange(val)
            editedValues.clampNoise = val
        end

        local spawnBox = vgui.Create("DCheckBoxLabel", scrollPanel)
        spawnBox:SetPos(0, 125)
        spawnBox:SetSize(16, 16)
        spawnBox:SetText("Leave Space for Flatgrass Building?")
        spawnBox:SetValue(editedValues.spawnArea)
        spawnBox:SetTextColor(Color(0, 0, 0))
        function spawnBox:OnChange(val)
            editedValues.spawnArea = val
        end
    end

    -- the mountain tab, contains the submit & test buttons & height modifiers
    local function treeTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Foliage", scrollPanel, "icon16/arrow_up.png").Tab

        -- editable sliders
        local treeHeight = vgui.Create("DNumSlider", scrollPanel)
        treeHeight:SetPos(0, 0)
        treeHeight:SetSize(410, 15)
        treeHeight:SetText("Tree Size")
        treeHeight:SetMinMax(1, 10)
        treeHeight:SetValue(editedValues.treeHeight)
        treeHeight:SetDecimals(1)
        treeHeight:SetDark(true)
        function treeHeight:OnValueChanged(val)
            editedValues.treeHeight = val
        end

        local treeResolution = vgui.Create("DNumSlider", scrollPanel)
        treeResolution:SetPos(0, 25)
        treeResolution:SetSize(410, 15)
        treeResolution:SetText("Tree Amount (x*x res per chunk)")
        treeResolution:SetMinMax(0, 20)
        treeResolution:SetValue(editedValues.treeResolution)
        treeResolution:SetDecimals(0)
        treeResolution:SetDark(true)
        function treeResolution:OnValueChanged(val)
            editedValues.treeResolution = math.Round(val)
        end

        local treeThreshold = vgui.Create("DNumSlider", scrollPanel)
        treeThreshold:SetPos(0, 50)
        treeThreshold:SetSize(410, 15)
        treeThreshold:SetText("Tree Slope Threshold")
        treeThreshold:SetMinMax(0, 1)
        treeThreshold:SetValue(editedValues.treeThreshold)
        treeThreshold:SetDecimals(3)
        treeThreshold:SetDark(true)
        function treeThreshold:OnValueChanged(val)
            editedValues.treeThreshold = val
        end

        local grassSize = vgui.Create("DNumSlider", scrollPanel)
        grassSize:SetPos(0, 100)
        grassSize:SetSize(410, 15)
        grassSize:SetText("Grass Size")
        grassSize:SetMinMax(5, 100)
        grassSize:SetValue(editedValues.grassSize)
        grassSize:SetDecimals(0)
        grassSize:SetDark(true)
        function grassSize:OnValueChanged(val)
            editedValues.grassSize = val
        end

        local grassCheckbox = vgui.Create("DCheckBoxLabel", scrollPanel)
        grassCheckbox:SetPos(0, 125)
        grassCheckbox:SetSize(16, 16)
        grassCheckbox:SetText("Generate Grass?")
        grassCheckbox:SetValue(editedValues.generateGrass)
        grassCheckbox:SetTextColor(Color(0, 0, 0))
        function grassCheckbox:OnChange(val)
            editedValues.generateGrass = val and true
        end
    end

    local function functionTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Custom", scrollPanel, "icon16/application_xp_terminal.png").Tab

        local funcText = vgui.Create("DLabel", scrollPanel)
        funcText:SetPos(0, 30)
        funcText:SetSize(410, 16)
        funcText:SetColor(Color(0, 0, 0))
        funcText:SetText("Optional Custom GLua Height Function (Must return a number!)")

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
        func:SetText(editedValues.customFunction or "")
        function func:OnChange()
            editedValues.customFunction = nil
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
                        editedValues.customFunction = func:GetValue()
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
        customChoices:AddChoice("Mee Graph", "local values = \n{1,1,0,0,0,1,1,0,0,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,0,0,1,1,1,0,1,1,1,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,1,1,1,1,1,0,0,0,0,1,1,1,1,1,0,0,0,1,1,0,1,0,1,1,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,1,1,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0,1,1,0,0,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,0,0}\nlocal localX = -floor(((x * 4) - 26) / 2)\nlocal localY = (floor((y + 5) * 2) * 26)\nif localX < 0 or localX > 26 then\nreturn 0\nend\nreturn (values[localX + localY] or 0) * 10")
        function customChoices:OnSelect(index, text, data)
            func:SetText(data)
            func:OnChange()
        end

        local spawnBox = vgui.Create("DCheckBoxLabel", scrollPanel)
        spawnBox:SetPos(207, 3)
        spawnBox:SetSize(16, 16)
        spawnBox:SetText("Leave Space for Flatgrass Building?")
        spawnBox:SetValue(editedValues.spawnArea)
        spawnBox:SetTextColor(Color(0, 0, 0))
        function spawnBox:OnChange(val)
            editedValues.spawnArea = val
        end
    end

    local function settingsTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Client Settings", scrollPanel, "icon16/page_white_gear.png").Tab

        local lodDistance = vgui.Create("DNumSlider", scrollPanel)
        lodDistance:SetPos(0, 0)
        lodDistance:SetSize(410, 15)
        lodDistance:SetText("LOD Distance (in hammer units)")
        lodDistance:SetMinMax(0, 10000)
        lodDistance:SetValue(math.sqrt(Terrain.LODDistance))
        lodDistance:SetDecimals(0)
        lodDistance:SetDark(true)
        function lodDistance:OnValueChanged(val)
            Terrain.LODDistance = val^2
        end
    end

    -- minimap ortho view
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
    -- ortho zoom slider
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
    settingsTab(tabs)
    

    -- test & submit changes button
    local submitButton = vgui.Create("DButton", tabsFrame)
    submitButton:SetPos(250, 305)
    submitButton:SetSize(150, 50)
    submitButton:SetIcon("models/weapons/v_slam/new light1")
    submitButton:SetText("     Submit Changes")
    function submitButton:DoClick()
        if !LocalPlayer():IsSuperAdmin() then return end
        net.Start("TERRAIN_SEND_DATA")
        net.WriteTable(editedValues)    -- writetable since value types may change during development
        net.SendToServer()
        changedTerrain = false
    end

    local testButton = vgui.Create("DButton", tabsFrame)
    testButton:SetPos(10, 305)
    testButton:SetSize(150, 50)
    testButton:SetIcon("models/weapons/v_slam/new light2")
    testButton:SetText("Test Changes")
    function testButton:DoClick() 
        local newFunction = Terrain.BuildMathFunc(editedValues)

        -- reload all chunks with the new function
        for k, v in ipairs(ents.FindByClass("terrain_chunk")) do
            --v:BuildCollision(newFunction) -- this shit crashes u
            v:GenerateMesh(newFunction)
            v:GenerateTrees(newFunction, editedValues)
            v:SetRenderBounds(v:OBBMins() * Vector(1, 1, -1), v:OBBMaxs() + Vector(0, 0, 1000))
        end

        changedTerrain = true
    end
end)