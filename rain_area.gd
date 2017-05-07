extends Area2D

export( bool ) var Passive = false
export( Color ) var Frame_Modulate = Color( 1, 1, 1, 1 )
export( int ) var Drop_Count = 100
export( float ) var Drop_Angle = 90.0
export( float ) var Min_Drop_Speed = 50.0
export( float ) var Max_Drop_Speed = 50.0
export( bool ) var Use_StartAnim = false
export( int ) var StartAnim_StartFrame = 0
export( int ) var StartAnim_EndFrame = 0
export( float ) var StartAnim_Interval = 0.1
export( bool ) var Use_DropAnim = false
export( int ) var DropAnim_StartFrame = 0
export( int ) var DropAnim_EndFrame = 0
export( float ) var DropAnim_Interval = 0.1
export( bool ) var Use_HitAnim = false
export( int ) var HitAnim_StartFrame = 0
export( int ) var HitAnim_EndFrame = 0
export( float ) var HitAnim_Interval = 0.1
# rain area
export( int ) var Polygon_Point_Count =200


# Member Variables
var rain_direction
var drops = []
#var drops_exclude = []
#var physicsQuery
var shape
var shape_transform
var colpoly
var colpoly_points = []
var colpoly_resetpoints = [] # list of points where the drops start
var colpoly_endpoints = [] # list of points where the drops end
var colpoly_ntriangles
var colpoly_triangles = []
#var offset

# manage frames
var Drop_Texture = null

var Hframes = 1
var Vframes = 1
var framesize = Vector2()
var framerects = []
var framesequence = []
var nframe_start = 0
var nframe_drop = 0
var nframe_hit = 0




# Inner classes
class Drop:
	var pos = Vector2()
	var oldpos = Vector2()
	var speed = 1.0
	var area = RID()
	var state = 0
	var frame = 0
	var timer = 0.0
	var endpos = Vector2()
	func _on_collide( a, b, c, d, e ):
		if a == Physics2DServer.AREA_BODY_REMOVED:
			return
		state = 2
		timer = 0.0






var test_points = []
func _ready():
	randomize()
	# search for a colision polygon child
	var colpol = null
	var dropobj = null
	for child in get_children():
		if child.get_type() == "CollisionPolygon2D":
			colpol = child
		if child.get_type() == "Sprite" and child.has_method( "is_rain_drop" ):
			dropobj = child
	if not colpol:
		print( get_name(), ": could not find a child CollisionPolygon2D" )
		return
	if not dropobj:
		print( get_name(), ": could not find a child rain drop" )
		return
	
	# isolate colision polygon
	colpoly = colpol.get_polygon()
	
	# the rain direction
	rain_direction = Vector2( cos( Drop_Angle * PI / 180 ), sin( Drop_Angle * PI / 180 ) )
	rain_direction = rain_direction.normalized()
	
	# take only points in the polygon where the rain starts
	colpoly_points = _get_polygon_points( colpoly, Polygon_Point_Count )
	colpoly_resetpoints = _get_polygon_resetpoints( colpoly_points, rain_direction * Max_Drop_Speed * 0.05, colpoly )
	test_points = [] + colpoly_resetpoints
	
	# compute points where the rain ends
	colpoly_endpoints = _get_polygon_endpoints( colpoly_resetpoints, rain_direction * Max_Drop_Speed * 0.05, colpoly )
	
	#print( "resetpoints: ", colpoly_resetpoints.size() )
	#print( "starting_points: ", starting_points.size() )
	#print( "endpoints: ", colpoly_endpoints.size() )
	
	var aux = Geometry.triangulate_polygon( colpoly )
	colpoly_ntriangles = aux.size() / 3
	for i in range( colpoly_ntriangles ):
		var t = [ colpoly[ aux[ i * 3 ] ], colpoly[ aux[ i * 3 + 1 ] ], colpoly[ aux[ i * 3 + 2 ] ] ]
		colpoly_triangles.append( t )
	
	# the texture
	Drop_Texture = dropobj.get_texture()
	if not Drop_Texture: return
	var texsize = Drop_Texture.get_size()
	Hframes = dropobj.get_hframes()
	Vframes = dropobj.get_vframes()
	framesize = Vector2( texsize.x / Hframes, texsize.y / Vframes )
	for y in range( Vframes ):
		for x in range( Hframes ):
			framerects.append( Rect2( Vector2( x * framesize.x, y * framesize.y ), framesize ) )
	
	# the frames
	if Use_StartAnim:
		framesequence += range( StartAnim_StartFrame, StartAnim_EndFrame + 1 )
		nframe_start = StartAnim_EndFrame + 1 - StartAnim_StartFrame
	else:
		nframe_start = 0
	if Use_DropAnim:
		framesequence += range( DropAnim_StartFrame, DropAnim_EndFrame + 1 )
		nframe_drop = DropAnim_EndFrame + 1 - DropAnim_StartFrame
	else:
		framesequence.append( DropAnim_StartFrame )
		nframe_drop = 1
	if Use_HitAnim:
		framesequence += range( HitAnim_StartFrame, HitAnim_EndFrame + 1 )
		nframe_hit = HitAnim_EndFrame + 1 - HitAnim_StartFrame
	else:
		nframe_hit = 0
	print( "Frame sequence: ", framesequence )
	print( "Frame counts: ", nframe_start, " ", nframe_drop, " ", nframe_hit )
	
	# get the drop collision shape
	var children = dropobj.get_children()
	# look for the sprite and the collision shape
	for child in children:
		if child.get_type() == "CollisionShape2D":
			shape = child.get_shape()
			shape_transform = child.get_transform()
			break
	if not shape:
		Passive = true
		print( "No drop collision shape - Passive mode" )
	else:
		print( "Drop shape transform: ", shape_transform )
	
	# create a bunch of drops
	#var mat = Matrix32()
	for i in range( Drop_Count ):
		# instance drop
		var d = Drop.new()
		# speed
		d.speed = rand_range( Min_Drop_Speed, Max_Drop_Speed )
		# area
		
		d.area = Physics2DServer.area_create()
		Physics2DServer.area_set_space( d.area, get_world_2d().get_space() )
		if not Passive:
			Physics2DServer.area_add_shape( d.area, shape )
			Physics2DServer.area_set_layer_mask( d.area, get_layer_mask() )
			Physics2DServer.area_set_collision_mask( d.area, get_collision_mask() )
			Physics2DServer.area_set_monitor_callback( d.area, d, "_on_collide" )
		# select a random starting point index
		var idx = randi() % colpoly_resetpoints.size()
		# compute random position along the way to the end point
		var p = colpoly_resetpoints[ idx ] + randf() * ( colpoly_endpoints[ idx ] - colpoly_resetpoints[ idx ] )
		#starting_points.append( p )
		# position
		d.pos = p #starting_points[i] #Vector2( ( randf() * 2 - 1 ) * Hextend, ( randf() * 2 - 1 ) * Vextend )
		d.endpos = colpoly_endpoints[ idx ]
		#d.endpos = colpoly_endpoints[i]
		shapepos( d )#, shape_transform )#mat )
		drops.append( d )
	
	
	# start the process
	set_process( true )







