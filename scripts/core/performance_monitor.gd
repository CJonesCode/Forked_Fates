class_name PerformanceMonitor
extends Node

## Performance Monitor for Development Builds
## Provides profiling markers, metrics tracking, and performance dashboard

# Performance tracking
var frame_times: Array[float] = []
var memory_usage_history: Array[int] = []
var object_counts: Dictionary = {}
var profiling_markers: Dictionary = {}

# Configuration
var max_history_size: int = 300  # 5 seconds at 60 FPS
var update_interval: float = 0.1
var enable_profiling: bool = true
var enable_memory_tracking: bool = true
var enable_object_tracking: bool = true

# Monitoring state
var update_timer: Timer
var last_memory_usage: int = 0
var profiling_start_times: Dictionary = {}

# Performance signals
signal performance_warning(metric: String, value: float, threshold: float)
signal memory_spike_detected(current_usage: int, spike_amount: int)
signal frame_drop_detected(dropped_frames: int)

# Performance thresholds
var frame_time_warning_threshold: float = 16.67  # 60 FPS
var memory_spike_threshold: int = 50 * 1024 * 1024  # 50 MB
var object_count_warning_threshold: int = 1000

func _ready() -> void:
	# Setup update timer
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_update_performance_metrics)
	update_timer.autostart = true
	add_child(update_timer)
	
	# Initialize arrays
	frame_times.resize(max_history_size)
	memory_usage_history.resize(max_history_size)
	
	Logger.system("PerformanceMonitor initialized with profiling: " + str(enable_profiling), "PerformanceMonitor")

func _process(_delta: float) -> void:
	if enable_profiling:
		_track_frame_time()

## Track frame time for performance analysis
func _track_frame_time() -> void:
	var frame_time: float = get_process_delta_time() * 1000.0  # Convert to milliseconds
	
	# Add to history (circular buffer)
	frame_times.append(frame_time)
	if frame_times.size() > max_history_size:
		frame_times.remove_at(0)
	
	# Check for frame drops
	if frame_time > frame_time_warning_threshold:
		performance_warning.emit("frame_time", frame_time, frame_time_warning_threshold)

## Update performance metrics periodically
func _update_performance_metrics() -> void:
	if enable_memory_tracking:
		_track_memory_usage()
	
	if enable_object_tracking:
		_track_object_counts()

## Track memory usage
func _track_memory_usage() -> void:
	var current_memory: int = OS.get_static_memory_usage()  # Get total static memory usage
	
	# Add to history
	memory_usage_history.append(current_memory)
	if memory_usage_history.size() > max_history_size:
		memory_usage_history.remove_at(0)
	
	# Check for memory spikes
	if last_memory_usage > 0:
		var memory_diff: int = current_memory - last_memory_usage
		if memory_diff > memory_spike_threshold:
			memory_spike_detected.emit(current_memory, memory_diff)
	
	last_memory_usage = current_memory

## Track object counts by type
func _track_object_counts() -> void:
	# Get current object counts from object pools
	if PoolManager:
		var pool_stats: Dictionary = PoolManager.get_pool_statistics()
		object_counts["pooled_objects"] = {}
		
		for scene_path in pool_stats.keys():
			var stats: Dictionary = pool_stats[scene_path]
			object_counts["pooled_objects"][scene_path] = stats.pool_size

## Start profiling marker
func start_profiling_marker(marker_name: String) -> void:
	if not enable_profiling:
		return
	
	profiling_start_times[marker_name] = Time.get_unix_time_from_system()
	Logger.debug("Started profiling marker: " + marker_name, "PerformanceMonitor")

## End profiling marker and record duration
func end_profiling_marker(marker_name: String) -> float:
	if not enable_profiling or not profiling_start_times.has(marker_name):
		return 0.0
	
	var start_time: float = profiling_start_times[marker_name]
	var end_time: float = Time.get_unix_time_from_system()
	var duration: float = (end_time - start_time) * 1000.0  # Convert to milliseconds
	
	# Store in profiling markers
	if not profiling_markers.has(marker_name):
		profiling_markers[marker_name] = []
	
	var marker_history: Array = profiling_markers[marker_name]
	marker_history.append(duration)
	
	# Limit history size
	if marker_history.size() > max_history_size:
		marker_history.remove_at(0)
	
	profiling_start_times.erase(marker_name)
	Logger.debug("Profiling marker '" + marker_name + "' completed in " + str(duration) + "ms", "PerformanceMonitor")
	
	return duration

## Get average frame time
func get_average_frame_time() -> float:
	if frame_times.is_empty():
		return 0.0
	
	var total: float = 0.0
	for time in frame_times:
		total += time
	
	return total / frame_times.size()

