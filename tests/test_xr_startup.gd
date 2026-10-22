extends SceneTree

const Startup = preload("res://scripts/input/xr_startup.gd")
var checks: int = 0
var failures: int = 0
var lookups: int = 0

class MockInterface extends RefCounted:
	var initialized: bool = false
	func is_initialized() -> bool:
		return initialized

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	check(not Startup.request_allowed([], [], false), "Godot Play defaults to desktop without runtime lookup")
	check(Startup.request_allowed([], [], false, true), "enabled project can still select VR")
	check(Startup.request_allowed([], ["--vr"], false), "retained VR flag survives engine argument consumption")
	check(Startup.request_allowed(["--xr-mode", "on"], [], false), "engine on needs no user flag")
	check(not Startup.request_allowed([], [], false, false), "disabled project stays desktop")
	check(Startup.request_allowed(["--xr-mode", "on"], [], false, false), "explicit on overrides disabled project")
	check(Startup.request_allowed(["--xr-mode", "default"], [], false, true), "default mode respects enabled project")
	check(not Startup.request_allowed([], ["--desktop"], false), "retained desktop flag blocks runtime after Godot consumes engine flags")
	check(not Startup.request_allowed(["--xr-mode", "off"], ["--vr"], false), "XR off wins over user flag")
	check(not Startup.request_allowed(["--xr-mode", "on"], ["--vr"], true), "headless blocks runtime")
	check(not Startup.request_allowed(["--editor", "--xr-mode", "on"], ["--vr"], false), "editor blocks runtime selection")
	check(not Startup.request_allowed(["--xr-mode", "on"], ["--vr", "--smoke"], false), "smoke cannot enter XR")
	check(not Startup.request_allowed(["--xr-mode", "on"], ["--vr", "--capture=x.png"], false), "capture cannot enter XR")
	check(Startup.request_allowed(["--xr-mode", "on"], ["--vr"], false), "legacy VR launcher remains accepted")
	var mock := MockInterface.new()
	var resolver := func() -> Object: lookups += 1; return mock
	check(Startup.select_interface(["--xr-mode", "off"], ["--vr"], false, resolver) == null and lookups == 0, "blocked selection never calls resolver")
	check(Startup.select_interface(["--xr-mode", "off"], [], false, resolver) == null and lookups == 0, "test override blocks lookup with project default on")
	check(Startup.select_interface([], ["--desktop"], false, resolver) == null and lookups == 0, "desktop launch never calls provider")
	check(Startup.select_interface(["--xr-mode", "on"], ["--vr"], false, resolver) == null and lookups == 1, "uninitialized provider falls back")
	mock.initialized = true
	check(Startup.select_interface([], [], false, resolver) == null and lookups == 1, "desktop default skips even an initialized provider")
	check(Startup.select_interface([], ["--vr"], false, resolver) == mock, "opt-in launcher selects initialized provider")
	var missing := func() -> Object: return null
	check(Startup.select_interface(["--xr-mode", "on"], ["--vr"], false, missing) == null, "missing provider falls back")
	var map := load("res://resources/xr/default_action_map.tres") as OpenXRActionMap
	check(map != null and not map.action_sets.is_empty(), "bundled action map loads")
	print("XR STARTUP CHECKS: ", checks, " failures: ", failures, "; mock providers only; no XR initialized")
	quit(1 if failures else 0)
