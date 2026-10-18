package online

// What the player is doing, shown on their Discord profile: "Playing Soldat Reloaded",
// the game's icon, and a line or two of where. Said to the Discord app running on this
// machine over its local pipe (Windows' \\.\pipe\discord-ipc-N, elsewhere a Unix socket
// of that name in the runtime directory: discord_windows.odin, discord_other.odin), as
// frames of JSON: a handshake with the game's application ID, then SET_ACTIVITY whenever
// what is shown changes. Nothing goes over the network from here, and nothing waits on
// Discord: with no app running the pipe isn't there, and it is looked for again every so
// often. The browser's Discord has no pipe, so it sees none of this. Discord clears what
// is shown when the pipe closes, as the game quits.
//
// The icon is the game's own, by its address (DISCORD_ICON), which Discord fetches and
// shows as it would an art asset of the application's: the application has none uploaded
// on Discord's Developer Portal, and an asset's name it hasn't got shows nothing. Under
// it, a button to join the server played on, when it is one anyone may join, and one to
// the game's newest release, for whoever sees them (Discord shows a player's buttons to
// the others, not to them).
//
// From the C client: net/discord.c.

import "core:encoding/endian"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:unicode/utf8"

import "../../../core/utils"

DISCORD_APP_ID :: "1555217040036339732"
DISCORD_ICON :: "https://raw.githubusercontent.com/soldatreloaded/soldatreloaded/main/assets/data/icon.png"
DISCORD_BUTTON :: `{"label":"Get Soldat Reloaded","url":"https://github.com/soldatreloaded/soldatreloaded/releases/latest"}`
// A server's join link as Discord takes one, https alone: the page that opens the game's
// own (soldatreloaded://join/..., link.odin) from there (the soldatreloaded.github.io
// repository).
DISCORD_JOIN_PAGE :: "https://soldatreloaded.github.io/join/?s="

@(private = "file")
RETRY_SECONDS :: 15 // with no app found, looked for again this often
@(private = "file")
SEND_GAP :: 5.0 // seconds between activities at least: Discord takes five in twenty
@(private = "file")
FRAME_HEADER :: 8 // opcode and length, each a little-endian u32
@(private = "file")
FRAME_MOST :: 2048 // a frame's JSON said, at most

@(private = "file")
Op :: enum u32 {
	Handshake,
	Frame,
	Close,
	Ping,
	Pong,
}

Discord_Text :: utils.Short_String(128) // a line shown

Discord_Activity :: struct {
	details:    Discord_Text, // the first line, empty for none
	state:      Discord_Text, // the second, empty for none
	since:      i64, // the time it began, Unix seconds, for the "elapsed"; 0 for none
	ends:       i64, // the time it ends, for the "left" in its place: the round's; 0 for none
	party:      Discord_Text, // the game's own id, shared by all in it; empty for none
	party_size: i32, // and the players in it, "(5 of 32)" after the state
	party_max:  i32,
	icon_text:  Discord_Text, // over the icon: the game and its version
	join:       Discord_Text, // a server anyone may join, host:port, for a Join game button; empty for none
}

Discord :: struct {
	pipe:      Discord_Pipe, // closed while zero
	ready:     bool, // the handshake answered: activities are heard
	next_try:  f64, // when to look for the app again
	last_sent: f64, // when the last activity went, for Discord's rate limit
	want:      Discord_Activity, // what is to be shown
	dirty:     bool, // and not yet said
	incoming:  [8192]u8, // what has come back, a frame at a time
	in_len:    int,
	skipping:  int, // the rest of a frame too big to keep, thrown away as it comes
}

// What to show; said once it differs from what was, as soon as Discord will hear it.
discord_set :: proc(d: ^Discord, a: Discord_Activity) {
	if d.want == a do return
	d.want = a
	d.dirty = true
}

// Each frame: connecting, the replies, and what is to be said. `enabled` false closes
// the pipe, and with it what is shown.
discord_pump :: proc(d: ^Discord, now: f64, enabled: bool) {
	if !enabled {
		if pipe_is_open(&d.pipe) do disconnect(d)
		d.next_try = 0 // looked for at once when turned back on
		return
	}
	if !pipe_is_open(&d.pipe) {
		if now < d.next_try do return
		d.next_try = now + RETRY_SECONDS
		if !pipe_open(&d.pipe) do return
		if !send_frame(d, .Handshake, `{"v":1,"client_id":"` + DISCORD_APP_ID + `"}`) do return
		d.dirty = true
	}
	read_frames(d)
	if d.ready && d.dirty && now - d.last_sent >= SEND_GAP {
		if send_activity(d) {
			d.dirty = false
			d.last_sent = now
		}
	}
}

discord_close :: proc(d: ^Discord) {
	pipe_close(&d.pipe)
	d.ready = false
}

@(private = "file")
disconnect :: proc(d: ^Discord) {
	pipe_close(&d.pipe)
	d.ready = false
	d.in_len = 0
	d.skipping = 0
	d.dirty = true // what is wanted is said again to the next pipe
}

@(private = "file")
send_frame :: proc(d: ^Discord, op: Op, json: string) -> bool {
	frame: [FRAME_HEADER + FRAME_MOST]u8
	if len(json) > FRAME_MOST do return false
	endian.unchecked_put_u32le(frame[0:], u32(op))
	endian.unchecked_put_u32le(frame[4:], u32(len(json)))
	copy(frame[FRAME_HEADER:], json)
	if pipe_write(&d.pipe, frame[:FRAME_HEADER + len(json)]) do return true
	disconnect(d)
	return false
}

