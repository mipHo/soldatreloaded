package client_test

import "core:strings"
import "core:testing"

import "../../apps/client/online"

// A join link names a server as the Join page takes it, and nothing else is taken from
// one: what it says is anyone's.
@(test)
join_links :: proc(t: ^testing.T) {
	Case :: struct {
		link, target: string, // "" for refused
	}
	cases := [?]Case {
		{"soldatreloaded://join/149.248.193.40:23073", "149.248.193.40:23073"},
		{"soldatreloaded://join/149.248.193.40:23073/", "149.248.193.40:23073"}, // as a browser leaves it
		{"SoldatReloaded://join/play.example.com", "play.example.com"}, // the game's port
		{"soldatreloaded://join/1.2.3.4:23073/se%2Fcret", "1.2.3.4:23073/se/cret"},
		{"soldatreloaded:join/1.2.3.4:23073", "1.2.3.4:23073"},
		{"soldatreloaded://join/1.2.3.4:23073/a%2Bb%25c%2Fd", "1.2.3.4:23073/a+b%c/d"}, // as the join page encodes one
		{"soldatreloaded://join/1.2.3.4:0", ""},
		{"soldatreloaded://join/1.2.3.4:70000", ""},
		{"soldatreloaded://join/1.2.3.4:23073/two%20words", ""}, // a password no server has
		{"soldatreloaded://join/1.2.3.4:23073/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", ""}, // 33 letters
		{"soldatreloaded://join/evil host:23073", ""},
		{"soldatreloaded://join/", ""},
		{"soldatreloaded://quit", ""},
		{"soldatreloaded://join/1.2.3.4%0A:23073", ""},
		{"https://join/1.2.3.4:23073", ""},
	}
	for c in cases {
		target, ok := online.link_target(c.link)
		if c.target == "" {
			testing.expectf(t, !ok, "%s refused, not %s", c.link, target)
		} else {
			testing.expectf(t, ok && target == c.target, "%s joins %s, not %s", c.link, c.target, target)
		}
	}
	testing.expect(t, online.link_is("soldatreloaded://anything") && !online.link_is("-map") && !online.link_is("soldatreloaded"), "ours by the scheme alone")
}

// Linux's handler: a desktop entry that runs the game from its install with the link, its
// path quoted; and the scheme's default put in mimeapps.list, the rest of it as it was.
@(test)
link_handler_files :: proc(t: ^testing.T) {
	entry := online.link_desktop_entry(`/home/a "b"/sr/soldatreloaded`, "/home/a/sr")
	testing.expect(t, strings.contains(entry, `Exec="/home/a \"b\"/sr/soldatreloaded" %u`), entry)
	testing.expect(t, strings.contains(entry, "Path=/home/a/sr\n") && strings.contains(entry, "MimeType=x-scheme-handler/soldatreloaded;"), entry)

	LINE :: "x-scheme-handler/soldatreloaded=" + online.LINK_DESKTOP_FILE
	testing.expect_value(t, online.link_mimeapps(""), "[Default Applications]\n" + LINE + "\n")
	kept := "[Added Associations]\ntext/plain=gedit.desktop;\n\n[Default Applications]\ntext/html=firefox.desktop\nx-scheme-handler/soldatreloaded=old.desktop\n\n[Removed Associations]\n"
	got := online.link_mimeapps(kept)
	testing.expect(t, strings.count(got, "x-scheme-handler/soldatreloaded=") == 1 && strings.contains(got, LINE), got)
	testing.expect(t, strings.contains(got, "text/plain=gedit.desktop;") && strings.contains(got, "text/html=firefox.desktop") && strings.contains(got, "[Removed Associations]"), "the rest kept")
	testing.expect_value(t, online.link_mimeapps(got), got) // made again, the same
	testing.expect(t, strings.contains(online.link_mimeapps("[Added Associations]\na=b\n"), "[Default Applications]\n" + LINE), "the section made")
}