func shapepos( d ):
	var mat = Matrix32( shape_transform )
	mat.o += d.pos + get_pos()
	Physics2DServer.area_set_transform( d.area, mat )









func _process( delta ):
	var newpos
	for d in drops:
		if d.state == 0:
			if Use_StartAnim:
				# play start animation by shifting frames
				d.timer += delta
				if d.timer >= StartAnim_Interval:
					d.timer -= StartAnim_Interval
					d.frame += 1
					if d.frame == nframe_start:
						d.state = 1
			else:
				d.frame = nframe_start
				d.state = 1
		if d.state == 1:
			# play drop animation by shifting frames
			d.timer += delta
			if d.timer >= DropAnim_Interval:
				d.timer -= DropAnim_Interval
				d.frame += 1
				if d.frame >= nframe_start + nframe_drop:
					# cycle?
					d.frame = nframe_start
			# update old position
			d.oldpos = d.pos
			# compute new position
			d.pos += delta * d.speed * rain_direction
			# check if within the polygon
			#if not _is_point_inside_polygon( d.pos, colpoly, colpoly_triangles ):
			#	d.pos = colpoly_resetpoints[ randi() % colpoly_resetpoints.size() ]
			# check if reaching the end point
			if ( sign( rain_direction.x ) > 0 and d.pos.x > d.endpos.x ) or \
				( sign( rain_direction.x ) < 0 and d.pos.x < d.endpos.x ) or \
				( sign( rain_direction.y ) > 0 and d.pos.y > d.endpos.y ) or \
				( sign( rain_direction.y ) < 0 and d.pos.y < d.endpos.y ):
				var idx = randi() % colpoly_resetpoints.size()
				d.pos = colpoly_resetpoints[ idx ]
				d.endpos = colpoly_endpoints[ idx ]
			shapepos( d )
		elif d.state == 2:
			# play coliding animation by shifting frames
			d.timer += delta
			if d.timer >= HitAnim_Interval:
				d.timer -= HitAnim_Interval
				d.frame += 1
				if d.frame >= nframe_start + nframe_drop + nframe_hit:
					# reset drop
					d.state = 0
					d.frame = 0
					# select a random starting point
					var idx = randi() % colpoly_resetpoints.size()
					d.pos = colpoly_resetpoints[ idx ]
					d.endpos = colpoly_endpoints[ idx ]
					shapepos( d )
				else:
					pass
	update()




