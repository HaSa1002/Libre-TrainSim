class_name ScenarioRoute
extends Resource

# to overwrite default rail logic, I guess?
# Dict[String, RailLogicSettings] ; RailLogicNodeName -> Settings
export (Dictionary) var rail_logic_settings := {}

# Array[RoutePoint]
export (Array, Resource) var route_points := []

export (bool) var activate_only_at_specific_routes := false  # ?????
export (Array, String) var specific_routes := []  # ???

export (bool) var is_playable := true  # for AI trains set to false, I guess
export (String) var train_name := "JFR1_Red"  # which train drives here

export (String) var description := ""

# example:
# route begins at 6:00, goes every 15 minutes, ends at 21:00
# interval_start = 21600
# interval_end = 75600
# interval = 900
export (int) var interval := 0  # how frequently this route drives, in minutes
export (int) var interval_end := 0  # last time of day this route drives, in seconds
export (int) var interval_start := 0  # first time of day this route drives, in seconds

# calculated data
var calculated_rail_route := []
var error_route_point_start_index: int
var error_route_point_end_index: int


# because Godot's initialisation sucks so hard,
# if we don't do it manually, all instances share the same arrays / dicts
func _init() -> void:
	rail_logic_settings = {}
	route_points = []
	specific_routes = []
	calculated_rail_route = []


func duplicate(recursive: bool = true):
	var copy = get_script().new()

	copy.description = description
	copy.train_name = train_name
	copy.is_playable = is_playable
	copy.activate_only_at_specific_routes = activate_only_at_specific_routes
	copy.specific_routes = specific_routes.duplicate(true)
	copy.interval = interval
	copy.interval_start = interval_start
	copy.interval_end = interval_end

	copy.route_points = []
	for p in route_points:
		var pcopy = p.duplicate(true)
		copy.route_points.append(pcopy)

	copy.rail_logic_settings = {}
	for s in rail_logic_settings:
		copy.rail_logic_settings[s] = rail_logic_settings[s].duplicate(true)

	return copy


##### ROUTE MANAGER FUNCTIONS
func get_point_description(index: int) -> String:
	return route_points[index].get_description()


func get_point(index: int) -> RoutePoint:
	return route_points[index].duplicate(true)


func size() -> int:
	return route_points.size()


func get_start_times() -> Array:
	var times := []

	var time: int = interval_start
	times.append(time)

	if interval == 0:
		return times

	while(time < interval_end):
		time += interval * 60  # minutes to seconds
		times.append(time)

	#print(times)
	return times


func get_calculated_station_points(start_time: int) -> Array:
	var time: int = start_time
	var station_table := []

	for route_point in route_points:
		if not route_point is RoutePointStation:
			continue

		var p: RoutePoint = route_point.duplicate(true)
		if p.stop_type != StopType.BEGINNING:
			time += p.duration_since_last_station
		p.arrival_time = time
		time += p.planned_halt_time
		p.departure_time = time
		station_table.append(p)

	return station_table


func get_station_index(index: int):
	if not route_points[index] is RoutePointStation:
		return -1

	var station_index: int = 0
	for i in range(index):
		if route_points[i] is RoutePointStation:
			station_index += 1
	#print(station_index)
	return station_index


func get_calculated_station_point(index: int, start_time: int):
	var station_index: int = get_station_index(index)
	var station_table: Array = get_calculated_station_points(start_time)
	return station_table[station_index]


func _get_rail(world: Node, route_point: RoutePoint) -> Node:
	if route_point is RoutePointStation:
		var station: Node = world.get_signal(route_point.station_node_name)
		if station == null:
			return null
		return world.get_rail(station.attached_rail)
	return world.get_rail(route_point.rail_name)


func get_calculated_rail_route(world: Node) -> Array:
	world.update_rail_connections()
	var route: Array = []
	var forward = null

	for i in range(size()-1):
		var start = _get_rail(world, route_points[i])
		var end = _get_rail(world, route_points[i+1])

		# first time, have to check both directions, we don't know where to go!
		if forward == null:
			var path_fwd = world.get_path_from_to(start, true, end)
			var path_bwd = world.get_path_from_to(start, false, end)

			# no route found, return nothing
			if path_fwd == [] and path_bwd == []:
				error_route_point_start_index = i
				error_route_point_end_index = i+1
				return []

			if path_fwd == []:
				route.append_array(path_bwd)
			else:
				route.append_array(path_fwd)
			forward = route.back().forward  # keep searching in the direction of the last rail

		else:
			var path: Array = world.get_path_from_to(start, forward, end)
			if path == []:
				error_route_point_start_index = i
				error_route_point_end_index = i+1
				return []

			# last destination rail == this start rail
			# so the rail is already in route, don't add it again!
			path.pop_front()
			route.append_array(path)

	calculated_rail_route = route.duplicate(true)
	return route


# call get_calculated_rail_route() before!
func get_spawn_point(train_length, world: Node) -> RoutePointSpawnPoint:
	var start_point: RoutePoint = route_points[0]

	if start_point is RoutePointSpawnPoint:
		start_point.forward = calculated_rail_route[0].forward
		return start_point as RoutePointSpawnPoint

	elif start_point is RoutePointStation:
		var spawn_point = RoutePointSpawnPoint.new()
		var station_node: Node = world.get_signal(start_point.station_node_name)

		spawn_point.distance_on_rail = station_node.get_perfect_halt_distance_on_rail(train_length)
		spawn_point.rail_name = station_node.attached_rail
		spawn_point.forward = station_node.forward
		spawn_point.initial_speed = 0
		spawn_point.initial_speed_limit = -1
		return spawn_point

	return null


func get_despawn_point() -> RoutePoint:
	return route_points.back().duplicate(true)


func get_minimal_platform_length(world: Node) -> int:
	# Can't use INF here, because then 'if minimal_platform_length > station_node.length:' won't trigger
	var minimal_platform_length: int = 1000000000000
	for route_point in route_points:
		if route_point is RoutePointStation and route_point.stop_type != StopType.DO_NOT_STOP:
				var station_node: Node = world.get_signal(route_point.station_node_name)
				if minimal_platform_length > station_node.length:
					minimal_platform_length = station_node.length
	return minimal_platform_length


func remove_point(index: int):
	route_points.remove(index)


func clear_route():
	route_points.clear()


func move_point_up(index: int) -> void:
	if index == 0:
		return
	var tmp = route_points[index-1]
	route_points[index-1] = route_points[index]
	route_points[index] = tmp


func move_point_down(index: int) -> void:
	if index >= route_points.size():
		return
	var tmp = route_points[index+1]
	route_points[index+1] = route_points[index]
	route_points[index] = tmp
