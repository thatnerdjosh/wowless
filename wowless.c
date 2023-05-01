#include <stdlib.h>
#include <stdio.h>
#include "lualib.h"
#include "lauxlib.h"

int main(int argc, char **argv) {
  lua_State *L = luaL_newstate();
  if (L == NULL) {
    return EXIT_FAILURE;
  }
  luaL_openlibsx(L, LUALIB_ELUNE);
  luaL_openlibsx(L, LUALIB_STANDARD);
  lua_newtable(L);
  for (int i = 0; i < argc; ++i) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i);
  }
  lua_setglobal(L, "arg");
  if (luaL_dofile(L, "wowless.lua") != 0) {
    puts(lua_tostring(L, -1));
  }
  lua_close(L);
  return EXIT_SUCCESS;
}