# Get the current camera
onready var camera = get_node( "../TileMap/player/Camera2D" )
onready var st = get_viewport_rect().size
func _draw():
	var vt = camera.get_viewport_transform()
	for d in drops:
		# check if this drop is to be drawn
		if d.pos.x < ( -vt.o.x ) or d.pos.x > ( -vt.o.x + st.width ) or \
			d.pos.y < ( -vt.o.y ) or d.pos.y > ( -vt.o.y + st.height ):
			continue
		# draw drop
		draw_texture_rect_region( Drop_Texture, \
				Rect2( d.pos, framesize ), framerects[ framesequence[ d.frame ] ], Frame_Modulate )
	#for p in colpoly_resetpoints:
	#	draw_circle( p, 2, Color( 1, 1, 0, 1 ) )
	#for p in colpoly_endpoints:
	#	draw_circle( p, 2, Color( 1, 0, 0, 1 ) )








func _get_random_point_within_polygon_old( poly, N = 1 ):
	var MaxTrials = 10 * N
	# generate a set of random points within a collision polygon.
	#var poly = get_node("CollisionPolygon2D").get_polygon()
	# stupid method that generates a random point within an enclosing rectangle
	# and checks if it is within the polygon
	var enclosing_rect = _get_enclosing_rectangle( poly )
	#print( enclosing_rect )
	var rect_dim = enclosing_rect[1] - enclosing_rect[0]
	var trial = 0
	var pout = []
	for trial in range( MaxTrials ):
		var p = Vector2( randf() * rect_dim.x, randf() * rect_dim.y ) + enclosing_rect[0]
		if _is_point_inside_polygon( p, poly, colpoly_triangles ):
			pout.append( p )
			if pout.size() == N:
				break
	return pout


func _get_enclosing_rectangle( poly ):
	var pout = [ Vector2( 10000.0, 10000.0 ), Vector2( -10000.0, -10000.0 ) ]
	for p in poly:
		pout[0].x = min( pout[0].x, p.x )
		pout[0].y = min( pout[0].y, p.y )
		pout[1].x = max( pout[1].x, p.x )
		pout[1].y = max( pout[1].y, p.y )
	return pout


func _get_polygon_points( poly, N ):
	var points = []
	var c = Curve2D.new()
	for p in poly:
		c.add_point( p )
	c.add_point( poly[0] )
	for i in range( N ):
		points.append( c.interpolate_baked( i * c.get_baked_length() / N ) )
	return points

# check points that after one step are outside the polygon
func _get_polygon_resetpoints( points, rdir, poly ):
	var rpoints = []
	for p in points:
		if _is_point_inside_polygon( p + rdir, poly, colpoly_triangles ):
			rpoints.append( p )
	var r = _get_enclosing_rectangle( rpoints )
	var maxh = r[1] - r[0]
	maxh = maxh.length()
	var rpoints2 = []
	var rdirn = rdir.normalized()
	for p in rpoints:
		var is_shadow = false
		for i in range( 1, 200 ):
			var d = i / 200.0 * maxh
			if _is_point_inside_polygon( p - rdirn * d, poly, colpoly_triangles ):
				is_shadow = true
				break
		if not is_shadow:
			rpoints2.append( p )
	return rpoints2


func _is_point_inside_polygon_full( p, poly ):
	# adapted from http://www.ariel.com.au/a/python-point-int-poly.html
	var n = poly.size()
	var inside = false
	var p1 = poly[0]
	var p2 = Vector2()
	var xinters = 0.0
	for i in range( n + 1 ):
		var p2 = poly[ i % n ]
		if p.y > min( p1.y, p2.y ):
			if p.y <= max( p1.y, p2.y ):
				if p.x <= max( p1.x, p2.x ):
					if p1.y != p2.y:
						xinters = ( p.y - p1.y ) * ( p2.x - p1.x ) / ( p2.y - p1.y ) + p1.x
					if p1.x == p2.x or p.x <= xinters:
						inside = not inside
		p1 = p2
	return inside


func _is_point_inside_polygon( p, poly, triangles ):
	var inside = false
	for i in range( triangles.size() ):
		if Geometry.point_is_inside_triangle( p, triangles[i][0], triangles[i][1], triangles[i][2] ):
			inside = true
			break
	# to handle the edges of the triangles
	if not inside:
		inside = _is_point_inside_polygon_full( p, poly )
	return inside


func _get_polygon_endpoints( spoints, direction, poly ):
	var endpoints = []
	# run each drop from the starting points to the end of the polygon
	for p in spoints:
		# test point
		var x = p + Vector2()
		var finished = false
		#print( "testing ", x )
		while not finished:
			x += direction
			if not _is_point_inside_polygon_full( x, poly ):
				endpoints.append( x )
				#print( "found endpoint ", x )
				finished = true
	return endpoints
	