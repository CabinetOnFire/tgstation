///Get a random food item exluding the blocked ones
/proc/get_random_food()
	var/static/list/allowed_food = list()

	if(!LAZYLEN(allowed_food)) //it's static so we only ever do this once
		var/list/blocked = list() // This used to be populated

		allowed_food = get_sane_item_types(/obj/item/food) - blocked

	return pick(allowed_food)

///Gets a random drink excluding the blocked type
/proc/get_random_drink()
	var/static/list/allowed_drinks = list()

	if(!LAZYLEN(allowed_drinks))
		var/list/blocked = list(
			/obj/item/reagent_containers/cup/glass/bottle
		)

		allowed_drinks = get_sane_item_types(/obj/item/reagent_containers/cup/glass) + get_sane_item_types(/obj/item/reagent_containers/cup/soda_cans) - blocked

	return pick(allowed_drinks)

///Picks a string of symbols to display as the law number for hacked or ion laws
/proc/ion_num() //! is at the start to prevent us from changing say modes via get_message_mode()
	return "![pick("!","@","#","$","%","^","&")][pick("!","@","#","$","%","^","&","*")][pick("!","@","#","$","%","^","&","*")][pick("!","@","#","$","%","^","&","*")]"

///Returns a string for a random nuke code
/proc/random_nukecode()
	var/val = rand(0, 99999)
	var/str = "[val]"
	while(length(str) < 5)
		str = "0" + str
	. = str

///Gets a random coin excluding the blocked type and including extra coins which aren't pathed like coins.
/proc/get_random_coin()
	var/list/blocked = list(
		/obj/item/coin/gold/debug,
		/obj/item/coin/eldritch,
		/obj/item/coin/mythril,
	)
	var/list/extra_coins = list(
		/obj/item/food/chococoin,
	)
	var/list/allowed_coins = subtypesof(/obj/item/coin) - blocked + extra_coins
	return pick(allowed_coins)

#define RANDOM_GENERATION_BATCH_SIZE 128
#define RANDOM_GENERATION_HEX_DIGITS "0123456789abcdef"
#define RANDOM_GENERATION_SAMPLE_DIGITS 6
#define RANDOM_GENERATION_SAMPLE_RANGE (1 << 24)

/// Seeded random rolls. Use the same seed to get the same draws again. Without a seed, this uses BYOND rng for a sneed
/datum/random_generation
	var/seed
	var/batch = 0
	var/buffer = ""
	var/offset = 1
	var/alist/indexed_batches

/// Save the seed. If there isn't one, generate one with byond's rng
/datum/random_generation/New(seed)
	src.seed = seed

/// Roll a whole number from low to high, including both ends.
/datum/random_generation/proc/rand_range(low, high)
	if (isnull(seed))
		return rand(low, high)
	if (high <= low)
		return low
	var/width = high - low + 1
	var/limit = sampling_limit(width)
	while (TRUE)
		if (offset > length(buffer))
			buffer = generate_batch("[batch++]")
			offset = 1
		var/sample = read_sample(buffer, offset)
		offset += RANDOM_GENERATION_SAMPLE_DIGITS
		if (sample < limit)
			return low + sample % width

/// Roll for a specific index, starting at zero. With a seed, the order you ask for rolls in doesn't matter.
/datum/random_generation/proc/rand_range_at(index, low, high)
	if (isnull(seed))
		return rand(low, high)
	if (high <= low)
		return low
	var/width = high - low + 1
	var/limit = sampling_limit(width)
	var/batch_key = "[round(index / RANDOM_GENERATION_BATCH_SIZE)]"
	indexed_batches ||= alist()
	var/digits = indexed_batches[batch_key]
	if (isnull(digits))
		digits = generate_batch("index/[batch_key]")
		indexed_batches[batch_key] = digits
	var/sample = read_sample(digits, (index % RANDOM_GENERATION_BATCH_SIZE) * RANDOM_GENERATION_SAMPLE_DIGITS + 1)
	var/retry = 0
	while (sample >= limit)
		sample = read_sample(generate_batch("index/[index]/retry/[retry++]"), 1)
	return low + sample % width

/// Find where to start rerolling so every number in the requested range has the same odds.
/datum/random_generation/proc/sampling_limit(width)
	// No more than six hex digits. (byond limit)
	if (width > RANDOM_GENERATION_SAMPLE_RANGE)
		CRASH("Random generation interval is too wide")
	return RANDOM_GENERATION_SAMPLE_RANGE - (RANDOM_GENERATION_SAMPLE_RANGE % width)

/// Get a batch of random numbers as hex text so we can make several rolls per rust-g call. byondapi 2027....
/datum/random_generation/proc/generate_batch(batch_key)
	var/digits = rustg_prng_chacha20_seeded(RUSTG_RNG_FORMAT_HEX, RANDOM_GENERATION_BATCH_SIZE * RANDOM_GENERATION_SAMPLE_DIGITS / 2, "[seed]/[batch_key]")
	if (length(digits) != RANDOM_GENERATION_BATCH_SIZE * RANDOM_GENERATION_SAMPLE_DIGITS)
		CRASH("Invalid rust-g random stream")
	return digits

/// Read six hex digits starting at offset and turn them into a number.
/datum/random_generation/proc/read_sample(digits, offset)
	var/sample = 0
	for (var/i in 1 to RANDOM_GENERATION_SAMPLE_DIGITS)
		var/digit_value = findtextEx(RANDOM_GENERATION_HEX_DIGITS, digits[offset++]) - 1
		sample = sample * 16 + digit_value
	return sample

/// Roll a percentage chance. Returns true if it hits.
/datum/random_generation/proc/chance(percent)
	if (isnull(seed))
		return prob(percent)
	return rand_range(0, RANDOM_GENERATION_SAMPLE_RANGE - 1) < percent * (RANDOM_GENERATION_SAMPLE_RANGE / 100)

/// Pick a key from the alist. (no list for u noob)
/datum/random_generation/proc/pick_weighted(alist/weights)
	var/total = 0
	for (var/item in weights)
		total += weights[item]
	if (total <= 0)
		return null
	var/draw = rand_range(1, total)
	for (var/item in weights)
		draw -= weights[item]
		if (draw <= 0)
			return item
	return null

/// Pick a random item from a list, or return null if it's empty.
/datum/random_generation/proc/pick_from(list/choices)
	if (length(choices))
		return choices[rand_range(1, length(choices))]

#undef RANDOM_GENERATION_SAMPLE_RANGE
#undef RANDOM_GENERATION_SAMPLE_DIGITS
#undef RANDOM_GENERATION_HEX_DIGITS
#undef RANDOM_GENERATION_BATCH_SIZE