## Get current FPS estimate
func get_current_fps() -> float:
	var avg_frame_time: float = get_average_frame_time()
	if avg_frame_time <= 0:
		return 0.0
	
	return 1000.0 / avg_frame_time

## Get memory usage statistics
func get_memory_stats() -> Dictionary:
	if memory_usage_history.is_empty():
		return {}
	
	var current: int = memory_usage_history.back()
	var min_usage: int = memory_usage_history.min()
	var max_usage: int = memory_usage_history.max()
	
	return {
		"current": current,
		"min": min_usage,
		"max": max_usage,
		"average": _calculate_average(memory_usage_history)
	}

## Get profiling marker statistics
func get_profiling_stats(marker_name: String) -> Dictionary:
	if not profiling_markers.has(marker_name):
		return {}
	
	var marker_history: Array = profiling_markers[marker_name]
	if marker_history.is_empty():
		return {}
	
	return {
		"count": marker_history.size(),
		"average": _calculate_average(marker_history),
		"min": marker_history.min(),
		"max": marker_history.max(),
		"latest": marker_history.back()
	}

## Get comprehensive performance report
func get_performance_report() -> Dictionary:
	return {
		"fps": get_current_fps(),
		"frame_time": {
			"average": get_average_frame_time(),
			"current": frame_times.back() if not frame_times.is_empty() else 0.0
		},
		"memory": get_memory_stats(),
		"object_counts": object_counts,
		"profiling_markers": _get_all_profiling_stats(),
		"timestamp": Time.get_unix_time_from_system()
	}

## Get all profiling marker statistics
func _get_all_profiling_stats() -> Dictionary:
	var all_stats: Dictionary = {}
	
	for marker_name in profiling_markers.keys():
		all_stats[marker_name] = get_profiling_stats(marker_name)
	
	return all_stats

## Calculate average of array values
func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	
	var total: float = 0.0
	for value in values:
		total += value
	
	return total / values.size()

## Print performance report to console
func print_performance_report() -> void:
	var report: Dictionary = get_performance_report()
	
	Logger.system("=== Performance Report ===", "PerformanceMonitor")
	Logger.system("FPS: " + str("%.1f" % report.fps), "PerformanceMonitor")
	Logger.system("Frame Time: " + str("%.2f" % report.frame_time.average) + "ms (current: " + str("%.2f" % report.frame_time.current) + "ms)", "PerformanceMonitor")
	
	if report.memory.has("current"):
		Logger.system("Memory: " + str("%.1f" % (report.memory.current / (1024.0 * 1024.0))) + "MB", "PerformanceMonitor")
	
	Logger.system("Object Counts:", "PerformanceMonitor")
	for object_type in report.object_counts.keys():
		Logger.system("  " + object_type + ": " + str(report.object_counts[object_type]), "PerformanceMonitor")
	
	Logger.system("Profiling Markers:", "PerformanceMonitor")
	for marker_name in report.profiling_markers.keys():
		var stats: Dictionary = report.profiling_markers[marker_name]
		if not stats.is_empty():
			Logger.system("  " + marker_name + ": " + str("%.2f" % stats.average) + "ms avg (" + str(stats.count) + " samples)", "PerformanceMonitor")

## Clear all performance history
func clear_performance_history() -> void:
	frame_times.clear()
	memory_usage_history.clear()
	profiling_markers.clear()
	object_counts.clear()
	
	Logger.debug("Performance history cleared", "PerformanceMonitor")

## Configure monitoring settings
func configure_monitoring(profiling: bool, memory_tracking: bool, object_tracking: bool) -> void:
	enable_profiling = profiling
	enable_memory_tracking = memory_tracking
	enable_object_tracking = object_tracking
	
	Logger.debug("Performance monitoring configured - Profiling: " + str(profiling) + ", Memory: " + str(memory_tracking) + ", Objects: " + str(object_tracking), "PerformanceMonitor")

## Set performance thresholds
func set_performance_thresholds(frame_time_threshold: float, memory_threshold: int, object_threshold: int) -> void:
	frame_time_warning_threshold = frame_time_threshold
	memory_spike_threshold = memory_threshold
	object_count_warning_threshold = object_threshold
	
	Logger.debug("Performance thresholds updated", "PerformanceMonitor")

## Check if performance is within acceptable bounds
func is_performance_healthy() -> bool:
	var avg_frame_time: float = get_average_frame_time()
	var current_memory: int = memory_usage_history.back() if not memory_usage_history.is_empty() else 0
	
	return avg_frame_time <= frame_time_warning_threshold and current_memory < memory_spike_threshold

func _exit_tree() -> void:
	clear_performance_history()
	Logger.debug("PerformanceMonitor cleanup completed", "PerformanceMonitor") 