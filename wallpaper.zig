const std = @import("std");
const http = std.http;

var aallocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

pub fn main() !void {
    var allocator = aallocator.allocator();

    // random number
    var rnd = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var some_random_num = rnd.random().uintLessThan(u8, 77);

    // fetch konachan page
    var client = http.Client{
        .allocator = allocator,
    };
    const url = try std.fmt.allocPrint(allocator, "https://konachan.net/post?tags=landscape&page={d}", .{some_random_num});
    const uri = try std.Uri.parse(url);

    var h = http.Headers{ .allocator = allocator };
    defer h.deinit();

    var req = try client.request(.GET, uri, h, .{});
    defer req.deinit();

    try req.start();
    try req.wait();

    const body = try req.reader().readAllAlloc(allocator, 10_000_000);
    defer allocator.free(body);

    // Get images
    const urls = try get_all_urls(allocator, body);

    // Select random image
    var rand_image = rnd.random().uintLessThan(usize, urls.len);
    const image_url = urls[rand_image];

    // Fetch image
    const image_uri = try std.Uri.parse(image_url);
    var image_req = try client.request(.GET, image_uri, h, .{});
    defer image_req.deinit();

    try image_req.start();
    try image_req.wait();

    const image_body = try image_req.reader().readAllAlloc(allocator, 10_000_000);
    defer allocator.free(image_body);

    // Random image name
    var name = [5]u8{ 0, 0, 0, 0, 0 };
    var i: u8 = 0;
    while (i < 5) {
        var c = rnd.random().uintLessThan(u8, 127);
        if (std.ascii.isAlphabetic(c) or std.ascii.isAlphanumeric(c)) {
            name[i] = c;
            i += 1;
        }
    }
    var nameext = try std.mem.concat(allocator, u8, &[_][]const u8{ &name, ".jpg" });

    // Clean previous images
    var dir = try std.fs.cwd().openIterableDir(".", .{});
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |file| {
        if (file.kind != .file) {
            continue;
        }
        if (std.mem.endsWith(u8, file.name, ".jpg")) {
            try std.fs.cwd().deleteFile(file.name);
        }
    }

    // Write image to file
    const image_file = try std.fs.cwd().createFile(nameext, .{ .truncate = true });
    defer image_file.close();
    _ = try image_file.write(image_body);

    // Set wallpaper
    const result = try std.ChildProcess.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "automator", "-i", nameext, "/Users/jairo/setDesktopPicture.workflow" },
    });
    if (result.stderr.len > 0) {
        std.debug.print("stderr: {s}\n", .{result.stderr});
    }
}

fn get_all_urls(allocator: std.mem.Allocator, body: []u8) ![][]u8 {
    var urls = std.ArrayList([]u8).init(allocator);
    var rest = body;
    while (true) {
        const url_and_rest = get_image_url_and_rest(rest);
        if (url_and_rest == null) {
            break;
        }
        if (url_and_rest.?.url) |url| {
            urls.append(url) catch unreachable;
        }
        if (url_and_rest.?.rest) |r| {
            rest = r;
        }
    }
    return urls.toOwnedSlice();
}

fn get_image_url_and_rest(body: []u8) ?struct {
    url: ?[]u8,
    rest: ?[]u8,
} {
    const index1 = std.mem.indexOf(u8, body, "https://konachan.net/image/");
    if (index1 == null) {
        return null;
    }
    const s1 = body[index1.?..];
    const iQuote = std.mem.indexOf(u8, s1, "\"");
    if (iQuote == null) {
        return null;
    }
    const url1 = s1[0..iQuote.?];
    if (url1.len == 0) {
        return null;
    }
    return .{ .url = url1, .rest = s1[iQuote.?..] };
}
