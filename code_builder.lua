--[[
    code
]]

local Base = require("builder_base")
local Builder, Super = class("Builder", Base)

function Builder:__init__()
    Super.__init__(self, "html")
    self._fileArr = {}
    self._lineArr = {}
    self:_prepareEnv()
end

function Builder:_prepareEnv()
    Super._prepareEnv(self)
end

function Builder:inputFiles(...)
    self:print("input files ...")
    self:assert(table.is_empty(self._fileArr), "input files are already defined")
    local fileArr = {...}
    for i,v in ipairs(fileArr) do
        self:assert(files.is_file(v), "input file not found:" .. v)
        self:print("input file:" .. v)
        table.insert(self._fileArr, v)
    end
end

function Builder:printHeader(headerTag, height)
    self:print("print header ...")
    self:assert(self._isPrintHeader == nil, "print header is already defined")
    self:assert(is_string(headerTag), "header tag should be string")
    self._isPrintHeader = true
    self._headerTag = headerTag
    self._headerHeight = height
    self:print("header tag:" .. tostring(self._headerTag))
end

function Builder:handleMacro(...)
    self:print("handle macro ...")
    self:assert(self._isHandleMacro == nil, "handle macro is already defined")
    self._isHandleMacro = true
    self:assert(self._commentTags == nil, "comment tag is already defined")
    self._commentTags = {...}
    self:assert(not table.is_empty(self._commentTags), "comment tag should be string")
    self:print("comment tags:" .. table.implode(self._commentTags, ","))
end

function Builder:outputFile(path)
    self:assert(self._outputFile == nil, "output can only be one file")
    self:assert(is_string(path), "output path should be string")
    self._outputFile = path
end

function Builder:_parseLine(line)
    return nil
end

function Builder:start()
    --
    self:print("start:")
    self:assert(not table.is_empty(self._fileArr), "input files are not defined")
    self:assert(not self._isHandleMacro or is_table(self._commentTags), "comment tags are not defined")
    self:assert(not self._isPrintHeader or is_string(self._headerTag), "header tag is not defined")
    --
    self:print("reading files ...")
    for i,path in ipairs(self._fileArr) do
        -- read file
        self:assert(files.is_file(path), "file not found:" .. tostring(path))
        local content = files.read(path)
        self:assert(#content > 0, "input files are empty")
        local lineArr = string.explode(content, "\n")
        -- put header file
        table.insert(self._lineArr, "\n")
        if self._isPrintHeader then
            local headInfo = string.format(" date:%s file:%s ", os.date("%Y-%m-%d %H:%M:%S", os.time()), path)
            local headWidth = #headInfo + 10
            local tagLength = #self._headerTag
            self._headerHeight = (self._headerHeight and self._headerHeight > 0) and self._headerHeight or 1
            for _=1,self._headerHeight do
                table.insert(self._lineArr, string.center(self._headerTag, headWidth, self._headerTag))
            end
            table.insert(self._lineArr, string.center(headInfo, headWidth, self._headerTag))
            for _=1,self._headerHeight do
                table.insert(self._lineArr, string.center(self._headerTag, headWidth, self._headerTag))
            end
        end
        table.insert(self._lineArr, "\n")
        -- parse file content
        for _,line in ipairs(lineArr) do
            local newLine = self:_parseLine(line)
            table.insert(self._lineArr, newLine or line)
        end
    end
    --
    self:print("creating target ...")
    local html = table.concat(self._lineArr, "\n")
    self:assert(self._outputFile ~= nil, "output path not found")
    files.write(self._outputFile, html)
    self:print("writing target succeeded!")
    self:print("finish!\n")
end

return Builder
