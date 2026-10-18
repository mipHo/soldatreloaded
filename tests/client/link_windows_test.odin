#+build windows
package client_test

import "core:testing"
import win "core:sys/windows"

import "../../apps/client/online"

foreign import advapi32 "system:Advapi32.lib"

@(default_calling_convention = "system", private = "file")
foreign advapi32 {
	RegDeleteTreeW :: proc(hKey: win.HKEY, lpSubKey: win.LPCWSTR) -> win.LSTATUS ---
}

// Windows's handler, under a key of the test's own, taken away after: the protocol, and
// its open command running the game with the link.
@(test)
link_handler_registry :: proc(t: ^testing.T) {
	ROOT :: `Software\SoldatReloadedTest`
	defer RegDeleteTreeW(win.HKEY_CURRENT_USER, win.utf8_to_wstring(ROOT, context.temp_allocator))
	testing.expect(t, online.link_register_at(ROOT + `\Classes`, `C:\Games\Soldat Reloaded\soldatreloaded.exe`), "written")
	read :: proc(key, name: string) -> string {
		buf: [512]u16
		size := u32(size_of(buf))
		wname := win.utf8_to_wstring(name, context.temp_allocator) if name != "" else nil
		if win.RegGetValueW(win.HKEY_CURRENT_USER, win.utf8_to_wstring(key, context.temp_allocator), wname, win.RRF_RT_REG_SZ, nil, &buf, &size) != 0 do return "<none>"
		text, _ := win.wstring_to_utf8(cstring16(&buf[0]), -1, context.temp_allocator)
		return text
	}
	testing.expect_value(t, read(ROOT + `\Classes\soldatreloaded`, "URL Protocol"), "")
	testing.expect_value(t, read(ROOT + `\Classes\soldatreloaded\shell\open\command`, ""), `"C:\Games\Soldat Reloaded\soldatreloaded.exe" "%1"`)
}
