# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: body preserve off
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local upload = require "resty.upload"
            local ljson = require "ljson"

            local form = upload:new(5)

            form:set_timeout(1000) -- 1 sec

            while true do
                local typ, res, err = form:read()
                if not typ then
                    ngx.say("failed to read: ", err)
                    return
                end

                ngx.say("read: ", ljson.encode({typ, res}))

                if typ == "eof" then
                    break
                end
            end

            local typ, res, err = form:read()
            ngx.say("read: ", ljson.encode({typ, res}))

            ngx.say("remain body: ", ngx.req.get_body_data())
        ';
    }
--- more_headers
Content-Type: multipart/form-data; boundary=---------------------------820127721219505131303151179
--- request eval
qq{POST /t\n-----------------------------820127721219505131303151179\r
Content-Disposition: form-data; name="file1"; filename="a.txt"\r
Content-Type: text/plain\r
\r
Hello, world\r\n-----------------------------820127721219505131303151179\r
Content-Disposition: form-data; name="test"\r
\r
value\r
\r\n-----------------------------820127721219505131303151179--\r
}
--- response_body
read: ["header",["Content-Disposition","form-data; name=\"file1\"; filename=\"a.txt\"","Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\""]]
read: ["header",["Content-Type","text/plain","Content-Type: text/plain"]]
read: ["body","Hello"]
read: ["body",", wor"]
read: ["body","ld"]
read: ["part_end"]
read: ["header",["Content-Disposition","form-data; name=\"test\"","Content-Disposition: form-data; name=\"test\""]]
read: ["body","value"]
read: ["body","\r\n"]
read: ["part_end"]
read: ["eof"]
read: ["eof"]
remain body: 
--- no_error_log
[error]



=== TEST 2: body preserve on
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local original_len = ngx.req.get_headers()["Content-Length"]
            local upload = require "resty.upload"

            local form = upload:new(5, nil, true)

            form:set_timeout(1000) -- 1 sec

            while true do
                local typ, res, err = form:read()
                if not typ then
                    ngx.say("failed to read: ", err)
                    return
                end


                if typ == "eof" then
                    break
                end
            end

            local typ, res, err = form:read()

            ngx.say("remain body length changed: ", #ngx.req.get_body_data() ~= original_len)
        ';
    }
--- more_headers
Content-Type: multipart/form-data; boundary=---------------------------820127721219505131303151179
--- request eval
qq{POST /t\n-----------------------------820127721219505131303151179\r
Content-Disposition: form-data; name="file1"; filename="a.txt"\r
Content-Type: text/plain\r
\r
Hello, world\r\n-----------------------------820127721219505131303151179\r
Content-Disposition: form-data; name="test"\r
\r
value\r
\r\n-----------------------------820127721219505131303151179--\r
}
--- response_body
remain body length changed: false

--- no_error_log
[error]



