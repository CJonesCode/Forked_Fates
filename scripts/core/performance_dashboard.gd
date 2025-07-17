extends Node

## Performance Dashboard for Development Builds
## Global access to performance monitoring and profiling tools

# Performance monitor instance
var performance_monitor: PerformanceMonitor

# Dashboard configuration
var enable_dashboard: bool = false  # Only enable in debug builds
var auto_report_interval: float = 10.0  # Auto-report every 10 seconds
var report_timer: Timer

func _ready() -> void:
	# Only enable in debug builds
	if OS.is_debug_build():
		enable_dashboard = true
	
	if enable_dashboard:
		# Create performance monitor
		performance_monitor = PerformanceMonitor.new()
		add_child(performance_monitor)
		
		# Setup auto-reporting
		_setup_auto_reporting()
		
		Logger.system("PerformanceDashboard enabled for debug build", "PerformanceDashboard")
	else:
		Logger.debug("PerformanceDashboard disabled for release build", "PerformanceDashboard")

## Setup automatic performance reporting
func _setup_auto_reporting() -> void:
	if not enable_dashboard:
		return
	
	report_timer = Timer.new()
	report_timer.wait_time = auto_report_interval
	report_timer.timeout.connect(_auto_performance_report)
	report_timer.autostart = true
	add_child(report_timer)

## Automatic performance report
func _auto_performance_report() -> void:
	if performance_monitor:
		performance_monitor.print_performance_report()

## Start profiling marker (global access)
func start_profiling(marker_name: String) -> void:
	if performance_monitor:
		performance_monitor.start_profiling_marker(marker_name)

## End profiling marker (global access)
func end_profiling(marker_name: String) -> float:
	if performance_monitor:
		return performance_monitor.end_profiling_marker(marker_name)
	return 0.0

## Get performance report (global access)
func get_performance_report() -> Dictionary:
	if performance_monitor:
		return performance_monitor.get_performance_report()
	return {}

## Print performance report (global access)
func print_performance_report() -> void:
	if performance_monitor:
		performance_monitor.print_performance_report()

## Check if performance is healthy (global access)
func is_performance_healthy() -> bool:
	if performance_monitor:
		return performance_monitor.is_performance_healthy()
	return true

## Enable or disable dashboard
func set_dashboard_enabled(enabled: bool) -> void:
	enable_dashboard = enabled
	if performance_monitor:
		performance_monitor.configure_monitoring(enabled, enabled, enabled)

## Convenience method for profiling code blocks
func profile_code_block(marker_name: String, code_block: Callable) -> float:
	if not enable_dashboard:
		code_block.call()
		return 0.0
	
	start_profiling(marker_name)
	code_block.call()
	return end_profiling(marker_name) 