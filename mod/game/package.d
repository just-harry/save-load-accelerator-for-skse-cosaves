
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module game;

public import game.target;


enum GameArchetype : ubyte
{
	ae7_104,
	ae7_99,
	ae1170,
	ae1130,
	ae640,
	ae353,
	se,
	vr,
	gog,
	gog659,
}


enum GameArchetype targetedGameArchetype = __traits(getMember, GameArchetype, targetedGameTag);


enum immutable(Char[]) targetedGameVersionFriendlyString (Char) = targetedGameVersionString[0 .. $ - 2];