// `s` as a JSON string's contents onto `b`: quotes and controls escaped, and what isn't
// UTF-8 (a server's name in an old codepage) a '?', which Discord would refuse.
@(private = "file")
write_text :: proc(b: ^strings.Builder, s: string) {
	for i := 0; i < len(s); {
		r, width := utf8.decode_rune(s[i:])
		switch {
		case r == utf8.RUNE_ERROR && width <= 1:
			strings.write_byte(b, '?')
		case r == '"' || r == '\\':
			strings.write_byte(b, '\\')
			strings.write_byte(b, u8(r))
		case r < 0x20:
			fmt.sbprintf(b, "\\u%04x", r)
		case:
			strings.write_string(b, s[i:i + width])
		}
		i += max(width, 1)
	}
}

@(private = "file")
send_activity :: proc(d: ^Discord) -> bool {
	@(static) nonce: u32
	nonce += 1
	return send_frame(d, .Frame, discord_activity_json(&d.want, nonce, process_id()))
}

// SET_ACTIVITY's frame for `want`, in the temp allocator.
discord_activity_json :: proc(want: ^Discord_Activity, nonce: u32, pid: int) -> string {
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, `{{"cmd":"SET_ACTIVITY","nonce":"%d","args":{{"pid":%d,"activity":{{`, nonce, pid)
	// Discord refuses a line under two characters, so one so short goes unsaid
	lines := [?]struct {
		key:  string,
		text: string,
	}{{"details", utils.short_string_text(&want.details)}, {"state", utils.short_string_text(&want.state)}}
	for line in lines {
		if len(line.text) < 2 do continue
		fmt.sbprintf(&b, `"%s":"`, line.key)
		write_text(&b, line.text)
		strings.write_string(&b, `",`)
	}
	switch {
	case want.ends > 0:  fmt.sbprintf(&b, `"timestamps":{{"end":%d}},`, want.ends)
	case want.since > 0: fmt.sbprintf(&b, `"timestamps":{{"start":%d}},`, want.since)
	}
	if party := utils.short_string_text(&want.party); party != "" && want.party_max > 0 {
		strings.write_string(&b, `"party":{"id":"`)
		write_text(&b, party)
		fmt.sbprintf(&b, `","size":[%d,%d]}},`, clamp(want.party_size, 1, want.party_max), want.party_max)
	}
	icon_text := utils.short_string_text(&want.icon_text)
	if len(icon_text) < 2 do icon_text = "Soldat Reloaded"
	strings.write_string(&b, `"assets":{"large_image":"` + DISCORD_ICON + `","large_text":"`)
	write_text(&b, icon_text)
	strings.write_string(&b, `"},"buttons":[`)
	// the server's join link first, but only of an address the game would take from one
	if join := utils.short_string_text(&want.join); join != "" {
		if _, ok := link_target(strings.concatenate({LINK_SCHEME + "://join/", join}, context.temp_allocator)); ok {
			strings.write_string(&b, `{"label":"Join game","url":"` + DISCORD_JOIN_PAGE)
			write_text(&b, join)
			strings.write_string(&b, `"},`)
		}
	}
	strings.write_string(&b, DISCORD_BUTTON + `]}}}`)
	return strings.to_string(b)
}

// A whole frame come back: the handshake's READY, an activity's answer, a ping, a close.
@(private = "file")
heard :: proc(d: ^Discord, op: Op, json: string) {
	#partial switch op {
	case .Frame:
		if !d.ready {
			d.ready = true // the handshake's answer: READY, the user's
			d.last_sent = -SEND_GAP
		} else if strings.contains(json, `"evt":"ERROR"`) {
			log.warnf("discord: %s", json)
		}
	case .Ping:
		send_frame(d, .Pong, json)
	case .Close: // the handshake refused, or the app closing
		log.warnf("discord: closed: %s", json)
		disconnect(d)
	}
}

@(private = "file")
read_frames :: proc(d: ^Discord) {
	for pipe_is_open(&d.pipe) {
		chunk: [2048]u8
		got := pipe_read(&d.pipe, chunk[:])
		if got < 0 {
			disconnect(d)
			return
		}
		if got == 0 do return
		rest := chunk[:got]
		for len(rest) > 0 && pipe_is_open(&d.pipe) {
			if d.skipping > 0 { // the rest of a frame too big to keep
				drop := min(len(rest), d.skipping)
				d.skipping -= drop
				rest = rest[drop:]
				continue
			}
			take := min(len(d.incoming) - d.in_len, len(rest))
			copy(d.incoming[d.in_len:], rest[:take])
			d.in_len += take
			rest = rest[take:]
			for d.in_len >= FRAME_HEADER && pipe_is_open(&d.pipe) {
				op := Op(endian.unchecked_get_u32le(d.incoming[0:]))
				size := int(endian.unchecked_get_u32le(d.incoming[4:]))
				if FRAME_HEADER + size > len(d.incoming) { // never kept: its header gone, the rest skipped
					d.skipping = FRAME_HEADER + size - d.in_len
					d.in_len = 0
					// still a READY or a close, if that is what it was, though unread
					if op == .Frame || op == .Close do heard(d, op, "")
					break
				}
				if d.in_len < FRAME_HEADER + size do break
				heard(d, op, string(d.incoming[FRAME_HEADER:][:size]))
				if !pipe_is_open(&d.pipe) do return
				d.in_len -= FRAME_HEADER + size
				copy(d.incoming[:], d.incoming[FRAME_HEADER + size:][:d.in_len])
			}
		}
	}
}
