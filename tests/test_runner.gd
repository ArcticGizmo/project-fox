extends Node
## Headless test runner. Discovers tests/unit/test_*.gd and runs every test_*
## method on a fresh instance. Exit code = number of failed tests (0 = pass).
##
##   godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
##   ... -- --filter=bull        (only tests whose file or method contains "bull")
##
## Prefer tools/test.ps1, which also fails the run on engine/script errors.

const TEST_DIR := "res://tests/unit"


func _ready() -> void:
	GameFeel.hit_stop_enabled = false
	GameFeel.damage_numbers_enabled = false
	await get_tree().process_frame
	var filter := _get_filter()
	var passed := 0
	var failed := 0
	var start_ms := Time.get_ticks_msec()

	for path: String in _find_tests():
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL  %s: could not load script (parse error?)" % path)
			failed += 1
			continue
		var file_name := path.get_file().get_basename()
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			if filter != "" and not (filter in file_name or filter in method_name):
				continue
			var case := script.new() as TestCase
			add_child(case)
			await case.before_each()
			var t0 := Time.get_ticks_msec()
			await case.call(method_name)
			var label := "%s.%s (%d ms)" % [file_name, method_name, Time.get_ticks_msec() - t0]
			if case.failures.is_empty():
				print("PASS  " + label)
				passed += 1
			else:
				print("FAIL  " + label)
				for f: String in case.failures:
					print("        - " + f)
				failed += 1
			case.queue_free()
			await get_tree().physics_frame
			await get_tree().physics_frame
			DebugSettings.show_boxes = false
			GameFeel.reset()
			Sfx.reset()
			get_tree().paused = false

	print("")
	print("%d passed, %d failed (%d ms)" % [passed, failed, Time.get_ticks_msec() - start_ms])
	# Let the audio thread drop stopped voices (real time: --fixed-fps frames are
	# near-instant), or their playbacks leak at exit.
	Sfx.stop_all()
	for _i: int in 3:
		await get_tree().process_frame
		OS.delay_msec(50)
	get_tree().quit(failed)


func _get_filter() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""


func _find_tests() -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(TEST_DIR.path_join(f))
	out.sort()
	return out
