class_name XRStartup
extends RefCounted
## A pure startup gate. No initialize() calls: OpenXR initializes at engine
## startup from project settings; validation must supply --xr-mode off.

static func request_allowed(engine_args: PackedStringArray, user_args: PackedStringArray, headless: bool, project_enabled: bool = false) -> bool:
	if headless:
		return false
	if "--editor" in engine_args or "-e" in engine_args:
		return false
	var xr_on := project_enabled or "--vr" in user_args
	for i in engine_args.size():
		if engine_args[i] == "--xr-mode" and i + 1 < engine_args.size():
			if engine_args[i + 1] == "off":
				return false
			if engine_args[i + 1] == "on":
				xr_on = true
	for argument: String in user_args:
		if argument == "--desktop" or argument == "--smoke" or argument.begins_with("--capture"):
			return false
	return xr_on

static func select_interface(engine_args: PackedStringArray, user_args: PackedStringArray, headless: bool, resolver: Callable, project_enabled: bool = false) -> Object:
	# Lookup itself is guarded; desktop tests cannot touch the runtime provider.
	if not request_allowed(engine_args, user_args, headless, project_enabled):
		return null
	var interface: Object = resolver.call()
	if interface == null or not interface.has_method("is_initialized") or not interface.is_initialized():
		return null
	return interface
