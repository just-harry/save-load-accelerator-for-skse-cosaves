
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module slack_common.dynamic_linking;

import slack_common.bindings;


version (Windows)
{
	pragma(inline, true)
	bool dynamicallyLinkInto (T) (scope HMODULE dll, scope const(char)[] exportName, scope T* destination)
	{
		const(ANSI_STRING) name = ANSI_STRING.fromString(exportName);
		return LdrGetProcedureAddress(dll, &name, 0, cast(void**) destination) == 0;
	}

	pragma(inline, true)
	bool dynamicallyLinkInto (T) (scope HMODULE dll, scope T* destination)
	{
		return dynamicallyLinkInto!T(dll, __traits(identifier, T), destination);
	}

	pragma(inline, true)
	T dynamicallyLinkAs (T) (scope HMODULE dll, scope const(char)[] exportName)
	{
		T export_ = void;
		dynamicallyLinkInto(dll, exportName, &export_);
		return export_;
	}

	enum string dynamicallyLink (string dll, string name) = `(` ~ dll ~ `).dynamicallyLinkAs!` ~ name ~ `("` ~ name ~ `")`;
}

