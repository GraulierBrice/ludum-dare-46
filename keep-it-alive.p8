pico-8 cartridge // http://www.pico-8.com
version 21
__lua__
-- configs and global data
function debug()
	color(0)
	rectfill(cam.x,cam.y,cam.x+60,cam.y+30)
	color(7)
	print("memory "..stat(0),cam.x,cam.y)
	print("cpu tot "..stat(1),cam.x,cam.y+10)
	print("cpu sys "..stat(2),cam.x,cam.y+20)
end

function _reset_globals()
	game={
		play=false,
		menu_id=1,
		gyro=0,
		menu_select=1,
		map_id=1
	}

	phy={
        dt=1/30,
        friction=1.5,
        bounce=0.5,
        grip=0.33,
        accel=100,
        max_vel_action=20
	}

	maps={
		{
			spawns={
				{{pos=vec_add(vec_mul(vector(12,7), vector(8,8)), vector(4,4)), rot=-0.25}},
				{{pos=vec_add(vec_mul(vector(12,6), vector(8,8)), vector(4,4)), rot=0},
				{pos=vec_add(vec_mul(vector(12,8), vector(8,8)), vector(4,4)), rot=0.5}}},
			corners={upper_left=vector(6,0), bottom_right=vector(39,21)}
			
		},
	}

	cam=vector(0,0)
end

-->8
-- main program
function _init()
	_reset_globals()
	local change1 = change_menu(1)
	for i in all(menus[2].opts) do
		add(menus[2].run,change1)
	end
end

function _update()
	if game.play then
		game_update()
	else
		menu_update()
	end
end

function _draw()
	cls()
	gyro_colours()
	if game.play then
		game_draw()
	else
		menu_draw()
	end
	--debug()
end
function gyro_colours()
	game.gyro=game.gyro%50+1
	if game.gyro > 25 then
		pal(2,12)
		pal(1,1)
	else
		pal(2,1)
		pal(1,12)
	end
end

-->8
-- game program
cars={}
patients={}
dropzones={}
gum={}
function game_start(nb_players, map, mode)
	game.play=true
	cars={}
	gum={}
	n_gums=0
	physics_start()
	for i=1, nb_players do
		local spawn = maps[map].spawns[nb_players][i]
		add(cars, rigidbody(spawn.pos.x, spawn.pos.y, spawn.rot, 7, 7, car_hit))
		cars[i].score = 0
	end
	if (mode==2) cars[2].score=nil
	default_patient(24*8,84,12)
	default_patient(25*8,84,10)
	default_patient(26*8,84,14)
	default_patient(27*8,84,8)
	default_patient(28*8,84,11)
	default_patient(29*8,84,1)
	default_patient(30*8,84,4)
	--default_patient(27*8,84)


	--add(patients, collider(21*8,10,0,8,8,true))
	add(dropzones, collider(12*8+4,7*8+4,0,8,24,true, dropzone_hit))
end

function game_update()
	if (btnp(4)) then
		_init()
		return
	end
	for i=1, #cars do
		update_car(cars[i], i-1)
	end
	for patient in all(patients) do
		update_patient(patient)
	end
	physics_update()
end

