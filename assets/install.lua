local ffi = require("ffi")
local A = require("android")

ffi.cdef[[
int mkdir(const char *pathname, int mode);
]]

local function check_installed_rev()
    local git_rev = io.open(A.dir .. "/git-rev")
    if git_rev then
        local rev = git_rev:read("*a")
        git_rev:close()
        return rev
    end
end

local function make_directory(where, dir)
    local subdir, left = dir:match("([^/]+)/(.*)")
    if subdir then
        local abs = where .. "/" .. subdir
        ffi.C.mkdir(abs, 493) -- 493dec == 0755oct
        make_directory(abs, left)
    end
end

local function install_file(file)
    file = file:gsub("^%./","") -- strip leading "./"
    A.LOGI(string.format("install file <%s>", file))
    make_directory(A.dir, file)
    local input = A.Asset.open("install/"..file)
    local output = assert(io.open(A.dir .. "/" .. file, "w"),
                    "cannot open output file")
    for content in input:data() do
        output:write(content)
    end
    input:close()
    output:close()
end

local function install()
    local asset_rev = A.Asset.content_of("install/git-rev")

    if asset_rev == check_installed_rev() then
        A.LOGI("Skip installation for revision "..asset_rev)
        return
    end

    local install_these_files = A.Asset.content_of("install.list")
    for file in install_these_files:gmatch("[^\n]+") do
        install_file(file)
    end
end

install()
