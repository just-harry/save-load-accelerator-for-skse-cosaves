
/+ These definitions are based on the work of the Skyrim Script Extender (SKSE).
   (https://skse.silverlock.org/)
   Full credit goes towards the team behind SKSE, those individuals being:
       Ian Patterson; Stephen Abel; Paul Connelly; Brendan Borthwick
       (ianpatt; behippo; scruggsywuggsy the ferret; purple lunchbox).
   Likewise for any contributors to the Script Extender project not named here.
+/

module game.events;

import game.offsets;


enum EXEBasedOffset!(
	void function (scope void* eventPump, void* eventHandler) nothrow @nogc
) registerGameEventHandler = {ae7_99: 0x005eb220, ae1170: 0x005dc8c0, ae1130: 0x005dbfe0, ae640: 0x0058f4e0, ae353: 0x00587e20, se: 0x0056b600, vr: 0x00571c00, gog: 0x005ded40, gog659: 0x0058f0a0};


enum EXEBasedOffset!(
	void function (scope void* eventPump, void* eventHandler) nothrow @nogc
) deregisterGameEventHandler = {ae7_99: 0x00485830, ae1170: 0x0047e310, ae1130: 0x0047e220, ae640: 0x0043e990, ae353: 0x0043c400, se: 0x00423b70, vr: 0x004336c0, gog: 0x0047e450, gog659: 0x0043e920};


enum EventContinuance : uint
{
	go = 0,
	stop = 1
}


struct EventPump (Event)
{}


extern(C++)
abstract class GameEventHandler (Event)
{
	~this () scope nothrow @nogc {}
	EventContinuance handle (scope Event* event, scope EventPump!Event* pump) scope nothrow @nogc;
}


struct MenuStatusChangeEvent
{
	const(char)* menuName;
	bool menuIsOpening;


	pragma(inline, true)
	bool menuIsClosing () () const @property scope
	{
		return !this.menuIsOpening;
	}
}
