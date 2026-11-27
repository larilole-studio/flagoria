class_name BombShot
extends RefCounted
## Geometry shared by host resolution and the pot drawn on each peer.

const VERTICAL_SCALE := 0.6
const FLIGHT_SPEED := 400.0
const ARC_HEIGHT := 28.0


static func landing(origin: Vector2, direction: Vector2, reach: float) -> Vector2:
	return origin + direction.normalized() * reach


static func travel_seconds(distance: float) -> float:
	return clampf(distance / FLIGHT_SPEED, 0.25, 0.65)


static func arc_point(origin: Vector2, end: Vector2, progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	return origin.lerp(end, t) + Vector2.UP * (4.0 * ARC_HEIGHT * t * (1.0 - t))


static func radii(radius: float) -> Vector2:
	return Vector2(radius, radius * VERTICAL_SCALE)


static func contains(center: Vector2, radius: float, point: Vector2) -> bool:
	return ((point - center) / radii(radius)).length_squared() <= 1.0
