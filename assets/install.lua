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

    local buffer_size = 4096
    local buf = ffi.new("char[?]", buffer_size)

    make_directory(A.dir, file)
    local output = assert(io.open(A.dir .. "/" .. file, "wb"),
                    "cannot open output file")

    local asset = ffi.C.AAssetManager_open(A.app.activity.assetManager,
                    "install/"..file, ffi.C.AASSET_MODE_STREAMING)
    assert(asset, "cannot open asset")
    
    local nb_read = ffi.C.AAsset_read(asset, buf, buffer_size)
    while nb_read > 0 do
        output:write(ffi.string(buf, nb_read))
        nb_read = ffi.C.AAsset_read(asset, buf, buffer_size)
    end

    ffi.C.AAsset_close(asset)
    output:close()
end

local function install()
    local asset_rev = A.get_asset_content("install/git-rev")

    if asset_rev == check_installed_rev() then
        A.LOGI("Skip installation for revision "..asset_rev)
        return
    end

    local install_these_files = A.get_asset_content("install.list")
    for file in install_these_files:gmatch("[^\n]+") do
        install_file(file)
    end
end

--[[
    local mgr = A.app.activity.assetManager
    local asset_dir = ffi.C.AAssetManager_openDir(mgr, "install")

    assert(asset_dir ~= nil, "could not open install directory in assets")

    local filename = ffi.C.AAssetDir_getNextFileName(asset_dir)
    while filename ~= nil do
        local sfilename = ffi.string(filename)
        A.LOGI(string.format("Check file: %s", sfilename))
        filename = ffi.C.AAssetDir_getNextFileName(asset_dir)
        local rev = filename:match(package_name)
        if rev then
            if rev == check_installed_rev() then
                A.LOGI("Skip installation for revision "..rev)
                break
            end
            A.LOGI("Found new package revision "..rev)
            -- copy package from asset
            local package = A.dir.."/"..filename
            local buffer_size = 4096
            local buf = ffi.new("char[?]", buffer_size)
            local asset = ffi.C.AAssetManager_open(mgr,
                            ffi.cast("char*", module.."/"..filename),
                            ffi.C.AASSET_MODE_STREAMING);
            if asset ~= nil then
                local output = ffi.C.fopen(ffi.cast("char*", package),
                                ffi.cast("char*", "wb"))
                local nb_read = ffi.C.AAsset_read(asset, buf,
                                ffi.new("int", buffer_size))
                while nb_read > 0 do
                    ffi.C.fwrite(buf, ffi.new("int", nb_read),
                                ffi.new("int", 1), output)
                    nb_read = ffi.C.AAsset_read(asset, buf,
                                ffi.new("int", buffer_size))
                end
                ffi.C.fclose(output)
                ffi.C.AAsset_close(asset)
                -- unpack to data directory
                local args = {"7z", "x", package, A.dir}
                local argv = ffi.new("char*[?]", #args+1)
                for i, arg in ipairs(args) do
                    argv[i-1] = ffi.cast("char*", args[i])
                end
                A.LOGI("Installing new koreader package to "..args[4])
                local lzma = ffi.load("liblzma.so")
                lzma.lzma_main(ffi.new("int", #args), argv)
                ffi.C.remove(ffi.cast("char*", package))
                break
            end
        end
    end
    A.LOGI("done")
    ffi.C.AAssetDir_close(asset_dir)
end
--]]

install()
