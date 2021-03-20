const c = @cImport(@cInclude("curl/curl.h"));
const std = @import("std");
const clap = @import("clap");

const debug = std.debug;

const CurlError = error {
    InitFailed,
    RequestFailed
};

pub fn main() anyerror!void {
     // First we specify what parameters our program can take.
    // We can use `parseParam` to parse a string to a `Param(Help)`
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-u, --url <URL>     Url to GET") catch unreachable,
    };

    // Initalize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also just pass `null` to `parser.next` if you
    // don't care about the extra information `Diagnostics` provides.
    var diag: clap.Diagnostic = undefined;

    var args = clap.parse(clap.Help, &params, std.heap.page_allocator, &diag) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer args.deinit();

    var url: []const u8 = "https://dominikbraun.io";

    if (args.option("--url")) |s| {
        url = s;
    }


    var initRes: u32 = @bitCast(u32, c.curl_global_init(c.CURL_GLOBAL_ALL));
    if (initRes == 0) {
        debug.print("Init ok", .{});
    } else {
        debug.print("init failed: {0}", .{initRes});
        return CurlError.InitFailed;
    }
    
    var handle: ?*c.CURL = c.curl_easy_init();
    if (handle == null) {
        debug.print("could not retrieve the curl handle", .{});
        return CurlError.InitFailed;
    }

    debug.print("got the curl handle", .{});
    
    // Set the URL that is about to receive our GET. This URL can
    // just as well be a https:// URL.
    _ = c.curl_easy_setopt(handle, .CURLOPT_URL, @ptrCast([*c]const u8, url));
   // _ = c.curl_easy_setopt(handle, .CURLOPT_HTTPGET, c_int(1));

    // Perform the request, res will get the return code.
    var res: c.CURLcode = c.curl_easy_perform(handle);

    // Check errors.
    if (res != c.CURLcode.CURLE_OK){
        // ToDo: use c.curl_easy_strerror(res);
        debug.print("request failed {0}", .{res});
        return CurlError.RequestFailed;
    }

    // always cleanup
    c.curl_easy_cleanup(handle);

    c.curl_global_cleanup();
}
