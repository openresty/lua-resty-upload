Name
====

lua-resty-upload - Streaming reader and parser for HTTP file uploading based on ngx_lua cosocket

Status
======

This library is considered experimental and still under active development.

The API is still in flux and may change without notice.

Description
===========

This Lua library is a streaming file uploading API for the ngx_lua nginx module:

http://wiki.nginx.org/HttpLuaModule

The multipart/form-data MIME type is supported.

This Lua library takes advantage of ngx_lua's cosocket API, which ensures
100% nonblocking behavior.

Note that at least [ngx_lua 0.5.0rc5](https://github.com/chaoslawful/lua-nginx-module/tags) or [ngx_openresty 1.0.11.7](http://openresty.org/#Download) is required.

Synopsis
========

    lua_package_path "/path/to/lua-resty-redis/lib/?.lua;;";

    server {
        location /test {
            content_by_lua '
                local upload = require "resty.upload"
                local cjson = require "cjson"

                local form = upload:new(5)

                form:set_timeout(1000) -- 1 sec

                while true do
                    local typ, res, err = form:read()
                    if not typ then
                        ngx.say("failed to read: ", err)
                        return
                    end

                    ngx.say("read: ", cjson.encode({typ, res}))

                    if typ == "eof" then
                        break
                    end
                end

                local typ, res, err = form:read()
                ngx.say("read: ", cjson.encode({typ, res}))
            ';
        }
    }

A typical output of the /test location defined above is:

    read: ["header",["Content-Disposition","form-data; name=\"file1\"; filename=\"a.txt\""]]
    read: ["header",["Content-Type","text\/plain"]]
    read: ["body","Hello"]
    read: ["body",", wor"]
    read: ["body","ld"]
    read: ["part_end"]
    read: ["header",["Content-Disposition","form-data; name=\"test\""]]
    read: ["body","value"]
    read: ["body","\r\n"]
    read: ["part_end"]
    read: ["eof"]
    read: ["eof"]

Author
======

Zhang "agentzh" Yichun (章亦春) <agentzh@gmail.com>

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2012, by Zhang "agentzh" Yichun (章亦春) <agentzh@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

See Also
========
* the ngx_lua module: http://wiki.nginx.org/HttpLuaModule
* the lua-resty-memcached library: https://github.com/agentzh/lua-resty-memcached
* the lua-resty-redis library: https://github.com/agentzh/lua-resty-redis