function game_draw()
	if (#cars == 1) then
		draw_screen(1, vector(-64, -64), vector(0,0))
	elseif (#cars == 2) then
		draw_screen(1, vector(-64, -32), vector(0,0))
		memcpy(0x1000, 0x6000, 0xfff)
		draw_screen(2, vector(-64, -96), vector(0,0))
		memcpy(0x6000, 0x1000, 0xfff)
		
		local left = vec_add(cam, vector(0, 64))
		local right = vec_add(cam, vector(128, 64))
		line(left.x, left.y, right.x, right.y, 0)
	end
end

function add_gum(p)
	local q=vector(flr(p.x), flr(p.y))
	if (#gum>=1000) then
		gum[n_gums]=q
	else
		add(gum, q)
	end
	n_gums=(n_gums+1)%1000
end

function draw_gum()
	for i=1,#gum do
		pset(gum[i].x, gum[i].y, 0)
	end
end

-- patients section

function default_patient(x, y, col)
	return  (col == 10) and patient(x,y,10,0,2,0,0,100,10)
	or ((col == 14) and patient(x,y,10,0,0,0.75,0,100,14)
	or ((col == 11) and patient(x,y,10,0,2,0.75,0,100,11)
	or ((col == 8) and patient(x,y,10,0,0,0.75,2,40,8)
	or ((col == 1) and patient(x,y,10,0,2,0,2,40,1)
	or ((col == 4) and patient(x,y,10,0,2,0.75,2,40,4)
	or patient(x,y,10,0,0,0,2,30,12))))))
end

function patient(x, y, hp, dmg_unloaded, dmg_drift, dmg_loaded, hit_dmg, hit_dmg_threshold,col)
	local p = collider(x,y,0,8,8,true, patient_hit)
	p.max_hp = hp
	p.hp = hp
	p.car_id = 0
	p.dmg_unloaded = dmg_unloaded
	p.dmg_drift = dmg_drift
	p.dmg_loaded = dmg_loaded
	p.hit_dmg = hit_dmg
	p.hit_dmg_threshold = hit_dmg_threshold
	p.col = col
	add(patients, p)
	return p
end

function patient_hit(patient, other, rel_vel)
	if (patient.car_id <= 0) then
		if (has(cars, other)) then
			if (not other.load and vec_len(rel_vel) < phy.max_vel_action) then
				other.load = patient
				patient.car_id = 1
			end
		end
	end
end

function update_patient(patient)
	if (patient.car_id > 0) then
		if (car_drifting(cars[patient.car_id])) then
			patient.hp -= phy.dt * patient.dmg_drift
		else
			patient.hp -= phy.dt * patient.dmg_loaded
		end
	end
end

function dropzone_hit(dropzone, other, rel_vel)
	if (has(cars, other)) then
		if (other.load and vec_len(rel_vel) < phy.max_vel_action) then
			del(patients, other.load)
			dropzone.col = other.load.col
			other.load = nil
			dropzone.patient = 0
			if (other.score) other.score+=1 else cars[1].score+=1
		end
	end
end

-- car section
function car_drifting(car)
	local loc_vel = tr_vector(car, car.vel)
	local d_rot = abs(atan2(loc_vel.x, loc_vel.y)-0.25)
	local speed = vec_len(car.vel)
	return speed > 0.5 and (d_rot%0.5) > 0.15
end

function car_hit(car, other, rel_vel)
	if (not other.trg and car.load != nil) then
		local speed = vec_len(rel_vel)
		if (speed >= car.load.hit_dmg_threshold) then
			car.load.hp -= car.load.hit_dmg
		end
	end
end

function update_car(car, player)
	local input = vector(0,0)
	if (btn(0, player)) input.x-=1
	if (btn(1, player)) input.x+=1
	if (btn(2, player)) input.y-=1
	if (btn(3, player)) input.y+=1
		
	local acc = input.y * phy.accel
	local mom = input.x * phy.grip * vec_len(car.vel) * phy.dt
	car.acc = vec_add(car.acc, inv_tr_vector(car, vector(0, acc)))
	car.mom = mom

	if (car_drifting(car)) then
		add_gum(car.pos)
	end
	
	if car.load then
		del(colliders, car.load)
	end

	if car.load and car.load.hp <= 0 then
		del(patients,car.load)
		car.load = nil
	end
end

function draw_car(car)
 	for x=-3, 4 do
	 	for y=-3, 4 do
			local col=sget(x+3, y+3)
			if col>0 then 
	  			local dst = vec_add(car.pos, inv_tr_vector(car, vector(x,y)))
 	  			pset(dst.x, dst.y, col)
		 	end
  		end
 	end
	if car.load then
		line(car.pos.x-car.load.hp/2,car.pos.y+10,car.pos.x+car.load.hp/2,car.pos.y+10,8)
	end
end

function draw_screen(player, cam_offset, ui_offset)
	cam = vec_add(cars[player].pos, cam_offset)
	camera(cam.x, cam.y)
	rectfill(cam.x, cam.y, cam.x+128, cam.y+128, 0)

	local orig = vec_mul(cam, vector(1/8,1/8))
	local dest = vector(flr(cam.x/8)*8, flr(cam.y/8)*8)

	map(orig.x, orig.y, dest.x, dest.y, 17, 17)

	draw_gum()


	for dropzone in all(dropzones) do
		if(dropzone.patient) then 
			line(dropzone.pos.x+4,dropzone.pos.y+dropzone.patient/2,dropzone.pos.x+4,dropzone.pos.y-dropzone.patient/2,7)
			pal(12,dropzone.col)
			sspr(24,0,9-dropzone.patient,8,dropzone.pos.x-4+dropzone.patient,dropzone.pos.y-4)
			pal(12,12)
			dropzone.patient+=0.5
			if (dropzone.patient>8) dropzone.patient=nil
		end
	end


	for i=1,#cars do
		for patient in all(patients) do
			if (patient.car_id <= 0) then
				local car_dists = {}
				local bound_x = min(cam.x+126,max(cam.x-1,patient.pos.x))
				local bound_y = {min(cam.y+128/#cars-2,max(cam.y-1,patient.pos.y)),min(cam.y+126,max(cam.y-1+65,patient.pos.y))}
				car_dist=vector(abs(cars[i].pos.x-1-patient.pos.x),abs(cars[i].pos.y-1-patient.pos.y))
				if car_dist.x<=68 and car_dist.y <=68/#cars then
					pal(12,patient.col)
					spr(1,patient.pos.x-4, patient.pos.y-4)
					pal(12,12)
				else
					if car_dist.x>#cars*car_dist.y then
						sspr(13,16,3,3,bound_x,bound_y[i],3,3)
					else
						sspr(13,21,3,3,bound_x,bound_y[i],3,3)
					end
				end
			
			else
				print(patient.car_id, cam.x, cam.y, 11)
				print(patient.hp.."/"..patient.max_hp, cam.x, cam.y+10, 8)
			end
		end
		draw_car(cars[i])
		if(cars[i].score) print("sCORE:"..cars[i].score, cam.x,cam.y+65*(i-1),9)
	end
end

-->8
-- menu program
function change_menu(n)
	return function() game.menu_select=1 game.menu_id=n end 
end

menus = {
	{
		opts={"one-player","two-player coop","two-play versus","credits"},
		run={
			function() game_start(1, 1) end,
			function() game_start(2, 1, 2) end,
			function() game_start(2, 1) end,
			change_menu(2)},
		--run={function() game.play=true end,nil,nil,},
		l=72,
		w=45
	},
	{ 	
		opts={"game designers  ","uLQUIRO","bRICE","programmers     ","uLQUIRO","bRICE","sound designer  ","pUDDY"},
		run={},
		l=72,
		w=85
	},
	display = function(menu)
		draw_menu_box(cam.x+64-menu.l/2,cam.y+64-menu.w/2,menu.l,menu.w,menu.opts) end
	}

function menu_update()
	if (btnp(2)) game.menu_select = max(game.menu_select-1,1)
	if (btnp(3)) game.menu_select = min(game.menu_select+1,#menus[game.menu_id].opts)
	if (btnp(4) or btnp(5)) then if (menus[game.menu_id].run[game.menu_select]) then menus[game.menu_id].run[game.menu_select]() end end
end

function menu_draw()
	camera(cam.x,cam.y)
	map(0,0,0,0,128,128)
	menus.display(menus[game.menu_id])
	spr(108,cam.x+96,cam.y+96,4,2)
	spr(108,cam.x+96,cam.y+112,4,2,true,true)
end

function draw_menu_box(x,y,l,w, opts)
	local off_set = 1
	spr(20,x+l/2-8,y-7)
	spr(21,x+l/2,y-7)
	rectfill(x,y,x+l,y+w,5)
	line(x,y+w,x+l,y+w,0)
	line(x+l,y,x+l,y+w,0)
	line(x,y,x+l,y,7)
	line(x,y,x,y+w,7)
	foreach(opts, function(s) selection(off_set) print(s,x+l/2-#s*2,y+off_set*10-5) off_set+=1 end)
end

function selection(n)
	if game.menu_select==n then color(7) else color(6) end
end
-->8
-- physics
colliders={}
rigidbodies={}

function physics_start()
	colliders={}
	rigidbodies={}
end

function physics_update()
	for i=1, #rigidbodies do
		rb_update(rigidbodies[i])
	end
end

function rigidbody(x, y, r, w, h, on_hit)
	local rb = collider(x, y, r, w, h, false, on_hit)
	rb.acc = vector(0, 0)
	rb.vel = vector(0, 0)
	rb.mom = 0
	rb.tor = 0
	add(rigidbodies, rb)
	return rb
end

function rb_col_response(rb, col, data)
	local hit = col_overlap_col(data.new_col, col)
	if (hit) then
		local rel_vel
		if (col.vel) then rel_vel = vec_sub(col.vel, rb.vel)
		else rel_vel = vec_sub(vector(0,0), rb.vel) end
		if (rb.on_hit != nil) then
			rb.on_hit(rb, col, rel_vel)
		end
		if (col.on_hit != nil) then
			col.on_hit(col, rb, rel_vel)
		end
		if (not col.trg) then
			local norm = col_normal(data.new_col, hit)
			local loc_hit = inv_tr_point(data.new_col, hit)
			local loc_hit_norm = inv_tr_vector(data.new_col, norm)
			local loc_hit_tan =  mul_mat_vec(rot_matrix(0.25), loc_hit_norm)
			local dv = vec_dot(data.new_vel, norm) * (1 + phy.bounce)
			local delta_v = vec_mul(vector(-dv,-dv),norm)
			data.new_vel = vec_add(data.new_vel, delta_v)
			
			data.new_pos = vec_add(rb.pos, vec_mul(data.new_vel, vector(phy.dt, phy.dt)))
			data.new_col.pos = data.new_pos
		end
	end
	return data
end

function rb_update(rb)
	local new_acc = vec_sub(rb.acc, vec_mul(rb.vel, vector(phy.friction, phy.friction)))
	
	local new_vel = vec_add(rb.vel, vec_mul(new_acc, vector(phy.dt, phy.dt)))
	local new_pos = vec_add(rb.pos, vec_mul(new_vel, vector(phy.dt, phy.dt)))

	local new_tor = rb.tor - rb.mom * phy.friction
	local new_mom = rb.mom + new_tor * phy.dt
	local new_rot = rb.rot + new_mom * phy.dt

	local new_col = collider(new_pos.x, new_pos.y, new_rot, rb.w, rb.h, false, rb.on_hit, true)
	
	local data = {new_col=new_col, new_vel=new_vel, new_pos=new_pos}
	
	for i=1, #colliders do
		local col = colliders[i]
		if (col != rb) then
			data=rb_col_response(rb, col, data)
		end
	end

	local p = vec_mul(vec_add(data.new_pos, vec_mul(vec_norm(data.new_vel), vector(8,8))), vector(1/8,1/8))
	if (fget(mget(p.x, p.y), 0)) then
		local col = collider(flr(p.x)*8+4, flr(p.y)*8+4, 0, 8, 8, false, nil, true)
		data = rb_col_response(rb, col, data)
	end


	rb.acc = vector(0,0)
	rb.vel = data.new_vel
	rb.pos = data.new_pos
	rb.mom = new_mom
	rb.rot = new_rot % 1
end

function collider(x, y, r, w, h, trg, on_hit, ign)
	local c = transform(x, y, r)
	c.w = w
	c.h = h
	c.trg = trg
	c.on_hit = on_hit
	if (not ign) then
		add(colliders, c)
	end
	return c
end

function col_overlap_point(c, p)
	local q=tr_point(c, p)
	local ul=col_loc_ul_corner(c)
	local br=col_loc_br_corner(c)

	return ul.x <= q.x and q.x <= br.x and br.y <= q.y and q.y <= ul.y
end

function col_overlap_col(c1, c2)
	local pts={}
	if (col_overlap_point(c1, col_ur_corner(c2))) add(pts, col_ur_corner(c2))
	if (col_overlap_point(c1, col_ul_corner(c2))) add(pts, col_ul_corner(c2))
	if (col_overlap_point(c1, col_br_corner(c2))) add(pts, col_br_corner(c2))
	if (col_overlap_point(c1, col_bl_corner(c2))) add(pts, col_bl_corner(c2))
	if (col_overlap_point(c2, col_ur_corner(c1))) add(pts, col_ur_corner(c1))
	if (col_overlap_point(c2, col_ul_corner(c1))) add(pts, col_ul_corner(c1))
	if (col_overlap_point(c2, col_br_corner(c1))) add(pts, col_br_corner(c1))
	if (col_overlap_point(c2, col_bl_corner(c1))) add(pts, col_bl_corner(c1))
	if (#pts > 0) then
		local contact = vector(0,0)
		for i=1,#pts do
			contact = vec_add(contact, pts[i])
		end
		contact = vec_mul(contact, vector(1/#pts, 1/#pts))
		return contact
	end
	return false
end

function col_normal(c, p)
	local q=tr_point(c, p)
	local n
	local angle = atan2(q.x, q.y)
		if (angle<0.125)  then n = col_left(c)
	elseif (angle==0.125) then n = vec_add(col_left(c), col_up(c))
	elseif (angle<0.375)  then n = col_up(c)
	elseif (angle==0.375) then n = vec_add(col_right(c), col_up(c))
	elseif (angle<0.625)  then n = col_right(c)
	elseif (angle==0.625) then n = vec_add(col_right(c), col_down(c))
	elseif (angle<0.875)  then n = col_down(c)
	elseif (angle==0.875) then n = vec_add(col_left(c), col_down(c))
	else                       n = col_left(c)
	end
	return vec_norm(n)
end

function col_draw(c)
	local ul=col_ul_corner(c)
	local br=col_br_corner(c)
	local bl=col_bl_corner(c)
	local ur=col_ur_corner(c)

	line(ur.x, ur.y, br.x, br.y)
	line(ur.x, ur.y, ul.x, ul.y)
	line(br.x, br.y, bl.x, bl.y)
	line(ul.x, ul.y, bl.x, bl.y)
end

function col_up(c)
	return inv_tr_vector(c, col_loc_up(c))
end

function col_down(c)
	return inv_tr_vector(c, col_loc_down(c))
end

function col_left(c)
	return inv_tr_vector(c, col_loc_left(c))
end

function col_right(c)
	return inv_tr_vector(c, col_loc_right(c))
end

function col_ul_corner(c)
	return vec_add(c.pos, vec_add(col_up(c), col_left(c)))
end

function col_ur_corner(c)
	return vec_add(c.pos, vec_add(col_up(c), col_right(c)))
end

function col_bl_corner(c)
	return vec_add(c.pos, vec_add(col_down(c), col_left(c)))
end

function col_br_corner(c)
	return vec_add(c.pos, vec_add(col_down(c), col_right(c)))
end

function col_loc_up(c)
	return vector(0,c.h*0.5)
end

function col_loc_down(c)
	return vector(0,-c.h*0.5)
end

function col_loc_left(c)
	return vector(-c.w*0.5,0)
end

function col_loc_right(c)
	return vector(c.w*0.5,0)
end

function col_loc_ul_corner(c)
	return vec_add(col_loc_up(c), col_loc_left(c))
end

function col_loc_ur_corner(c)
	return vec_add(col_loc_up(c), col_loc_right(c))
end

function col_loc_bl_corner(c)
	return vec_add(col_loc_down(c), col_loc_left(c))
end

function col_loc_br_corner(c)
	return vec_add(col_loc_down(c), col_loc_right(c))
end

-->8
-- maths
function vector(x, y)
	return {x=x, y=y}
end

function vec_add(u, v)
	return vector(u.x+v.x, u.y+v.y)
end

function vec_sub(u, v)
	return vector(u.x-v.x, u.y-v.y)
end

function vec_mul(u, v)
	return vector(u.x*v.x, u.y*v.y)
end

function vec_dot(u, v)
	return u.x*v.x + u.y*v.y
end

function vec_len(v)
	return sqrt(vec_dot(v, v))
end

function vec_norm(v)
	if (v != vector(0,0)) then
		local d = 1/vec_len(v)
		return vec_mul(v, vector(d, d))
	else
		return v
	end
end

function matrix(c00, c01, c10, c11)
	return {c00, c01, c10, c11}
end

function mtx_inv(m)
	local d=m[1]*m[4]-m[2]*m[3]
	if (d!=0) then
		return matrix(d*m[4], -d*m[2], -d*m[3], d*m[1])
	else
		return m
	end
end

function rot_matrix(a)
	local c=cos(a)
	local s=sin(a)
	return matrix(c, -s, s, c)
end

function mul_mat_vec(m, v)
	return vector(m[1]*v.x + m[2]*v.y, m[3]*v.x + m[4]*v.y)
end

function transform(x, y, rot)
	return {pos=vector(x, y), rot=rot}
end

function tr_vector(t, v)
	return mul_mat_vec(rot_matrix(t.rot), v)
end

function tr_point(t, p)
	return tr_vector(t, vec_sub(p, t.pos))
end

function inv_tr_vector(t, v)
	return mul_mat_vec(mtx_inv(rot_matrix(t.rot)), v)
end

function inv_tr_point(t, p)
	return vec_add(t.pos, inv_tr_vector(t, vec_sub(p, t.pos)))
end

function tr_up(t)
	return tr_vector(t, vector(0,1))
end

function tr_down(t)
	return tr_vector(t, vector(0,-1))
end

function tr_right(t)
	return tr_vector(t, vector(1,0))
end

function tr_left(t)
	return tr_vector(t, vector(-1,0))
end

-->8
-- general  utils
function has(table, object)
	for val in all(table) do
		if (val==object) return true
	end
	return false
end

__gfx__
00a77a00000f00ff000000700000ff000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700000cccff000070770007ff70fcf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
076666700000ccc00007b700666fccf60c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077887704004ccc0007bbb70444cccfff0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07255170444440cf07bbb700444cccff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07888870000400000bbb7000f66fcc66000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077887700004000007b700007ff70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777000044000700000000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888677777777777777755aa55aa007777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000
888888886777b777777777775aa55aa5072222555511117000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888677bb77777777777aa55aa55722222555511111700000000000000000000000000000000000000000000000000000000000000000000000000000000
8888888867bbbbbb77777777a55aa55a722222555511111700000000000000000000000000000000000000000000000000000000000000000000000000000000
8888888867bbbbbb7777777755aa55aa722222555511111700000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888677bb777777777775aa55aa5722225555551111700000000000000000000000000000000000000000000000000000000000000000000000000000000
888888886777b77777777777aa55aa55722225555551111700000000000000000000000000000000000000000000000000000000000000000000000000000000
888888886777777777777777a55aa55a755555555555555700000000000000000000000000000000000000000000000000000000000000000000000000000000
666b666600000c0c58888885bbbbbbbb55ddddd50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
666b366600000ccc58878885bbbbbbb35ddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
666b3666a88a0c0c58878885bb3bbb3b0ddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66bbb3668668000058878885b3bbbbbb0ddd0ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66bbb3668888000058878885bbbbbbbb0ddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6bbbbb3688880ccc58878885bbbb3bbb0ddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66645666888800c058878885bbb3bbbb00ddddd50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6644456688880ccc58888885bbbbbbbb500000550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555666666655555555555555556666666500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555566666665555555555555566666665500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555556666666555555555555666666655500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555555666666655555555556666666555500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555555566666665555555566666665555500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555555556666666555555666666655555500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555555555666666655556666666555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666555555555555555566666665566666665555555500000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000888888000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000888000000888888000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088800000088888888888000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000888000008889888008888800000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008880000888999998800088880000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088800088889998889988000888000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000888000888899000088898800088800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000888008888000000000088880008800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000880088880000aaaaaa008888000880
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088808888000aaa00000a00888800080
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008800898000aa000aaaa000088800080
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088089800a0a00aa000aaa0008880008
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008888980a0aa0a0000000aa009880008
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008889880a0a00000000a00a009988008
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008889800a0a000000000a0aa00998008
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080899800a0a000000000a00a00998808
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
__gff__
0102020000000000000000000000000001090100000000000000000000000000010104040000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0b0b0b0b0b0b1212121212121212121212121212121212121212121212121212121212121212121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212303531313131313131313131313131313131313131313131313131323012121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212303131343030303030303033313131313131313131313131313131313230121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212303331323020303030303030313134303030333131343030303331313130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212123033313230303030303030313130121212303131301212303033313130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212121230313120121212123030312430121212303131301212123030333130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212121230311312121012123030313130121230303131303012123030303130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212121230311311101010123030313130121230353131323030303030303130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b0b1212121230311312121012121230313130303035313131313230303030303130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b121212121230313120121212121230313132303531343030333132303030303130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b121212121230313130121212121230313131313131302323303131313131313130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0b0b0b0b121212121230313130121212123030313131313131302323303131313131313130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070707121212121230313132303030303035313134303331323030353134303030353130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070707121212121230313131313122313131313130303033313131313430303035313130121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070707121212121230333131313122313131313430303030333131343030303531313430121207070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000121212121212303030303030303030303030121230303131303030353131343012121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000121212121212121212121212121212121212121230303131303035313134301212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000121212121212121212121212121212121212121212303331313131313430121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000121212121212121212121212121212121212121212303033313131343012121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000001212121212121212121212121212121212121212303030303030301212121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000001212121212121212121212121212121212121212123030303030121212121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000001212121212121212121212121212121212121212121212121212121212121212000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
