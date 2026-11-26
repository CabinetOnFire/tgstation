/// Conveys all log_mapping messages as unit test failures, as they all indicate mapping problems.
/datum/unit_test/maptest_log_mapping
	test_flags = UNIT_TEST_MAP_TEST
	// Happen before all other tests, to make sure we only capture normal mapping logs.
	priority = TEST_PRE

/datum/unit_test/maptest_log_mapping/Run()
	for(var/log_entry in GLOB.unit_test_mapping_logs)
		TEST_FAIL(log_entry)

/// Checks that the same seed gives the same cave shape in a small slice of Lavaland.
/datum/unit_test/lavaland_seed_replays_cave_slice/Run()
	var/area/test_area = get_area(run_loc_floor_bottom_left)
	var/datum/map_generator/cave_generator/lavaland/first_generator = allocate(/datum/map_generator/cave_generator/lavaland)
	var/datum/map_generator/cave_generator/lavaland/second_generator = allocate(/datum/map_generator/cave_generator/lavaland)
	var/seed = "lavaland-cave-unit-test"
	var/first_layout = first_generator.generate_cave(test_area, seed)
	var/second_layout = second_generator.generate_cave(test_area, seed)

	var/expected_length = world.maxx * world.maxy
	TEST_ASSERT_EQUAL(length(first_layout), expected_length, "The first cave layout was incomplete.")
	TEST_ASSERT_EQUAL(length(second_layout), expected_length, "The second cave layout was incomplete.")
	TEST_ASSERT(findtext(first_layout, "0") && findtext(first_layout, "1"), "Expected the cave layout to have walls and floors.")

	var/slice_size = 32
	var/start_x = max(1, round((world.maxx - slice_size) / 2) + 1)
	var/start_y = max(1, round((world.maxy - slice_size) / 2) + 1)
	var/row_width = min(slice_size, world.maxx - start_x + 1)
	var/end_y = min(world.maxy, start_y + slice_size - 1)
	for (var/y in start_y to end_y)
		var/row_start = (y - 1) * world.maxx + start_x
		var/row_end = row_start + row_width
		TEST_ASSERT_EQUAL(copytext(first_layout, row_start, row_end), copytext(second_layout, row_start, row_end), "The same seed gave different cave tiles at y=[y].")
