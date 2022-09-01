#include <lauxlib.h>

/* TODO proper elune header inclusion */
extern void luaL_openlibsx(lua_State *, int);

static const char sandbox_metatable_name[] = "wowless sandbox";

static int wowless_sandbox_create(lua_State *L) {
  lua_State **p = lua_newuserdata(L, sizeof(*p));
  luaL_getmetatable(L, sandbox_metatable_name);
  lua_setmetatable(L, -2);
  *p = luaL_newstate();
  luaL_openlibsx(*p, 1); /* elune libs only */
  return 1;
}

static lua_State *check_sandbox(lua_State *L) {
  return *(lua_State **)luaL_checkudata(L, 1, sandbox_metatable_name);
}

static int wowless_sandbox_gc(lua_State *L) {
  lua_State *S = check_sandbox(L);
  lua_close(S);
  return 0;
}

static int wowless_sandbox_eval(lua_State *L) {
  lua_State *S = check_sandbox(L);
  const char *str = luaL_checkstring(L, 2);
  lua_settop(S, 0);
  if (luaL_dostring(S, str) != 0) {
    lua_pushstring(L, "eval error");
    lua_error(L);
  }
  int n = lua_gettop(S);
  for (int i = 1; i <= n; ++i) {
    switch (lua_type(S, i)) {
      case LUA_TNUMBER:
        lua_pushnumber(L, lua_tonumber(S, i));
        break;
      case LUA_TSTRING:
        lua_pushstring(L, lua_tostring(S, i));
        break;
      default:
        lua_pushstring(L, "invalid type");
        lua_error(L);
    }
  }
  return n;
}

static struct luaL_Reg sandbox_index[] = {
  {"eval", wowless_sandbox_eval},
  {NULL, NULL},
};

static struct luaL_Reg module_index[] = {
  {"create", wowless_sandbox_create},
  {NULL, NULL},
};

int luaopen_wowless_sandbox(lua_State *L) {
  if (luaL_newmetatable(L, sandbox_metatable_name)) {
    lua_pushstring(L, "__index");
    lua_newtable(L);
    luaL_register(L, NULL, sandbox_index);
    lua_settable(L, -3);
    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, wowless_sandbox_gc);
    lua_settable(L, -3);
    lua_pushstring(L, "__metatable");
    lua_pushstring(L, sandbox_metatable_name);
    lua_settable(L, -3);
  }
  lua_pop(L, 1);
  lua_newtable(L);
  luaL_register(L, NULL, module_index);
  return 1;
}
