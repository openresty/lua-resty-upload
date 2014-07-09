--[[
Description:
    This script is aimed to extend the nginx lua module, to provide support of 
    decoding HTTP multipart form data into Lua table. 
    The script requires the upload module, which is from :
        https://github.com/openresty/lua-resty-upload

FileId:
$Id: form.lua
2014-07-09 16:08 星期三

License:
Copyright 2014, mochui.net, all rights reserved.
--]]

module("form", package.seeall)

local upload = require "upload";

local function decodeContentDisposition(value)
    local ret;

    local typ, paras = string.match(value, "([%w%-%._]+);(.+)");

    if typ then
        ret                 = {};
        ret.dispositionType = typ;
        ret.paras           = {};
        
        if paras then
            for paraKey, paraValue in string.gmatch(paras, '([%w%.%-_]+)="([%w%.%-_]+)"') do
                ret.paras[paraKey] = paraValue;
            end
        end
    end

    return ret;
end

local function decodeHeaderItem(key, value)
    local ret;

    if key == "Content-Disposition" then
        ret = decodeContentDisposition(value);
    end

    if key == "Content-Type" then
        ret = value;
    end

    return ret;
end

local function decodeHeader(res)
    if type(res) == "table" and res[1] and res[2] then
        key     = res[1];
        value   = decodeHeaderItem(res[1], res[2]);
    else
        key     = res;
        value   = res;
    end

    return key, value;
end

function getFormTable(tmpFileFolder)
    local chunkSize = 4096;
    local formdata  = {};
    local part      = {};
    part.headers    = {};
    part.body       = "";
    
    local headers   = {};

    util.log("start to decode form data");
    local form, err = upload:new(chunkSize);
    if not form then
        return nil, err;
    end

    form:set_timeout(1000);

    while true do
        local typ, res, err = form:read();

        if not typ then
            return nil, err;
        end

        if typ == "header" then
            local key, value = decodeHeader(res);
            util.log("header:" .. tostring(res[3]));
            if key then
                part.headers[key] = value;
            else
                return nil, "failed to decode header:" .. res;
            end
        end
        
        if typ == "body" then
            if part.headers["Content-Disposition"] 
                and part.headers["Content-Disposition"].paras
                and part.headers["Content-Disposition"].paras.filename then    
                local filePath = tmpFileFolder or "/tmp";
                local fullFileName = filePath .. "/" 
                    .. part.headers["Content-Disposition"].paras.filename;
                if not part.tmpFd then
                    part.tmpFd, err = io.open(fullFileName, "w");
                    if not part.tmpFd then
                        return nil, "failed to open tmpfile:" 
                                    .. tostring(fullFileName);
                    end
                    part.body = fullFileName;
                end
                part.tmpFd:write(res);
            else
                part.body = part.body .. res;
            end
        end

        if typ == "part_end" then
            if part.tmpFd then
                part.tmpFd:close();
            end
            table.insert(formdata, part);
            part            = {};
            part.headers    = {};
            part.body       = ""; 
            part.tmpFd      = nil;
        end

        if typ == "eof" then
            break;
        end
    end

    return formdata, err;
end

