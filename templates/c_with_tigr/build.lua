
-- pcall(os.execute, "git clone git@github.com:kompasim/my-build-tools.git ./.my-build-tools")
-- package.path = package.path .. ";./.my-build-tools/?.lua"
package.path = package.path .. ";../../?.lua"
local builder = require("builder")

local builder = builder.c {}
builder:setInput('./test.c')
builder:setLibs("tigr")
builder:setOutput('test')
builder:start()

os.execute("start " .. files.csd() .. "./test.exe")
