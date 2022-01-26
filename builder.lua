--[[
    builder
]]

local function download_and_import_by_git(gitUrl, entryName, workingDir)
    local slashPos = string.find(string.reverse(gitUrl), "/", 1, true)
    local pointPos = string.find(string.reverse(gitUrl), ".", 1, true)
    assert(slashPos ~= nil and pointPos ~= nil and slashPos > pointPos, "[LUA_GIT_IMPORT] invalid url:" .. gitUrl)
    local folderName = "." .. string.sub(gitUrl, #gitUrl - slashPos + 2, #gitUrl - pointPos) .. "/"
    workingDir = workingDir or os.getenv("HOME")
    assert(workingDir ~= nil, "[LUA_GIT_IMPORT] working dir not found !")
    package.path = package.path .. ";" .. workingDir .. "/" .. folderName .. "?.lua"
    local isOk, err = pcall(require, entryName)
    if not isOk then
        print('[LUA_GIT_IMPORT] downloading ...')
        os.execute("git clone " .. gitUrl .. " " .. workingDir .. "/" .. folderName)
        isOk, err = pcall(require, entryName)
        assert(isOk, "[LUA_GIT_IMPORT] import failed:" .. tostring(err))
        print('[LUA_GIT_IMPORT] import succeeded!')
    end
end
download_and_import_by_git("git@github.com:kompasim/pure-lua-tools.git", "initialize", "./")

MY_PRINT_TAG = "[LUA_C_BUILDER]:"
MY_LIBRARY_PATH = files.csd() .. ".builder/"
KEYS = {
    NAME = "NAME",
    TYPE = "TYPE",
    URL = "URL",
    EXT = "EXT",
    BRANCH = "BRANCH",
    DIR_I = "DIR_I", -- -I
    DIR_L = "DIR_L", -- -L
    LIB_L = "LIB_L", -- -l
    FLAGS = "FLAGS", -- flags
}
TYPES = {
    GIT = "GIT",
    ZIP = "ZIP",
}
require("configs")

local Builder = class("Builder")

function Builder:__init__(isDebug, needPullGit)
    print('\n-----------------[Lua C Builder]---------------------\n')
    self._isDebug = isDebug == true
    self._needPullGit = needPullGit == true
    self._includeDirs = {}
    self._linkingDirs = {}
    self._linkingTags = {}
    self._extraFlags = {}
    self._executableFile = nil
end

function Builder:print(...)
    print(MY_PRINT_TAG, ...)
end

function Builder:assert(v, msg)
    assert(v, string.format("%s%s", MY_PRINT_TAG, msg))
end

function Builder:error(msg)
    error(string.format("%s%s", MY_PRINT_TAG, msg))
end

function Builder:_downloadByGit(config)
    local name = config[KEYS.NAME]
    local url = config[KEYS.URL]
    local branch = config[KEYS.BRANCH] or 'master'
    local directory = MY_LIBRARY_PATH .. name .. "/"
    if not files.is_folder(directory) then
        self:print('cloning...')
        local cmd = string.format("git clone %s %s --branch %s --single-branch", url, directory, branch)
        local isOk = tools.execute(cmd)
        self:assert(isOk, "git clone failed!")
    elseif self._needPullGit then
        self:print('pulling...')
        local cmd = string.format("cd %s && git pull", directory)
        local isOk = tools.execute(cmd)
        self:assert(isOk, "git pull failed!")
    end
    self:print('complete!')
end

function Builder:_downloadByZip(config)
    local name = config[KEYS.NAME]
    local url = config[KEYS.URL]
    local parts = string.explode(url, "%.")
    local ext = parts[#parts]
    local directory = MY_LIBRARY_PATH .. name .. "/"
    local cacheDir = MY_LIBRARY_PATH .. ".temp/"
    local cacheFile = cacheDir .. name .. "." .. ext
    if files.is_folder(directory) then
        self:print('downloaded!')
        return
    end
    local isOk, err
    if not isOk then
        files.delete(cacheFile)
        self:print('downloading with pws1 ...')
        isOk, err = http.download(url, cacheFile, 'pws1')
    end
    if not isOk or files.size(cacheFile) == 0 then
        files.delete(cacheFile)
        self:print('download failed with pws1.')
        self:print('downloading with curl ...')
        isOk, err = http.download(url, cacheFile, 'curl')
    end
    if not isOk or files.size(cacheFile) == 0 then
        files.delete(cacheFile)
        self:print('download failed with curl.')
        self:print('downloading with wget ...')
        isOk, err = http.download(url, cacheFile, 'wget')
    end
    if not isOk or files.size(cacheFile) == 0 then
        files.delete(cacheFile)
        self:error('download failed with wget.')
    end
    self:print('download succeeded.')
    self:print('unzipping...')
    local cmd = string.format("unzip %s -d %s", cacheFile, directory)
    local isOk = tools.execute(cmd)
    self:assert(isOk, "unzip failed!")
    self:print('complete!')
end

function Builder:prepareEnv()
    if not files or not files.mk_folder then
        self:error('pure lua tools not found!')
    end
    if not files.is_folder(MY_LIBRARY_PATH) then
        files.mk_folder(MY_LIBRARY_PATH)
    end
end

function Builder:_installLib(name)
    local config = CONFIGS[name]
    self:assert(config ~= nil, string.format("lib [%s] not found", name))
    local parts = string.explode(config[KEYS.URL], "%.")
    config[KEYS.EXT] = string.upper(parts[#parts])
    config[KEYS.TYPE] = config[KEYS.EXT]
    config[KEYS.NAME] = name
    if config[KEYS.TYPE] == TYPES.GIT then
        self:_downloadByGit(config)
    elseif config[KEYS.TYPE] == TYPES.ZIP then
        self:_downloadByZip(config)
    else
        self:error(string.format('invalid lib type [%s]', config[KEYS.TYPE]))
    end
end

function Builder:installLibs(...)
    self:print('INSTALL LIB START!')
    self:prepareEnv()
    local libs = {...}
    for i=1,#libs,1 do
        local lib = libs[i]
        self:print(string.format('install:%s -> start:', lib))
        self:_installLib(lib)
        self:print(string.format('install:%s -> end.', lib))
    end
    self:print('INSTALL LIB END!\n')
end

function Builder:_containLib(name)
    local config = CONFIGS[name]
    local directory = MY_LIBRARY_PATH .. name .. "/"
    self:assert(config ~= nil, string.format("lib [%s] not found", name))
    self:assert(files.is_folder(directory), string.format("lib [%s] not installed", name))
    --
    local function insertInclue(dir)
        dir = directory .. dir
        self:assert(files.is_folder(dir), string.format("include directory [%s] not found", dir))
        table.insert(self._includeDirs, dir)
    end
    if is_string(config[KEYS.DIR_I]) then
        insertInclue(config[KEYS.DIR_I])
    elseif is_table(config[KEYS.DIR_I]) then
        for _,v in ipairs(config[KEYS.DIR_I]) do
            insertInclue(v)
        end
    end
    --
    local function insertLinking(dir)
        dir = directory .. dir
        self:assert(files.is_folder(dir), string.format("linking directory [%s] not found", dir))
        table.insert(self._linkingDirs, dir)
    end
    if is_string(config[KEYS.DIR_L]) then
        insertLinking(config[KEYS.DIR_L])
    elseif is_table(config[KEYS.DIR_L]) then
        for _,v in ipairs(config[KEYS.DIR_L]) do
            insertLinking(v)
        end
    end
    --
    local function insertTags(tag)
        table.insert(self._linkingTags, tag)
    end
    if is_string(config[KEYS.LIB_L]) then
        insertTags(config[KEYS.LIB_L])
    elseif is_table(config[KEYS.LIB_L]) then
        for _,v in ipairs(config[KEYS.LIB_L]) do
            insertTags(v)
        end
    end
    --
    if is_string(config[KEYS.FLAGS]) then
        table.insert(self._extraFlags, config[KEYS.FLAGS])
    end
end

function Builder:containLibs(...)
    self:print('CONTAIN LIB START!')
    local libs = {...}
    for i=1,#libs,1 do
        local lib = libs[i]
        self:print(string.format("contain:[%s]", lib))
        self:_containLib(lib)
    end
    self:print('CONTAIN LIB END!\n')
end

function Builder:processGcc(codePath, isRelease)
    self:print('PROCESS GCC START!')
    --
    local includeDirCmd = ""
    for _,v in ipairs(self._includeDirs) do
        includeDirCmd = includeDirCmd .. " -I " .. v
    end
    --
    local linkingDirCmd = ""
    for _,v in ipairs(self._linkingDirs) do
        linkingDirCmd = linkingDirCmd .. " -L " .. v
    end
    --
    local linkingTagCmd = ""
    for _,v in ipairs(self._linkingTags) do
        linkingTagCmd = linkingTagCmd .. " -l " .. v
    end
    --
    local extraFlagsCmd = ""
    for _,v in ipairs(self._extraFlags) do
        extraFlagsCmd = extraFlagsCmd .. " " .. v
    end

    --
    local parts = string.explode(codePath, "%.")
    local name = string.lower(parts[#parts - 1])
    local target = tools.is_windows() and string.format( "%s.exe", name) or name
    local cmd = string.format("gcc %s -o %s %s %s %s %s", codePath, target, includeDirCmd, linkingDirCmd, linkingTagCmd, extraFlagsCmd)
    --
    if isRelease then
        cmd = cmd .. " -O2 -mwindows"
    end
    --
    if self._isDebug then
        self:print(string.format("cmd:%s", cmd))
    end
    local isOk, output = tools.execute(cmd)
    if not isOk then
        self:print("gcc process failed!")
        self:error("err:" .. output)
    end
    if files.is_file(target) then
        self._executableFile = "." .. files.delimiter() .. target
    end
    self:print("gcc process succeeded!")
    --
    self:print('PROCESS GCC END!\n')
end

function Builder:programRun(argumentString)
    self:assert(self._executableFile ~= nil, 'executable file not found!')
    argumentString = argumentString or ""
    os.execute(self._executableFile .. argumentString)
end

return Builder
