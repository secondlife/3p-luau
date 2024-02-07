# 3p-luau

Luau (lowercase u, /ˈlu.aʊ/) is a fast, small, safe, gradually typed embeddable scripting language derived from [Lua](http://www.lua.org/).

It is designed to be backwards compatible with Lua 5.1, as well as incorporating [some features](https://luau-lang.org/compatibility) from future Lua releases, but also expands the feature set (most notably with type annotations). Luau is largely implemented from scratch, with the language runtime being a very heavily modified version of Lua 5.1 runtime, with completely rewritten interpreter and other [performance innovations](https://luau-lang.org/performance). The runtime mostly preserves Lua 5.1 API, so existing bindings should be more or less compatible with a few caveats.
