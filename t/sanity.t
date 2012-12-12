# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: basic
--- http_config eval: $::HttpConfig
--- config
    location /t {
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
read: ["header",["Content-Type","text\/plain","Content-Type: text\/plain"]]
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
--- no_error_log
[error]



=== TEST 2: in-part header line too long
--- http_config eval: $::HttpConfig
--- config
    location /t {
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
--- more_headers
Content-Type: multipart/form-data; boundary=---------------------------820127721219505131303151179
--- request eval
qq{POST /t\n-----------------------------820127721219505131303151179\r
Content-Disposition: form-data; name="file1"; filename="a.txt"\r
Content-Type: text/plain\r
} . ("Hello, world" x 64) . qq{\r\n-----------------------------820127721219505131303151179\r
Content-Disposition: form-data; name="test"\r
\r
value\r
\r\n-----------------------------820127721219505131303151179--\r
}
--- response_body
read: ["header",["Content-Disposition","form-data; name=\"file1\"; filename=\"a.txt\"","Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\""]]
read: ["header",["Content-Type","text\/plain","Content-Type: text\/plain"]]
failed to read: line too long: Hello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, worldHello, wo...
--- no_error_log
[error]



=== TEST 3: terminate line too long
--- http_config eval: $::HttpConfig
--- config
    location /t {
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
\r\n-----------------------------820127721219505131303151179} . ("a" x 1024) . qq{--\r
}
--- response_body
read: ["header",["Content-Disposition","form-data; name=\"file1\"; filename=\"a.txt\"","Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\""]]
read: ["header",["Content-Type","text\/plain","Content-Type: text\/plain"]]
read: ["body","Hello"]
read: ["body",", wor"]
read: ["body","ld"]
read: ["part_end"]
read: ["header",["Content-Disposition","form-data; name=\"test\"","Content-Disposition: form-data; name=\"test\""]]
read: ["body","value"]
read: ["body","\r\n"]
failed to read: line too long: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa...
--- no_error_log
[error]

