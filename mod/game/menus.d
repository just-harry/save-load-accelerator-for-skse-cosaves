
/+ These definitions are based on the work of the Skyrim Script Extender (SKSE).
   (https://skse.silverlock.org/)
   Full credit goes towards the team behind SKSE, those individuals being:
       Ian Patterson; Stephen Abel; Paul Connelly; Brendan Borthwick
       (ianpatt; behippo; scruggsywuggsy the ferret; purple lunchbox).
   Likewise for any contributors to the Script Extender project not named here.
+/

module game.menus;

import game.events;
import game.offsets;


enum EXEBasedOffset!(InternedMenuNames*) internedMenuNames = {ae7_104: 0x021a05c8, ae7_99: 0x021a05c8, ae1170: 0x020f8958, ae1130: 0x020eb658, ae640: 0x01f5a778, ae353: 0x01f5c3f8, se: 0x01ec0a78, vr: 0x01f85100, gog: 0x020f9d58, gog659: 0x01f54778};
enum EXEBasedOffset!(GameMenuState*) gameMenuState = {ae7_104: 0x0219e5c0, ae7_99: 0x0219e5c0, ae1170: 0x020f6a00, ae1130: 0x020e9700, ae640: 0x01f58820, ae353: 0x01f5a4a0, se: 0x01ebeb20, vr: 0x01f83200, gog: 0x020f7e00, gog659: 0x01f52820};


struct InternedMenuNames
{
	mixin(fieldAt!(q{const(char)*}, q{faderMenu}, q{192}));
}


struct GameMenuState
{
	mixin(fieldAt!(q{EventPump!MenuStatusChangeEvent}, q{menuStatusChangeEventPump}, q{8}));
}

