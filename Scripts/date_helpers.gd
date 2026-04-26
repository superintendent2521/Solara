extends RefCounted
class_name DateHelpers

static func get_next_month(current_month: int, current_year: int) -> Dictionary:
	var next_month = current_month + 1
	var next_year = current_year

	if next_month > 12:
		next_month = 1
		next_year += 1

	return {
		"month": next_month,
		"year": next_year,
	}
