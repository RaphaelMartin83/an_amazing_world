extends RefCounted
# ============================================================================
#  THE HERO: everything that makes the main character look like your friend.
#  Edit these values (or send reference photos and they get tuned for you).
#
#   hair_style : "short" | "messy" | "spiky" | "buzz" | "long" | "curly" | "bald"
#   beard      : "none" | "stubble" | "full" | "goatee"
#   moustache  : true / false
#   accessory  : "none" | "cap" | "headband"
# ============================================================================

const HERO := {
	"name": "Palmouze",
	"skin": Color("efb99a"),
	"hair_style": "messy",
	"hair_color": Color("15100e"),
	"beard": "full",
	"moustache": false,
	"glasses": false,
	"glasses_color": Color("1b1b22"),
	"eye_color": Color("4a2f1c"),
	"shirt": Color("e3a82b"),   # mustard yellow t-shirt
	"shirt_text": "",
	"pants": Color("2b3a5c"),
	"shoes": Color("f4f4f4"),
	"gloves": Color("f4f4f4"),
	"accessory": "none",
	"accessory_color": Color("d93636"),
	# proportions (1.0 = default)
	"head_scale": 1.0,
	"face_width": 0.95,
	"nose": 1.25,
	"brow": 1.5,
	"ears": 1.05,
	"build": 0.95,
	"height": 1.0,
}
