local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func) 
    return func 
end)

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles

if typeof(clonefunction) == "function" then
    local
        isfolder_copy,
        isfile_copy,
        listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)

    local isfolder_success, isfolder_result = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if not isfolder_success or typeof(isfolder_result) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            return (if success then data else false)
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            return (if success then data else false)
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            return (if success then data else {})
        end
    end
end

local saveManagerChunkOk, saveManagerChunkResult = pcall(function()

local SaveManager = {} do
    SaveManager.Folder = "MidgardLibSettings"
    SaveManager.Ignore = {
        ["BackgroundColor"] = true, ["MainColor"] = true, ["AccentColor"] = true, ["OutlineColor"] = true, 
        ["FontColor"] = true, ["FontFace"] = true, ["ToggleColor"] = true, ["SliderColor"] = true,
    }
    SaveManager.IgnoreExport = {}
    SaveManager.Library = nil
    SaveManager.CustomSave = nil
    SaveManager.CustomLoad = nil
    SaveManager.CustomValidate = nil
    SaveManager.CurrentConfig = nil
    SaveManager.ManualAutoload = nil
    SaveManager.ConfigVersion = nil
    SaveManager.UseCustomStateAsPrimary = false
    SaveManager.AutoSaveDebounce = 1
    SaveManager.PendingLoads = {}
    SaveManager.PendingLoadWorker = nil
    SaveManager.AutoSaveDirty = false
    SaveManager._autoSaveTimer = nil

    do
        local ok, plr = pcall(function()
            return game:GetService("Players").LocalPlayer
        end)
        SaveManager.SubFolder = (ok and plr and plr.Name) or ""
    end

    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = "Toggle", idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                local lib = SaveManager.Library
                if not (lib and lib.Toggles) then return end
                local object = lib.Toggles[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = "Slider", idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                local lib = SaveManager.Library
                if not (lib and lib.Options) then return end
                local object = lib.Options[idx]
                local numValue = tonumber(data.value)
                if object and numValue ~= nil and object.Value ~= numValue then
                    object:SetValue(numValue)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                local value = object.Value
                local label = nil
                local entries = nil
                if object.SpecialType == "Player" then
                    if object.Multi then
                        local names = {}
                        for k, v in pairs(value or {}) do
                            if typeof(k) == "Instance" and k:IsA("Player") then
                                names[k.Name] = v
                            else
                                names[tostring(k)] = v
                            end
                        end
                        value = names
                    else
                        if typeof(value) == "Instance" and value:IsA("Player") then
                            value = value.Name
                        end
                    end
                elseif object.Multi then
                    entries = {}
                    for selectedValue, active in pairs(value or {}) do
                        if active then
                            table.insert(entries, {
                                value = selectedValue,
                                label = tostring(selectedValue),
                            })
                        end
                    end
                else
                    label = value ~= nil and tostring(value) or nil
                end

                return {
                    type = "Dropdown",
                    idx = idx,
                    value = value,
                    label = label,
                    entries = entries,
                    multi = object.Multi,
                }
            end,
            Load = function(idx, data)
                local lib = SaveManager.Library
                if not (lib and lib.Options) then return end
                local object = lib.Options[idx]
                if not object then return end

                local function resolveSingleDropdownValue(rawValue, fallbackLabel)
                    if rawValue == nil then
                        return nil
                    end

                    if table.find(object.Values, rawValue) then
                        return rawValue
                    end

                    if fallbackLabel ~= nil then
                        for _, candidate in ipairs(object.Values or {}) do
                            if tostring(candidate) == tostring(fallbackLabel) then
                                return candidate
                            end
                        end
                    end

                    return rawValue
                end

                local function resolveMultiDropdownValue(rawTable, fallbackEntries)
                    local resolved = {}

                    if typeof(rawTable) == "table" then
                        for rawKey, active in pairs(rawTable) do
                            local candidate = nil
                            if table.find(object.Values, rawKey) then
                                candidate = rawKey
                            else
                                for _, optionValue in ipairs(object.Values or {}) do
                                    if tostring(optionValue) == tostring(rawKey) then
                                        candidate = optionValue
                                        break
                                    end
                                end
                            end

                            if candidate ~= nil and active then
                                resolved[candidate] = true
                            end
                        end
                    end

                    if typeof(fallbackEntries) == "table" then
                        for _, entry in ipairs(fallbackEntries) do
                            local candidate = resolveSingleDropdownValue(entry.value, entry.label)
                            if candidate ~= nil then
                                resolved[candidate] = true
                            end
                        end
                    end

                    return resolved
                end

                local value = data.value
                if object.SpecialType == "Player" then
                    local Players = game:GetService("Players")
                    if data.multi then
                        if typeof(value) == "table" then
                            local resolved = {}
                            for name, v in pairs(value) do
                                local player = Players:FindFirstChild(tostring(name))
                                if player and player:IsA("Player") then
                                    resolved[player] = v
                                end
                            end
                            value = resolved
                        end
                    else
                        if typeof(value) == "string" and value ~= "" then
                            local player = Players:FindFirstChild(value)
                            if player and player:IsA("Player") then
                                value = player
                            else
                                return
                            end
                        end
                    end
                elseif data.multi then
                    value = resolveMultiDropdownValue(value, data.entries)
                else
                    value = resolveSingleDropdownValue(value, data.label)
                end

                if object.Value ~= value then
                    if type(object.SetPendingValue) == "function" then
                        object:SetPendingValue(value)
                    else
                        object:SetValue(value)
                    end
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                return { type = "KeyPicker", idx = idx, mode = object.Mode, key = object.Value, modifiers = object.Modifiers }
            end,
            Load = function(idx, data)
                local lib = SaveManager.Library
                if not (lib and lib.Options) then return end
                local object = lib.Options[idx]
                if object then
                    object:SetValue({ data.key, data.mode, data.modifiers or {} })
                end
            end,
        },
        Input = {
            Save = function(idx, object)
                return { type = "Input", idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                local lib = SaveManager.Library
                if not (lib and lib.Options) then return end
                local object = lib.Options[idx]
                if object and object.Value ~= data.text and type(data.text) == "string" then
                    object:SetValue(data.text)
                end
            end,
        },
    }

    -- Library Bind
    -- Stores the Library instance used for controls and config UI.
    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    -- Pending Load Queue
    -- Queues a control load until the target control exists.
    function SaveManager:QueuePendingLoad(option)
        if type(option) ~= "table" or type(option.idx) ~= "string" or option.idx == "" then
            return
        end

        self.PendingLoads[option.idx] = option
        self:StartPendingLoadWorker()
    end

    -- Pending Load Apply
    -- Replays queued loads against controls that are now available.
    function SaveManager:TryApplyPendingLoads()
        local lib = self.Library
        if not (lib and lib.Options and lib.Toggles) then
            return false
        end

        local appliedAny = false
        for idx, option in pairs(self.PendingLoads) do
            local optionType = option and option.type
            local parser = optionType and self.Parser[optionType]
            if not parser or self.Ignore[idx] then
                self.PendingLoads[idx] = nil
            else
                local object = if optionType == "Toggle" then lib.Toggles[idx] else lib.Options[idx]
                if object then
                    self.PendingLoads[idx] = nil
                    appliedAny = true
                    task.spawn(parser.Load, idx, option)
                end
            end
        end

        return appliedAny
    end

    -- Pending Load Worker
    -- Starts the retry worker that drains pending control loads.
    function SaveManager:StartPendingLoadWorker()
        if self.PendingLoadWorker then
            return
        end

        self.PendingLoadWorker = task.spawn(function()
            for _ = 1, 60 do
                self:TryApplyPendingLoads()

                if next(self.PendingLoads) == nil then
                    break
                end

                task.wait(0.25)
            end

            self.PendingLoadWorker = nil
        end)
    end

    -- Section Ignore
    -- Marks all controls in a section as ignored or restored.
    function SaveManager:IgnoreSection(section, shouldIgnore)
        if typeof(section) ~= "table" then return end

        local ignore = shouldIgnore ~= false
        local elements = section.Elements
        if typeof(elements) ~= "table" then return end

        for _, element in pairs(elements) do
            local idx = typeof(element) == "table" and element.Idx or nil
            if type(idx) == "string" and idx ~= "" then
                self.Ignore[idx] = ignore
            end
        end
    end

    --// Folders \\--
    -- Subfolder Check
    -- Resolves and optionally creates the configured subfolder.
    function SaveManager:CheckSubFolder(createFolder)
        if typeof(self.SubFolder) ~= "string" or self.SubFolder == "" then return false end

        if createFolder == true then
            if not isfolder(self.Folder .. "/settings/" .. self.SubFolder) then
                makefolder(self.Folder .. "/settings/" .. self.SubFolder)
            end
        end

        return true
    end

    -- Config Paths
    -- Returns the current settings and autoload paths.
    function SaveManager:GetPaths()
        local paths = {}

        local parts = self.Folder:split("/")
        for idx = 1, #parts do
            local path = table.concat(parts, "/", 1, idx)
            if not table.find(paths, path) then paths[#paths + 1] = path end
        end

        paths[#paths + 1] = self.Folder .. "/settings"

        if self:CheckSubFolder(false) then
            local subFolder = self.Folder .. "/settings/" .. self.SubFolder
            parts = subFolder:split("/")

            for idx = 1, #parts do
                local path = table.concat(parts, "/", 1, idx)
                if not table.find(paths, path) then paths[#paths + 1] = path end
            end
        end

        return paths
    end

    -- Folder Tree
    -- Builds the folder layout used by the save system.
    function SaveManager:BuildFolderTree()
        local paths = self:GetPaths()

        for i = 1, #paths do
            local str = paths[i]
            if isfolder(str) then continue end
            makefolder(str)
        end
    end

    -- Folder Check
    -- Ensures the save folder tree exists before file operations.
    function SaveManager:CheckFolderTree()
        if not isfolder(self.Folder) then
            makefolder(self.Folder)
        end

        local settingsPath = self.Folder .. "/settings"
        if not isfolder(settingsPath) then
            makefolder(settingsPath)
        end
    end

    -- Ignore Indexes
    -- Replaces the ignored control index list.
    function SaveManager:SetIgnoreIndexes(list)
        for _, key in pairs(list) do
            self.Ignore[key] = true
        end
    end

    -- Folder Set
    -- Sets the root save folder.
    function SaveManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    -- Subfolder Set
    -- Sets the nested save subfolder.
    function SaveManager:SetSubFolder(folder)
        self.SubFolder = folder
        self:BuildFolderTree()
    end

    -- Project Configure
    -- Applies project-specific save options and policies.
    function SaveManager:ConfigureProject(options)
        if type(options) ~= "table" then return end
        if options.Library then
            self:SetLibrary(options.Library)
        end
        if type(options.Folder) == "string" and options.Folder ~= "" then
            self:SetFolder(options.Folder)
        end
        if type(options.SubFolder) == "string" and options.SubFolder ~= "" then
            self:SetSubFolder(options.SubFolder)
        end
        if type(options.Ignore) == "table" then
            self:SetIgnoreIndexes(options.Ignore)
        end
        if type(options.IgnoreExport) == "table" then
            self:SetIgnoreExportIndexes(options.IgnoreExport)
        end
        if type(options.UseCustomStateAsPrimary) == "boolean" then
            self.UseCustomStateAsPrimary = options.UseCustomStateAsPrimary
        end
        if type(options.ConfigVersion) == "number" then
            self.ConfigVersion = options.ConfigVersion
        end
        if type(options.AutoSaveDebounce) == "number" and options.AutoSaveDebounce >= 0 then
            self.AutoSaveDebounce = options.AutoSaveDebounce
        end
    end

    -- Export Ignore
    -- Replaces the index list excluded from export.
    function SaveManager:SetIgnoreExportIndexes(list)
        for _, key in pairs(list) do
            self.IgnoreExport[key] = true
        end
    end

    -- Config Path
    -- Resolves the full path for a config name.
    function SaveManager:ResolvePath(name)
        if not name or name == "" then return nil end
        SaveManager:CheckFolderTree()

        local basePath = self.Folder .. "/settings/" .. name
        if SaveManager:CheckSubFolder(true) then
            basePath = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name
        end

        return basePath
    end

    -- State Serialize
    -- Builds the save payload for the current config state.
    -- In custom-primary mode, only the current custom format is supported.
    function SaveManager:SerializeCurrentState(name)
        local data = self.UseCustomStateAsPrimary and {} or { objects = {} }
        local lib = self.Library
        if not lib then return false, "library not set" end

        if not self.UseCustomStateAsPrimary then
            for idx, option in pairs(lib.Options) do
                local optionType = option.type or option.Type
                if not self.Parser[optionType] then continue end
                if self.Ignore[idx] then continue end
                if name ~= "autosave" and self.IgnoreExport[idx] then continue end
                table.insert(data.objects, self.Parser[optionType].Save(idx, option))
            end

            for idx, toggle in pairs(lib.Toggles) do
                if self.Ignore[idx] then continue end
                if name ~= "autosave" and self.IgnoreExport[idx] then continue end
                table.insert(data.objects, self.Parser.Toggle.Save(idx, toggle))
            end
        end

        if self.CustomSave then
            local ok, custom = pcall(self.CustomSave)
            if ok and custom then data.custom = custom end
        end

        if type(self.ConfigVersion) == "number" then
            data.Version = self.ConfigVersion
        end

        return true, data
    end

    -- Config I/O
    -- Config Save
    -- Writes the current config payload to disk.
    function SaveManager:Save(name, silent)
        if not name then
            return false, "no config file is selected"
        end
        SaveManager:CheckFolderTree()

        local fullPath = self.Folder .. "/settings/" .. name .. ".json"
        if SaveManager:CheckSubFolder(true) then
            fullPath = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. ".json"
        end

        local data = self.UseCustomStateAsPrimary and {} or { objects = {} }

        local lib = self.Library
        if not lib then return false, "library not set" end

        if not self.UseCustomStateAsPrimary then
            for idx, option in pairs(lib.Options) do
                if not self.Parser[option.type] then continue end
                if self.Ignore[idx] then continue end
                table.insert(data.objects, self.Parser[option.type].Save(idx, option))
            end

            for idx, toggle in pairs(lib.Toggles) do
                if self.Ignore[idx] then continue end
                table.insert(data.objects, self.Parser.Toggle.Save(idx, toggle))
            end
        end

        if self.CustomSave then
            local ok, custom = pcall(self.CustomSave)
            if ok and custom then data.custom = custom end
        end

        if type(self.ConfigVersion) == "number" then
            data.Version = self.ConfigVersion
        end

        local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not success then
            return false, "failed to encode data"
        end

        local successWrite, err = pcall(writefile, fullPath, encoded)
        if not successWrite then
            return false, "failed to write file: " .. tostring(err)
        end

        if not silent then
            self.CurrentConfig = name
        end

        return true
    end

    -- Config Import
    -- Loads config data from raw JSON text.
    -- In custom-primary mode, this only accepts the current `custom` payload format.
    function SaveManager:LoadConfigData(rawText)
        if type(rawText) ~= "string" or rawText:gsub("%s+", "") == "" then
            return false, "empty config text"
        end

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, rawText)
        if not success or type(decoded) ~= "table" then
            return false, "invalid config json"
        end

        if not self.UseCustomStateAsPrimary and type(decoded.objects) == "table" then
            for _, option in pairs(decoded.objects) do
                local optionType = option and option.type
                if not optionType then continue end
                if not self.Parser[optionType] then continue end
                if self.Ignore[option.idx] then continue end
                local object = if optionType == "Toggle" then self.Library.Toggles[option.idx] else self.Library.Options[option.idx]
                if object then
                    task.spawn(self.Parser[optionType].Load, option.idx, option)
                else
                    self:QueuePendingLoad(option)
                end
            end
        end

        local customPayload = decoded.custom
        if self.UseCustomStateAsPrimary and type(customPayload) ~= "table" then
            return false, "invalid custom config"
        end

        if self.CustomValidate and customPayload then
            local ok, valid, err = pcall(self.CustomValidate, customPayload)
            if not ok then
                return false, "custom config validation failed"
            end
            if valid == false then
                return false, err or "invalid custom config"
            end
        end

        if self.CustomLoad and customPayload then
            task.spawn(self.CustomLoad, customPayload)
        end

        return true
    end

    -- Config Export
    -- Copies the current config payload to the clipboard.
    function SaveManager:ExportToClipboard()
        if typeof(setclipboard) ~= "function" then
            return false, "clipboard unavailable"
        end

        local success, data = self:SerializeCurrentState("export")
        if not success then
            return false, data
        end

        local encodedSuccess, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not encodedSuccess then
            return false, "failed to encode config"
        end

        local clipboardSuccess, clipboardErr = pcall(setclipboard, encoded)
        if not clipboardSuccess then
            return false, tostring(clipboardErr)
        end

        return true
    end

    -- Config Load
    -- Loads a config file from disk and applies it.
    -- In custom-primary mode, legacy config layouts are not supported.
    function SaveManager:Load(name)
        if not name then
            return false, "no config file is selected"
        end
        SaveManager:CheckFolderTree()

        local file = self.Folder .. "/settings/" .. name .. ".json"
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. ".json"
        end

        if not isfile(file) then return false, "invalid file" end

        self.CurrentConfig = name

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
        if not success or type(decoded) ~= "table" then return false, "decode error" end

        if not self.UseCustomStateAsPrimary and type(decoded.objects) == "table" then
            for _, option in pairs(decoded.objects) do
                if not option.type then continue end
                if not self.Parser[option.type] then continue end
                if self.Ignore[option.idx] then continue end
                local object = if option.type == "Toggle" then self.Library.Toggles[option.idx] else self.Library.Options[option.idx]
                if object then
                    task.spawn(self.Parser[option.type].Load, option.idx, option)
                else
                    self:QueuePendingLoad(option)
                end
            end
        end

        local customPayload = decoded.custom
        if self.UseCustomStateAsPrimary and type(customPayload) ~= "table" then
            return false, "invalid custom config"
        end

        if self.CustomValidate and customPayload then
            local ok, valid, err = pcall(self.CustomValidate, customPayload)
            if not ok then
                return false, "custom config validation failed"
            end
            if valid == false then
                return false, err or "invalid custom config"
            end
        end

        if self.CustomLoad and customPayload then
            task.spawn(self.CustomLoad, customPayload)
        end

        self:SaveAutoSaveMetadata()

        return true
    end

    -- Config Delete
    -- Deletes a config file from disk.
    function SaveManager:Delete(name)
        if not name then
            return false, "no config file is selected"
        end

        local file = self.Folder .. "/settings/" .. name .. ".json"
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. ".json"
        end

        if not isfile(file) then return false, "invalid file" end

        local success = pcall(delfile, file)
        if not success then return false, "delete file error" end

        if self:GetAutoloadConfig() == name then
            self:DeleteAutoLoadConfig()
            if self.AutoloadConfigLabel then
                self.AutoloadConfigLabel:SetVisible(false)
            end
        end

        return true
    end

    -- Config List
    -- Reads and returns the available config names.
    function SaveManager:RefreshConfigList()
        local success, data = pcall(function()
            SaveManager:CheckFolderTree()

            local list = {}
            local out = {}

            if SaveManager:CheckSubFolder(true) then
                list = listfiles(self.Folder .. "/settings/" .. self.SubFolder)
            else
                list = listfiles(self.Folder .. "/settings")
            end
            if typeof(list) ~= "table" then list = {} end

            for i = 1, #list do
                local file = list[i]
                local name = type(file) == "string" and file:match("([^/\\]+)%.json$")
                if name then
                    table.insert(out, name)
                end
            end

            return out
        end)

        if not success then
            warn("Failed to Load Config List: " .. tostring(data))
            return {}
        end

        return data
    end

    -- Autoload
    -- Autoload Read
    -- Reads the currently configured autoload entry.
    function SaveManager:GetAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                return "none"
            end
            return if name == "" or name == "none" then "" else name
        end

        return ""
    end

    -- Autoload Load
    -- Loads the config referenced by the autoload file.
    function SaveManager:LoadAutoloadConfig()
        SaveManager:CheckFolderTree()

        local path = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            path = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(path) then
            local successRead, name = pcall(readfile, path)
            if not successRead then return end

            name = name:gsub("^%s*(.-)%s*$", "%1")
            if name == "" then return end

            local success, err = self:Load(name)
            if not success then
                warn("Failed to Load Autoload Config: " .. tostring(err))
            end
        end
    end

    -- Autoload Save
    -- Writes the autoload target and syncs metadata.
    function SaveManager:SaveAutoloadConfig(name, preserveAutoSave)
        SaveManager:CheckFolderTree()

        -- Manual autoload selection disables autosave to avoid two competing config sources.
        local lib = self.Library
        if not preserveAutoSave and lib and lib.Toggles.SaveManager_AutoSave and lib.Toggles.SaveManager_AutoSave.Value then
            lib.Toggles.SaveManager_AutoSave:SetValue(false)
        end

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(writefile, autoLoadPath, name)
        if not success then return false, "write file error" end

        -- Set ManualAutoload (independent from AutoSave's CurrentConfig)
        if name and name ~= "none" and name ~= "" then
            self.ManualAutoload = name
            self:SaveAutoSaveMetadata()
        end

        return true, ""
    end

    -- Autoload Clear
    -- Removes the autoload file and clears metadata.
    function SaveManager:DeleteAutoLoadConfig()
        local path = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            path = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        -- Always delete the file to keep it in sync with ManualAutoload = nil
        if isfile(path) then
            local success, err = pcall(delfile, path)
            if not success then return false, err end
        end

        self.ManualAutoload = nil
        local autoSaveEnabled = self.Library
            and self.Library.Toggles
            and self.Library.Toggles.SaveManager_AutoSave
            and self.Library.Toggles.SaveManager_AutoSave.Value == true
        if not autoSaveEnabled then
            self.CurrentConfig = nil
        end
        self:SaveAutoSaveMetadata()

        return true
    end

    -- Autoload Label
    -- Refreshes the label that shows the active autoload target.
    function SaveManager:UpdateAutoloadLabel(name)
        if not self.AutoloadConfigLabel then return end
        local text = (name == nil or name == "" or name == "none") and "" or ("Autoload: " .. tostring(name))
        self.AutoloadConfigLabel:SetText(text)
        self.AutoloadConfigLabel:SetVisible(text ~= "")
    end

    -- Autosave Policy
    -- Enables or disables autosave and syncs autoload behavior.
    function SaveManager:ApplyAutoSavePolicy(enabled)
        if self.LoadingMetadata then
            self:SaveAutoSaveMetadata()
            return true
        end

        if enabled then
            self:CancelAutoSaveTimer()
            self.CurrentConfig = "autosave"
            local saveSuccess, saveErr = self:Save("autosave")
            if not saveSuccess then
                return false, saveErr
            end
            local autoloadSuccess, autoloadErr = self:SaveAutoloadConfig("autosave", true)
            if not autoloadSuccess then
                return false, autoloadErr
            end
            self:UpdateAutoloadLabel("autosave")
        else
            self:CancelAutoSaveTimer()
            local deleteSuccess, deleteErr = self:DeleteAutoLoadConfig()
            if not deleteSuccess then
                return false, deleteErr
            end
            self.CurrentConfig = nil
            self:UpdateAutoloadLabel("")
        end

        self:SaveAutoSaveMetadata()
        return true
    end

    -- Config Reset
    -- Restores controls to their default values.
    function SaveManager:ResetConfig()
        for idx, toggle in pairs(self.Library.Toggles) do
            if self.Ignore[idx] then continue end
            local defaultVal = toggle.InitialValue
            if defaultVal == nil then defaultVal = toggle.Default end
            if defaultVal ~= nil then
                toggle:SetValue(defaultVal)
            end
        end

        for idx, option in pairs(self.Library.Options) do
            if self.Ignore[idx] then continue end
            local defaultVal = option.InitialValue
            if defaultVal == nil then defaultVal = option.Default end
            if defaultVal ~= nil then
                if option.Type == "Dropdown" then
                    if type(defaultVal) == "table" and not option.Multi then
                        -- Dropdown.Default stores an array of indices. Convert the first index to its value.
                        local firstIndex = defaultVal[1]
                        if firstIndex and option.Values and option.Values[firstIndex] then
                            option:SetValue(option.Values[firstIndex])
                        else
                            option:SetValue(nil)
                        end
                    elseif type(defaultVal) == "table" and option.Multi then
                        local mapped = {}
                        for _, idxVal in pairs(defaultVal) do
                            if type(idxVal) == "number" and option.Values and option.Values[idxVal] then
                                mapped[option.Values[idxVal]] = true
                            elseif type(idxVal) == "string" then
                                mapped[idxVal] = true
                            end
                        end
                        option:SetValue(mapped)
                    else
                        option:SetValue(defaultVal)
                    end
                elseif option.Type == "KeyPicker" then
                    option:SetValue({ defaultVal, option.Mode, option.DefaultModifiers })
                else
                    option:SetValue(defaultVal)
                end
            end
        end
    end

    -- Config Section
    -- Builds the managed configuration controls in the UI.
    function SaveManager:BuildManagedConfigSection(tab)
        assert(self.Library, "Must set SaveManager.Library")

        local section = tab

        section:AddToggle("SaveManager_AutoSave", { Text = "Save Configuration", Default = false }):OnChanged(function()
            local success, err = self:ApplyAutoSavePolicy(self.Library.Toggles.SaveManager_AutoSave.Value)
            if not success then
                warn("Failed to Update Autosave: " .. tostring(err))
            end
        end)

        section:AddDivider()

        section:AddInput("SaveManager_ConfigName", { Text = "Configuration Name" })
        section:AddButton("Create", function()
            local name = self.Library.Options.SaveManager_ConfigName.Value

            if name:gsub(" ", "") == "" then
                warn("Invalid Config Name (Empty)")
                return
            end

            local success, err = self:Save(name)
            if not success then
                warn("Failed to Create Config: " .. tostring(err))
                return
            end

            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end):AddButton("Reset", function()
            self:ResetConfig()
        end)

        section:AddDropdown("SaveManager_ConfigList", { Text = "Configuration List", Values = self:RefreshConfigList(), AllowNull = true })
        section:AddButton("Load", function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Load(name)
            if not success then
                warn("Failed to Load Config: " .. tostring(err))
                return
            end

        end):AddButton("Overwrite", function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Save(name)
            if not success then
                warn("Failed to Overwrite Config: " .. tostring(err))
                return
            end
        end)

        section:AddButton("Refresh", function()
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end):AddButton("Delete", function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Delete(name)
            if not success then
                warn("Failed to Delete Config: " .. tostring(err))
                return
            end

            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton("Set Autoload", function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:SaveAutoloadConfig(name)
            if not success then
                warn("Failed to Set Autoload Config: " .. tostring(err))
                return
            end

            self:UpdateAutoloadLabel(name)
        end):AddButton("Reset Autoload", function()
            local success, err = self:DeleteAutoLoadConfig()
            if not success then
                warn("Failed to Reset Autoload Config: " .. tostring(err))
                return
            end

            self:UpdateAutoloadLabel("")
        end)

        self.AutoloadConfigLabel = section:AddLabel("", false, true)
        self:UpdateAutoloadLabel(self:GetAutoloadConfig())

        section:AddDivider()
        section:AddInput("Config_Paste_Box", { Text = "Paste Configuration", Placeholder = "JSON Code..." })
        section:AddButton("Import", function()
            local text = self.Library.Options.Config_Paste_Box and self.Library.Options.Config_Paste_Box.Value or ""
            local success, err = self:LoadConfigData(text)
            if not success then
                warn("Failed to Import Config: " .. tostring(err))
                return
            end
        end):AddButton("Export", function()
            local success, err = self:ExportToClipboard()
            if not success then
                warn("Failed to Export Config: " .. tostring(err))
                return
            end
        end)

        self:LoadAutoSaveMetadata()
        self:Initialize()
        self:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName", "SaveManager_AutoSave", "Config_Paste_Box" })
    end

    -- Config Section Alias
    -- Keeps compatibility with the older config section entry point.
    function SaveManager:BuildConfigSection(tab)
        return self:BuildManagedConfigSection(tab)
    end

    -- Autosave Cancel
    -- Cancels the pending autosave timer.
    function SaveManager:CancelAutoSaveTimer(clearDirty)
        if self._autoSaveTimer then
            pcall(task.cancel, self._autoSaveTimer)
            self._autoSaveTimer = nil
        end
        if clearDirty ~= false then
            self.AutoSaveDirty = false
        end
    end

    -- Autosave Flush
    -- Writes the pending autosave immediately when allowed.
    function SaveManager:FlushAutoSave()
        local toggle = self.Library and self.Library.Toggles and self.Library.Toggles.SaveManager_AutoSave
        self._autoSaveTimer = nil

        if self.LoadingMetadata or not self.AutoSaveDirty or not (toggle and toggle.Value) then
            return false
        end

        self.AutoSaveDirty = false
        self.CurrentConfig = "autosave"
        local ok, err = self:Save("autosave", true)
        if ok then
            self:SaveAutoSaveMetadata()
        end

        return ok, err
    end

    -- Autosave Schedule
    -- Schedules a debounced autosave write.
    function SaveManager:ScheduleAutoSave()
        local toggle = self.Library and self.Library.Toggles and self.Library.Toggles.SaveManager_AutoSave
        if self.LoadingMetadata or not (toggle and toggle.Value) then
            return
        end

        self:CancelAutoSaveTimer(false)
        local debounceDelay = tonumber(self.AutoSaveDebounce) or 1
        self._autoSaveTimer = task.delay(math.max(0, debounceDelay), function()
            self:FlushAutoSave()
        end)
    end

    -- Autosave Dirty
    -- Marks autosave state dirty and queues a flush.
    function SaveManager:MarkAutoSaveDirty()
        self.AutoSaveDirty = true
        self:ScheduleAutoSave()
    end

    -- SaveManager Init
    -- Hooks autosave listeners after the UI has been built.
    function SaveManager:Initialize()
        if self.Initialized then return end
        self.Initialized = true

        self.Library.OnObjectChanged.Event:Connect(function()
            local toggle = self.Library.Toggles.SaveManager_AutoSave
            if not self.LoadingMetadata and toggle and toggle.Value then
                self:MarkAutoSaveDirty()
            end
        end)
    end

    -- Autosave Metadata Save
    -- Persists autosave and autoload metadata to disk.
    function SaveManager:SaveAutoSaveMetadata()
        if self.LoadingMetadata then return end

        local lib = self.Library
        if not (lib and lib.Toggles) then return end

        local path = self.Folder .. "/settings/autosave_meta.json"
        self:CheckFolderTree()
        local data = {
            Enabled = (lib.Toggles.SaveManager_AutoSave and lib.Toggles.SaveManager_AutoSave.Value) or false,
            CurrentConfig = self.CurrentConfig,
            ManualAutoload = self.ManualAutoload or nil,
        }
        local encodedSuccess, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not encodedSuccess then return false, "failed to encode autosave metadata" end

        local writeSuccess, writeErr = pcall(writefile, path, encoded)
        if not writeSuccess then return false, "failed to write autosave metadata: " .. tostring(writeErr) end

        return true
    end

    -- Autosave Metadata Load
    -- Restores autosave and autoload metadata from disk.
    function SaveManager:LoadAutoSaveMetadata()
        local path = self.Folder .. "/settings/autosave_meta.json"
        if isfile(path) then
            local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(path))
            if success and type(decoded) == "table" then
                self.LoadingMetadata = true

                -- Restore ManualAutoload field
                self.ManualAutoload = (decoded.ManualAutoload ~= "" and decoded.ManualAutoload) or nil

                -- Priority: ManualAutoload (Set Autoload button) > CurrentConfig when AutoSave is enabled
                local configToLoad = self.ManualAutoload or ((decoded.Enabled == true) and decoded.CurrentConfig or nil)
                if configToLoad and configToLoad ~= "" then
                    self.CurrentConfig = configToLoad
                    local ok, err = self:Load(self.CurrentConfig)
                    if not ok then
                        if err == "invalid file" then
                            -- Clear whichever reference was stale
                            if self.ManualAutoload == configToLoad then
                                self.ManualAutoload = nil
                            end
                            self.CurrentConfig = nil
                            pcall(delfile, path)
                        else
                            warn("Failed to Restore Config: " .. tostring(err))
                        end
                    end
                end

                if decoded.Enabled ~= nil and self.Library.Toggles.SaveManager_AutoSave then
                    self.Library.Toggles.SaveManager_AutoSave:SetValue(decoded.Enabled)
                end

                self.LoadingMetadata = false

                -- Sync label with what was actually loaded
                if self.AutoloadConfigLabel then
                    local labelConfig = self.ManualAutoload or (decoded.Enabled and self.CurrentConfig) or nil
                    if labelConfig and labelConfig ~= "" then
                        self.AutoloadConfigLabel:SetText("Autoload: " .. labelConfig)
                        self.AutoloadConfigLabel:SetVisible(true)
                    else
                        self.AutoloadConfigLabel:SetVisible(false)
                    end
                end
            end
        end
    end

end

return SaveManager
end)

if not saveManagerChunkOk then
    warn("[Midgard - Save] Script Error:\n" .. tostring(saveManagerChunkResult))
end

return if saveManagerChunkOk then saveManagerChunkResult else nil
