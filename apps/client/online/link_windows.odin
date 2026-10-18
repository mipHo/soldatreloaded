#+build windows
package online

import "core:os"
import "core:path/filepath"
import "core:strings"
import win "core:sys/windows"

// The scheme's handler on Windows: HKEY_CURRENT_USER\Software\Classes\soldatreloaded, for
// this user alone, needing no administrator: a URL protocol whose open command runs this
// program with the link, and whose icon is the program's.

LINK_CLASSES :: `Software\Classes`

// This game made the handler, as it starts. False if it couldn't be, which only means
// links don't open it.
link_register :: proc() -> bool {
	exe, err := os.get_executable_path(context.temp_allocator)
	if err != nil do return false
	return link_register_at(LINK_CLASSES, exe)
}

// The handler under HKEY_CURRENT_USER\<classes>, for `exe`.
link_register_at :: proc(classes, exe: string) -> bool {
	key, _ := filepath.join({classes, LINK_SCHEME}, context.temp_allocator)
	command, _ := filepath.join({key, `shell\open\command`}, context.temp_allocator)
	icon, _ := filepath.join({key, "DefaultIcon"}, context.temp_allocator)
	quoted := strings.concatenate({`"`, exe, `"`}, context.temp_allocator)
	return value_set(key, "", "URL:Soldat Reloaded") &&
		value_set(key, "URL Protocol", "") &&
		value_set(icon, "", strings.concatenate({quoted, ",0"}, context.temp_allocator)) &&
		value_set(command, "", strings.concatenate({quoted, ` "%1"`}, context.temp_allocator))
}

// A string value, its key made if it isn't there; "" for the key's own.
@(private = "file")
value_set :: proc(key, name, value: string) -> bool {
	wkey := win.utf8_to_wstring(key, context.temp_allocator)
	wname := win.utf8_to_wstring(name, context.temp_allocator) if name != "" else nil
	wvalue := win.utf8_to_utf16(value, context.temp_allocator)
	data := make([]u16, len(wvalue) + 1, context.temp_allocator) // with its terminator, as REG_SZ is
	copy(data, wvalue)
	return win.RegSetKeyValueW(win.HKEY_CURRENT_USER, wkey, wname, win.REG_SZ, raw_data(data), u32(len(data) * size_of(u16))) == 0
}
