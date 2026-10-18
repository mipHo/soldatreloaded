package online

import "core:net"
import "core:strconv"
import "core:strings"

// A link that joins a server, clicked anywhere a link can be: in a browser, a chat, a
// server list. soldatreloaded://join/<host>[:<port>][/<password>], the port the game's
// own if none, as the Join page takes an address. The game starts with the link as its
// argument (the system's handler for the scheme, main's link.odin); what it says is
// anyone's, so nothing but a join of that shape is taken from it.

LINK_SCHEME :: "soldatreloaded"

@(private = "file")
LINK_HOST_MAX :: 253 // a DNS name's, at most

// Whether `arg` is one of ours at all, whatever it then says.
link_is :: proc(arg: string) -> bool {
	return len(arg) > len(LINK_SCHEME) && strings.equal_fold(arg[:len(LINK_SCHEME) + 1], LINK_SCHEME + ":")
}

// The server a join link names, as connect takes it: host:port, and /password after it
// when the link has one. False for anything else: another command, a host or port that
// can't be, a password a server can't have. In the temp allocator.
link_target :: proc(link: string) -> (target: string, ok: bool) {
	if !link_is(link) do return
	rest := link[len(LINK_SCHEME) + 1:]
	rest = strings.trim_prefix(rest, "//")
	if len(rest) < 5 || !strings.equal_fold(rest[:5], "join/") do return
	rest = rest[5:]
	rest = strings.trim_suffix(rest, "/") // as a browser or a chat leaves it
	decoded := net.percent_decode(rest, context.temp_allocator) or_return

	address, password, has_password := target_split(decoded)
	host, port := address, ""
	if colon := strings.last_index_byte(address, ':'); colon >= 0 do host, port = address[:colon], address[colon + 1:]
	if !host_valid(host) do return
	if port != "" {
		n, parsed := strconv.parse_uint(port, 10)
		if !parsed || n < 1 || n > 65535 do return
	}
	if has_password && (password == "" || len(password) > 32 || strings.contains_any(password, " \"") || !printable(password)) do return
	return target_join(address, password if has_password else ""), true
}

// ---------------------------------------------------------------------------------
// The handler: this game, the program at `exe` run from its install `dir`, made the
// system's for the scheme, for the user alone, as it starts (link_register, a file for
// each system). On Linux, a desktop entry that runs it, and that entry the default for
// the scheme in the user's mimeapps.list; the entry's text and the list's are made here.

LINK_DESKTOP_FILE :: "soldatreloaded-link.desktop"

// The desktop entry: hidden from the menus, the game run in its install with the link.
link_desktop_entry :: proc(exe, dir: string, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	strings.write_string(&b, "[Desktop Entry]\nType=Application\nName=Soldat Reloaded\n")
	strings.write_string(&b, "Exec=")
	desktop_quote(&b, exe)
	strings.write_string(&b, " %u\nPath=")
	strings.write_string(&b, dir)
	strings.write_string(&b, "\nIcon=")
	strings.write_string(&b, dir)
	strings.write_string(&b, "/data/icon.png\nTerminal=false\nNoDisplay=true\nMimeType=x-scheme-handler/" + LINK_SCHEME + ";\n")
	return strings.to_string(b)
}

// An Exec argument quoted as the Desktop Entry spec has it: in double quotes, its `"`,
// backquote, `$` and backslash escaped by a backslash.
@(private = "file")
desktop_quote :: proc(b: ^strings.Builder, s: string) {
	strings.write_byte(b, '"')
	for c in transmute([]u8)s {
		if c == '"' || c == '`' || c == '$' || c == '\\' do strings.write_byte(b, '\\')
		strings.write_byte(b, c)
	}
	strings.write_byte(b, '"')
}

// mimeapps.list as `list` was, with our entry the default for the scheme: the line put
// in place under [Default Applications], which is made if it isn't there; the rest as
// it was.
link_mimeapps :: proc(list: string, allocator := context.temp_allocator) -> string {
	KEY :: "x-scheme-handler/" + LINK_SCHEME
	LINE :: KEY + "=" + LINK_DESKTOP_FILE
	lines := strings.split_lines(list, context.temp_allocator)
	out := make([dynamic]string, context.temp_allocator)
	in_defaults, done := false, false
	for line in lines {
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "[") {
			if in_defaults && !done {
				append(&out, LINE)
				done = true
			}
			in_defaults = trimmed == "[Default Applications]"
		}
		if in_defaults && strings.has_prefix(trimmed, KEY + "=") {
			if !done do append(&out, LINE)
			done = true
			continue
		}
		append(&out, line)
	}
	for len(out) > 0 && strings.trim_space(out[len(out) - 1]) == "" do pop(&out)
	if !done {
		if !in_defaults {
			if len(out) > 0 do append(&out, "")
			append(&out, "[Default Applications]")
		}
		append(&out, LINE)
	}
	append(&out, "")
	return strings.join(out[:], "\n", allocator)
}

// A host name or an IPv4 address: letters, digits, dots and dashes.
@(private = "file")
host_valid :: proc(host: string) -> bool {
	if host == "" || len(host) > LINK_HOST_MAX do return false
	for c in transmute([]u8)host {
		switch c {
		case 'a' ..= 'z', 'A' ..= 'Z', '0' ..= '9', '.', '-':
		case: return false
		}
	}
	return true
}

@(private = "file")
printable :: proc(s: string) -> bool {
	for c in transmute([]u8)s do if c < 0x21 || c > 0x7E do return false
	return true
}
