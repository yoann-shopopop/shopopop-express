class_name DeliveryListView
extends Node3D
## The left column: one ClipCardView per delivery, stacked vertically and pinned into a screen region
## by GameRoot. Scroll offsets the stack; cards outside the region are hidden. Pure rendering.

const VISIBLE_ROWS := 6      # how many rows fit in the left region at once

var _views: Array[ClipCardView] = []
var _deliveries: Array[Delivery] = []
var _scroll: int = 0         # index of the first visible row


## Rebuilds one card per delivery (call once after setup).
func build(deliveries: Array[Delivery]) -> void:
	for v in _views:
		v.queue_free()
	_views.clear()
	_deliveries = deliveries
	for delivery in deliveries:
		var view := ClipCardView.new()
		add_child(view)
		view.bind_delivery(delivery)
		_views.append(view)


## Re-reads every delivery's status (call on any delivery change).
func refresh_statuses() -> void:
	for i in _views.size():
		_views[i].bind_delivery(_deliveries[i])


## Scrolls the list by [param delta] rows (clamped).
func scroll_by(delta: int) -> void:
	_scroll = clampi(_scroll + delta, 0, maxi(0, _views.size() - VISIBLE_ROWS))


## Lays the cards out around [param origin] (world), each row [param row_step] down (world units),
## scaled by [param card_scale]. Rows outside the visible window are hidden.
func layout(origin: Vector3, row_step: float, card_scale: float) -> void:
	for i in _views.size():
		var slot := i - _scroll
		var visible := slot >= 0 and slot < VISIBLE_ROWS
		_views[i].visible = visible
		if visible:
			_views[i].position = origin + Vector3(0.0, 0.0, slot * row_step)
			_views[i].scale = Vector3.ONE * card_scale
