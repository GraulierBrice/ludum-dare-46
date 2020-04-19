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
		menu_select=1,
		map_id=1
	}

	phy={
        dt=1/30,
        friction=1.5,
        bounce=0.5,
        grip=0.33,
        accel=150,
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
		{
			spawns={
				{{pos=vec_add(vec_mul(vector(93,16), vector(8,8)), vector(4,4)), rot=0.5}},
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
	if game.play then
		game_draw()
	else
		menu_draw()
	end
	--debug()
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
	game.map_id=map
	physics_start()
	for i=1, nb_players do
		local spawn = maps[map].spawns[nb_players][i]
		add(cars, rigidbody(spawn.pos.x, spawn.pos.y, spawn.rot, 7, 7, car_hit))
		cars[i].score = 0
	end
	if (mode==2) cars[2].score=nil
	default_patient(109*8,14*8,12)
	default_patient(110*8,14*8,10)
	default_patient(111*8,14*8,14)
	default_patient(112*8,14*8,8)
	default_patient(113*8,14*8,11)
	default_patient(114*8,14*8,1)
	default_patient(115*8,14*8,4)
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
		
		local left = vec_add(cam, vector(0, 63))
		local right = vec_add(cam, vector(128, 64))
		rectfill(left.x, left.y, right.x, right.y, 0)
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
			if (other.score) other.score+=colour_to_score(other.load.col) else cars[1].score+=colour_to_score(other.load.col)
			dropzone.col = other.load.col
			other.load = nil
			dropzone.patient = 0
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

			if time()%2 > 1 and col==2 or time()%2 <= 1 and col==1 then
				col=12
			end
			if col>0 then 
	  			local dst = vec_add(car.pos, inv_tr_vector(car, vector(x,y)))
 	  			pset(dst.x, dst.y, col)
		 	end
  		end
 	end
	if car.load then
		local l = vec_add(car.pos, vector(-car.load.hp/2,10))
		local r = vec_add(car.pos, vector(car.load.hp/2,10))
		line(l.x, l.y, r.x, r.y, 8)
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
			function() game_start(1, 2, nil) end,
			function() game_start(2, 1, nil) end,
			function() game_start(2, 1, nil) end,
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
	if time()%2 > 1 then
		pal(1,12)
	else
		pal(2,12)
	end
	spr(6,x+l/2-8,y-7)
	spr(7,x+l/2,y-7)
	pal()
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

	if (fget(mget(p.x,p.y), 2)) then
		if (vec_len(data.new_vel)>30) then
			if (rb.rot>0.5) new_rot -= 0.001*vec_len(data.new_vel) else new_rot += 0.001*vec_len(data.new_vel)
			if(rb.load) rb.load.hp -= rb.load.dmg_drift/3
		end
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

function colour_to_score(c)
	return  (c == 10) and 2
	or ((c == 14) and 3
	or ((c == 11) and 5
	or ((c == 8) and 4
	or ((c == 1) and 3
	or ((c == 4) and 6
	or 1)))))
end

__gfx__
00a77a00000f00ff000000700000ff000f00000000000c0c00777777777777005555555556666666655555555555555566666661666666666666666166666666
00777700000cccff000070770007ff70fcf0000000000ccc07222255551111705557555555666666665555555555555666666615666666666666666166666666
076666700000ccc00007b700666fccf60c000000a88a0c0c72222255551111175557555555566666666555555555556666666155666666666666666166666666
077887704004ccc0007bbb70444cccfff0f000008668000072222255551111175555555555556666666655555555566666661555666666666666666166666666
07255170444440cf07bbb700444cccff000000008888000072222255551111175555555555555666666665555555666666615555666666666666666166666666
07888870000400000bbb7000f66fcc660000000088880ccc72222555555111175557555555555566666666555556666666155555666666666666666166666666
077887700004000007b700007ff7000000000000888800c072222555555111175557555555555556666666655566666661555555666666666666666166666666
0777777000044000700000000ff000000000000088880ccc75555555555555575555555555555555666666665666666615555555111111116666666166666666
77788777777777776777777655aa55aa7777777777777777777777777777777755555555555555555555555555777755555555555888888566636666bbb3bbbb
77788777777bb777677677765aa55aa577555577775555777711117777dddd7755555555575555555555557557bbbb75555555555887888566333666bb333bbb
77788777777bb77767677776aa55aa557755557777555577771ddd7777daaa775555555555755555555557557bb3bb37555555555887888563333366b33333bb
88888888777bb77767787776a55aa55a7755557777555577771ddd7777daaa775775577555555555555555557b3bb3b7555555555887888563333366b33333bb
888888887bbbbbb76788877655aa55aa7755557777555577771ddd7777daaa775555555555555555555555557bbbbbb75555555558878885333333363333333b
7778877777bbbb77677876765aa55aa57711117777dddd77771ddd7777daaa775555555555555755557555557bbb3bb755555555588788853333333333333333
77788777777bb77767776776aa55aa55771ddd7777daaa77771ddd7777daaa7755555555555555755755555557b3bb75555555555887888566645666b554555b
777887777777777767777776a55aa55a7777777777777777777777777777777755555555555555555555555555777755555555555888888566444566bb444bbb
66666666677777777777777777777776666666666666666666666666ffffffff666666666666666666666666ccccccd1bb3bbbbbb3bbbbb3b3bbbbbbb3bbbbb3
60000006677777777777777777777776677777777777777777777776ff1111ff666666666666666666666666cccccdcdb3bbbb3bbbbbb3b3bbbbb3bbbbbbb3b3
60000006677777777777777777777776677777777777777777777776ff1dddff666666666666666666666666ccccccccbbbbb3bbbbbb3bb3bbbb3bbbbbbb3bb3
60000116677777777777777777777776677777777777777777777776ff1dddff555555555555555555555555cd1cccccbbbbbbbbbbbbbbb3bbbbbbbbbbbbbbb3
60011dd6677777777777777777777776677777777777777777777776ff1dddff511111511111511115111115dcdcccccbbbbbbbbbbbbbbb3bbbbbbbbbbbbbbb3
611dd666677777777777777777777776677777777777777777777776ff1dddff516666516666516665166665ccccd1ccbbbbb3bbbbbb3bb3bbbb3bbbbbbb3bb3
6dd66776677777777777777777777776677777777777777777777776ff1dddff555555555555555555555555cccdcdccbbbb3bbbbbb3bbb3bbb3bbbbbbb3bbb3
67777776677777777777777777777776677777777777777777777776ffffffff516516516516516565165165ccccccccbbbbbbbbbbbbbbb33333333333333333
ffffffff6effffffffffffffffffffe6ffffffffffffffff6666666886666666666666666666666666666666dddddd10ddddddd0ccccccc1ccccccd166651666
ffffffff6effffffffffffffffffffe6ff5555ffff5555ff6666668ff8666666666666666666666666666666ddddd1d1ddddddddcccccccccccccdcd66651666
ff1111ff6effffffffffffffffffffe6ff5555ffff5555ff666668ffff866666665555555555555555555566dddddddddd55555555555555555555cc66651666
ff1dddff6effffffffffffffffffffe6ff5555ffff5555ff66668ffffff86666651111511115511115111156d10dddddd50ddd5dcd155cccc51ccc5c66651666
ff1dddff6effffffffffffffffffffe6ff5555ffff5555ff6668ffffffff86665166665166655166651666651d1ddddd5d1ddd5ddcd55cccd5dcccc566651666
ff1dd6ff6effffffffffffffffffffe6ff1111ffffddddff668ffffffffff866555555555555555555555555dddd10dd55555555555555555555555566651666
ff1dddff6effffffffffffffffffffe6ff1dddffffdaaaff68ffffffffffff86516516516666666665165165ddd1d1dd5dd5d151cccdcdccc5cd5dc566651666
ff1dddff6effffffffffffffffffffe6ffffffffffffffff8ffffffffffffff8555555555555555555555555dddddddd55555555555555555555555566651666
55555555555555555555555555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
5ffffffffffffffffffffff555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
5ffffffffffffffffffffff555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
5ffffffffffffffffffffff555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
5ffffffffffffffffffffff555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
5ffffffffffffffffffffff555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
5ffffffffffffffffffffff555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
5ffffffffffffffffffffff555555555666666660000000000000000000000000000000051666666666666510000000000000000000000000000000000000000
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
__gff__
0000000000000000000000000000000001010100010101010000000400040101010101010101010101010101040404040101010101010101010101010101010101010101010101010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020000000000000000000000000001090100000000000000000000000000010104000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0f0f0c18181818181818181818181818181c1c1c1c1c0f36370f0f36370f0f36370f0f0f0f0f0f0f0f0f0f0e3b2b2b2b0f0f0f0f0f0f0f0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2d0c1a0b0f0f0f0f0f0f0a19090f0f0f0f0f0a1c1c1c3634323736272737363535370f0f0f0f0f0f0f0f0f0e3b2b2b2b0f0f0f0f0f0f0f0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f1f080b0f0f0f0f0f0f0f0f0a19090f0f0f0f0f0a1c1c3132303331323033313032330f0f0f0f0f0f0f0f0f0e3b2b2b2b0f0f0f0f0f0f0f0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2f080f0f0f0f0f0f0f0f0f0f1c1c181818181818181818181818181818181818181818180f0f0f0f0f0f0f0e3b2b2b2b0f0f0f0f0f1c1c0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0e080f0f0f0f0f0f0f0f1c1c1c0f0f0f0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0f0f0f0f0f0f0f0f0f0e3b2b2b2b0f1c1c1c1c0f0f1c1c1c1c1c1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2d080f0f0f0f0f0f1c1c0f1c0f0f0f0e1f2c2c2c2c2c2c2c2c2c2c2c2c1f2c2c2c2d0f0f0f0f0f0f0f0f0f0e3b2b2b2b0f1c0f0f0f0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e0f1f080f0f0f0f0f1c1c0f0f1c0f0f0f0e2c2c2c1f1f2c2c1f2c2c2c1f2c2c2c1f2c2d0f0f0f0f0f0f0f0f0f0e3b2b2b2b0f1c0f0f0f0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d0d2f080d0d0d0d0f1c0f0f0f1c0f0f0f0e2c1f2c2c1f2c2c2c2c2c1f2c2c1f2c2c2c2d0f0f0f0f0f0f1c0f0f0e3b2b2b2b0f1c0f0f0f0f0f0f0f0f0f0f1c0f
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018181818181818181c1c0f0f0f1c0f1c0f0e2c2c2c1f2c2c1f2c1f1f2c2c2c2c2c2c1f2d0f0f0f0f0f0e080f0f0e3b2b2b2b0e1c0f0f0f0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a0f2d0f0f0f0f0f0f1c0f0f1c1c1c1c0f0e2c1f2c2c1f2c2c2c2c2c2c1f2c2c1f2c1f2d0f0f0f0f0f0e080f0f0e3b2b2b2b0e1c0f0f0f0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f1f0f0f0f0f0f0f1c0f0f0f1c1c1c0f0e2c2c1f2c2c2c2c1f2c2c2c2c1f2c2c2c2c2d0f0f0f0f0f0c1c090f0e3b2b2b2b0e1c1c0f0f0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2f0f0f0f0f0f0f1c0f0f0f1c1c1c0f0e2e2e2e2e2e2e24252525252525252525262f0f0f0f0f0c1c1c1c090e3c3d3d3e0f0e1c0f0f0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0f0f0f0f0f0f1c0f0f0f0f1c1c1c0f0f282a2a2a2a2921162217221022142217232a0f0f0f0c1c1a1c191c090d0d0d0d0d0c1c090f0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2d0f0f0f0f1c1c0f0f0f0f1c1c1c0f0f0f0f0f0f0f0f21222222222222222222230f0f0f0c1a1c1c1b1c191c1c1c1c1c1c1a1c19090d0d0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f1f0f0f0f1c1c0f0f0f0f0f1c1c1c0f0f0f0f0f0d0f0f21152214221122152216230f0f0c1a1c1c191c1c1a1c18181818181c1b1c1818180f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e0f2f0f0f1c1c0f0f0f0f0f0f0f1c1c0f0f0f0f0c18090f21222222222022222222230f0c1a1c0b0a1c191a1c1c1c1c1c1c1c191c1a0b0f0f0f0f0f0f0f1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d0d0d0d0d0f0f0f0f0f0f0f0f0f1c1c090d0d0c1a1c19090d0d0d0c131313090d0d0d0c1a1c0b0f0f0a1c0b0f0f3839393a0a1c1c0b0f0f0f0f0f0f0f0f1c0f
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018181818180f0f0f0f0f0f0f0f0f1c1c1c1818081c1b1c081d1818181818181818181d181c1c0f0f0f0e080f0f0e3b3b3b3b1e0a19090f0f0f0f0f0f0f1c0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818181818180f0f0f0f0f0f0f0f1c1c0f0f0f0a191c1a0b282a0a1c1c1c1c1c0b28292a0e1c0f0f1e0e080f2d0e3b2b2b2b0f0f0a080f0f0f0f0f0f0f1c0f0f
0000000000000024252525252525252525260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018181818180f0f0f0f0f0f0f0f0f0f1c0f0f0f0f0a180b0f0f4a0e181c1c1c180f490f0f0e1c0f0f0f0e080f2f0e3b2b2b2b0f0f0e080f0f0f0f0f0f0f0f0f0f
000000000000002115221522102214221523000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a0f0f0f0f0f0f0f0f0f0f0f0f0f0f1c0f0f0f0f0f0f0f0f0f4a0e181c1c1c180f490f0f0e1c0f0f0f0e080f0f0e3b2b2b2b1e0f0e080f0f0f0f0f0f0f0f0f0f
000000000000002122222222222222222223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2d0f0f0f0f0f0f0f0f0f0f0f0f1c1c0f0f0f0f0f0f0f0f4a0f0a0808080b0f490f0f0e1c0f0f1e0e080f2d0e3b2b2b2b0f0f0e080f0f0f0f0f0f0f0f0f0f
000000000000002115221422112215221423000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f1f0f0f0f0f0f0f0f0f0f0f0f0f0f1c1c0f0f0f0f0f0f0f4a0f0f0f0f0f0f0f490f0f0e1c0f0f0f0e1c0f2f0e3b2b2b2b0f0f0e080f0f0f0f0f0f0f0f0f0f
000000000000002122222222202222222223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1c1c1c0f0f0f0f0f4a0f0f0f0f0f0f0f490f0f0e1c1c0f0f0f1c0f0f0e3b2b2b2b1e0f0e080f0f0f0f0f0f0f0f0f0f
000000000000000d0d0d0c131313090d0d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1c1c0f0f0f0f4a2829292929292a490f0f0e0f1c0f0f0f1c0f0f0e3b2b2b2b0f0f0e19090d0d0d0d0d0d0d0d0d
000000000000001d1818181818181818181d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2d0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1c0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1c0f0f0f1c0f2d0e3b2b2b2b1f2c1f0a19181818181818181818
000000000000002b2b2b2b2b2b2b2b2b2b2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f1f0f0f0f0f0f0f0f0f0f0f0f0f0f1c1c1c1c1c1c1c1c1c0f0f0f0f0f0f0f0f0f0f0f0f0f1c0f0f0f0f0f2f0e3b2b2b2b2c2c2d0e1c181818181818181818
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1c1c1c1c1c1c1c1c1c1c1c1c0f0f1c0f0f0f0f0f0f0e3b2b2b2b1f2e1f0c1a181818181818181818
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1c1c1c1c1c1c1c1c1c2d0e3b2b2b2b0f0f0c1a0b0f0f0f0f0f0f0f4444
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2d0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f2f0e3b2b2b2b1e0c1a0b0f0f0f0f0f0f0f0f4444
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f1f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e3c3d3d3e0c1a0b4444444444444444444444
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f2f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0c18181818180b444444444444444444444444
