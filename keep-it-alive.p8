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
		map_id=1,
		start=0,
		nb_players=1
	}

	phy={
        dt=1/30,
        friction=1.5,
        bounce=0.5,
        grip=0.33,
        accel=150,
        max_vel_action=25,
		bounds={min=vector(0,0), max=vector(128,128)}
	}

	maps={
		{
			spawns={
				{{pos=vec_add(vec_mul(vector(93,21), vector(8,8)), vector(4,4)), rot=0}},
				{{pos=vec_add(vec_mul(vector(92,21), vector(8,8)), vector(4,4)), rot=0},
				{pos=vec_add(vec_mul(vector(94,21), vector(8,8)), vector(4,4)), rot=0}}},
			patients_spawns={
				vec_mul(vector(78,27), vector(8,8)),
				vec_mul(vector(72,6), vector(8,8)),
				vec_mul(vector(90,3), vector(8,8)),
				vec_mul(vector(94,3), vector(8,8)),
				vec_mul(vector(97,3), vector(8,8)),
				vec_mul(vector(122,8), vector(8,8)),
				vec_mul(vector(123,20), vector(8,8))
			},
			delay_between_patients=5,
			patients_spawn_rates={
				{10, 0.2},
				{14, 0.2},
				{11, 0.2},
				{8, 0.125},
				{1, 0.125},
				{4, 0.05},
				{-1, 0.10},
			},
			morphines={
				vec_mul(vector(91,6), vector(8,8)),
				vec_mul(vector(69,20), vector(8,8)),
				vec_mul(vector(117,26), vector(8,8))
			},
			bounds={min=vector(64*8,0), max=vector(128*8,32*8)}
		}
	}

	cam=vector(0,0)
end

-->8
-- main program
function _init()
	_reset_globals()
	music(0)
	local change1 = change_menu(1)
	for i in all(menus[2].opts) do
		add(menus[2].run,change1)
	end
	for i in all(menus[3].opts) do
		add(menus[3].run,change1)
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
death_message_lt=0
cars={}
patients={}
dropzones={}
gum={}
morphines={}
time_to_spawn_patient=0

function game_start(nb_players, map, mode)
	music(0)
	sfx(40)
	game.play=true
	cars={}
	gum={}
	morphines={}
	patients={}
	particles = {}
	game.start=time()+180
	game.mode=mode
	game.score = 0

	n_gums=0
	game.map_id=map
	physics_start()
	for i=1, nb_players do
		local spawn = maps[map].spawns[nb_players][i]
		add(cars, rigidbody(spawn.pos.x, spawn.pos.y, spawn.rot, 7, 7, car_hit))
	end

	for m in all(maps[map].morphines) do
		morphine(m.x, m.y)
	end

	add(dropzones, collider(93*8+4,16*8+4,0,24,24,true, dropzone_hit))
end

function game_end()
	pal()
	menus.crosses={}
	game.play=false
	if (game.mode==1) then
		menus[4].opts[2]="you scored "..game.score
		change_menu(4)()
	elseif (game.mode==2) then
		menus[5].opts[2]="you scored "..game.score
		change_menu(5)()	
	end
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
	for morphine in all(morphines)do
		update_morphine(morphine)
	end
	if (time() > time_to_spawn_patient) then
		spawn_patient()
		time_to_spawn_patient = time() + maps[game.map_id].delay_between_patients
	end
	phy.bounds = maps[game.map_id].bounds

	physics_update()

	if(game.mode == 1) then 
		if (game.start<time()) game_end()
	end

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

function spawn_patient()
	local r = rnd()
	local s = 0
	
	for rate in all(maps[game.map_id].patients_spawn_rates) do
		s+=rate[2]
		if (r < s) then
			local spwn = nil
			for i in all(randomPermutation(#maps[game.map_id].patients_spawns)) do
				local m = maps[game.map_id].patients_spawns[i]
				local free = true
				for col in all(colliders) do
					if (col.pos.x==m.x and col.pos.y==m.y) then
						free = false
						break
					end
				end
				if (free) then
					spwn = m
					break
				end
			end
			if (spwn != nil) then
				default_patient(spwn.x, spwn.y, rate[1])
				break
			end
		end
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
	local unload_dmg = 0.5/30
	return  (col == 10) and patient(x,y,10,unload_dmg,2,0,0,100,10)
	or ((col == 14) and patient(x,y,10,unload_dmg,0,0.75,0,100,14)
	or ((col == 11) and patient(x,y,10,unload_dmg,2,0.75,0,100,11)
	or ((col == 8) and patient(x,y,10,unload_dmg,0,0.75,2,40,8)
	or ((col == 1) and patient(x,y,10,unload_dmg,2,0,2,40,1)
	or ((col == 4) and patient(x,y,10,unload_dmg,2,0.75,2,40,4)
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
			if(patient.dmg_drift>0)blood(cars[patient.car_id].pos,true)
		else
			patient.hp -= phy.dt * patient.dmg_loaded
			if(patient.dmg_loaded>0)blood(cars[patient.car_id].pos,true)
		end
	else
		patient.hp -= patient.dmg_unloaded
		if(patient.hp<0)then
			if (game.mode==1) then
				del(patients,patient)
				del(colliders, patient)
			else game_end() end
		end
	end 
end

function dropzone_hit(dropzone, other, rel_vel)
	if (has(cars, other)) then
		if (other.load and vec_len(rel_vel) < phy.max_vel_action) then
			del(patients, other.load)
			if (game.score) game.score+=colour_to_score(other.load.col) else game.score+=colour_to_score(other.load.col)
			dropzone.col = other.load.col
			other.load = nil
			dropzone.patient = 0
			sfx(41)
		end
	end
end

function morphine(x,y)
	local m = collider(x,y,0,8,8,true, morphine_hit)
	m.full=true
	add(morphines,m)
	return m
end

function morphine_hit(morphine, other, rel_vel)
	if (has(cars, other)) then
		if (other.load and morphine.full) then
			other.load.hp += 10
			morphine.full = false
			morphine.time = time()
			sfx(43)
		end
	end
end

function update_morphine(morphine)
	if not morphine.full then
		if (time() - morphine.time>=10) morphine.full = true
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
			blood(car.pos,true)
			blood(car.pos,true)
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
		if (game.mode==1) then
			death_message_lt = time()+2
			sfx(42)
		else
			game_end()
		end
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
	cam.x=min(112*8,max(cam.x,64*8))
	cam.y=min(16*8-(player-2)*8*8*(#cars-1),max(cam.y,0-8*8*(player-1)))
	camera(cam.x, cam.y)
	rectfill(cam.x, cam.y, cam.x+128, cam.y+128, 0)

	local orig = vec_mul(cam, vector(1/8,1/8))
	local dest = vector(flr(cam.x/8)*8, flr(cam.y/8)*8)

	map(orig.x, orig.y, dest.x, dest.y, 17, 17)

	draw_gum()


	for dropzone in all(dropzones) do
		if(dropzone.patient) then 
			pal(12,dropzone.col)
			sspr(24,dropzone.patient,8,8-dropzone.patient,dropzone.pos.x-4,dropzone.pos.y-4-dropzone.patient)
			pal(12,12)
			dropzone.patient+=0.5
			if (dropzone.patient>8) dropzone.patient=nil
		end
	end

	for morphine in all(morphines) do
		pal(11,0)
		pal(7,0)
		spr(2,morphine.pos.x+1,morphine.pos.y+1)
		pal()
		if (not morphine.full) pal(11,6)
		spr(2,morphine.pos.x,morphine.pos.y-time()%2)
		pal(11,11)
	end

	if(game.mode==1) print("time "..flr(game.start-time()),cam.x+64-#"time"*4,cam.y,9)

	
		for patient in all(patients) do
			if (patient.car_id <= 0) then
				local bound_x = min(cam.x+125,max(cam.x-2,patient.pos.x))
				local bound_y = {min(cam.y+128/#cars-3-(#cars-1) ,max(cam.y-2,patient.pos.y)),min(cam.y+125,max(cam.y+63,patient.pos.y))}
				for i=1,#cars do
					local car_dist=vec_sub(cars[i].pos,patient.pos)
					if (abs(car_dist.x)<=68 and abs(car_dist.y) <=68/#cars) patient.show=true
				end
				pal(12,patient.col)
				if patient.show then
					local l = vec_add(patient.pos, vector(-patient.hp/2,10))
					local r = vec_add(patient.pos, vector(patient.hp/2,10))
					line(l.x, l.y, r.x, r.y, 8)
					spr(1,patient.pos.x-4, patient.pos.y)
					patient.show = true
				elseif patient.hp>4 or time()%0.5==0 then
					for i=1,#cars do
					local car_dist=vec_sub(cars[i].pos,patient.pos)
						if abs(car_dist.x)>#cars*abs(car_dist.y) then
							sspr(40,0,5,5,bound_x,bound_y[i],5,5)
						else
							sspr(43,3,5,5,bound_x,bound_y[i],5,5)
						end
					end
				end
				patient.show=false
				pal(12,12)
			end
		end
	for i=1,#cars do
		draw_particles()
		draw_car(cars[i])
		if(death_message_lt>time()) then
			draw_menu_box(cam.x+32,cam.y+16,72,12,{"patient has died"})
		end
		if(game.score) print("sCORE:"..game.score, cam.x,cam.y+65*(i-1),9)
	end
	for p in all(patients) do
		p.show=false
	end

end

-->8
-- menu program
function change_menu(n)
	return function() game.menu_select=1 game.menu_id=n end 
end

menus = {
	{
		opts={"save them fast", "save them all", "add player 2", "how to play","credits"},
		run={
			function() game_start(game.nb_players, 1, 1) end,
			function() game_start(game.nb_players, 1, 2) end,
			function() 
				if (game.nb_players==1) then game.nb_players=2 menus[1].opts[3]="add player 2"
				else  game.nb_players=1 menus[1].opts[3]="remove player 2" end end,
			change_menu(3),
			change_menu(2)},
		--run={function() game.play=true end,nil,nil,},
		l=82,
		w=55
	},
	{ 	
		opts={" game designers  ","tHEO fAFET","bRICE"," programmers     ","tHEO fAFET","bRICE"," sound designer  "," pUDDY/pRODUCER-SAN"},
		run={},
		l=78,
		w=85
	},
	{
		opts={"save the patients!","be careful of their symptoms:","  broken bones -> avoid walls"," vommiting    -> drive safe","  bleeding out -> quickly go!","get them to the drop zone","use morphine to keep alive","slow down to pick-up/drop-off","player 1 uses arrow keys     ","player 2 uses esdf           "},
		run={},
		l=126,
		w=105
	},	
	{
		opts={"congratulations!", "score placeholder", "try again", "back to menu"},
		run={nil,nil,function()game_start(game.nb_players, game.map_id, game.mode) end, change_menu(1)},
		l=16*4+4,
		w=45
	},	
	{
		opts={" oh no someone has died!", "score placeholder", "try again", "back to menu"},
		run={nil,nil,function()game_start(game.nb_players, game.map_id, game.mode) end, change_menu(1)},
		l=23*4+4,
		w=45
	},

	display = function(menu)
		draw_menu_box(cam.x+64-menu.l/2,cam.y+64-menu.w/2,menu.l,menu.w,menu.opts) end
	}

function menu_update()
	if not menus.crosses then
		menus.crosses={}
		physics_start()
		for i = 1, 8 do
			local rb = rigidbody(cam.x+rnd()*124, cam.y+rnd()*124, 0, 8, 8)
			add(menus.crosses, rb)
			local r = rnd()
			rb.vel = vector(cos(r)*20, sin(r)*20)
		end
	end

	for i=1,#menus.crosses do
		local rb=menus.crosses[i]
		rb.vel = vec_mul(vec_norm(rb.vel), vector(20,20))
	end

	if (btnp(2)) then game.menu_select = max(game.menu_select-1,1) sfx(44) end
	if (btnp(3)) then game.menu_select = min(game.menu_select+1,#menus[game.menu_id].opts) sfx(44) end
	if (btnp(4) or btnp(5)) then if (menus[game.menu_id].run[game.menu_select]) then menus[game.menu_id].run[game.menu_select]() sfx(44) end end

	phy.bounds = {min=cam, max=vec_add(cam, vector(127,127))}

	physics_update()
end

function menu_draw()
	camera(cam.x,cam.y)
	rectfill(cam.x, cam.y, cam.x+128, cam.y+128, 7)
	for i=1,#menus.crosses do
		local rb=menus.crosses[i]
		spr(16, cam.x+rb.pos.x, cam.y+rb.pos.y)
	end
	if (game.menu_id==1) then
		if (game.nb_players==1) then menus[1].opts[3]="add player 2"
		else menus[1].opts[3]="remove player 2" end
	end
	menus.display(menus[game.menu_id])
	spr(108,cam.x+96,cam.y+96,4,2)
	spr(108,cam.x+96,cam.y+112,4,2,true,true)
	if(game.menu_id==3)then
		spr(1,cam.x+3,cam.y+35)
		pal(12,10)
		spr(1,cam.x+3,cam.y+45)
		pal(12,14)
		spr(1,cam.x+3,cam.y+55)
		pal(12,12)
		spr(2,cam.x+3,cam.y+74)
		spr(2,cam.x+117,cam.y+74)
		spr(19,cam.x+4,cam.y+64)
		spr(19,cam.x+116,cam.y+64)
	end
end

function draw_menu_box(x,y,l,w, opts)
	local off_set = 1
	if time()%2 > 1 then
		pal(1,12)
		pal(2,1)
	else
		pal(1,1)
		pal(2,12)
	end
	spr(6,x+l/2-8,y-7)
	spr(7,x+l/2,y-7)
	pal()
	rectfill(x,y,x+l,y+w,5)
	line(x,y+w,x+l,y+w,1)
	line(x+l,y,x+l,y+w,1)
	line(x,y,x+l,y,6)
	line(x,y,x,y+w,6)
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
			if (abs(col.pos.x-rb.pos.x)<16 and abs(col.pos.y-rb.pos.y)<16) then
				data=rb_col_response(rb, col, data)
			end
		end
	end

	local p = vec_mul(vec_add(data.new_pos, vec_mul(vec_norm(data.new_vel), vector(8,8))), vector(1/8,1/8))
	
	if (fget(mget(p.x, p.y), 0)) then
		local col = collider(flr(p.x)*8+4, flr(p.y)*8+4, 0, 8, 8, false, nil, true)
		data = rb_col_response(rb, col, data)
	end

	if (fget(mget(p.x,p.y), 2)) then
		if (vec_len(data.new_vel)>50) then
			if (rb.rot>0.5) new_rot -= 0.02 else new_rot += 0.02
			if(rb.load) then rb.load.hp -= rb.load.dmg_drift/3 blood(rb.pos,true) end
		end
	end

	if (data.new_pos.x>=phy.bounds.max.x-4) and data.new_vel.x>0 then
		local col = collider(phy.bounds.max.x-4, data.new_pos.y, 0, 8, 100, false, nil, true)
		data = rb_col_response(rb, col, data)
	elseif (data.new_pos.x<=phy.bounds.min.x+4) and data.new_vel.x<0 then
		local col = collider(phy.bounds.min.x+4, data.new_pos.y, 0, 8, 100, false, nil, true)
		data = rb_col_response(rb, col, data)
	end


	if (data.new_pos.y>=phy.bounds.max.y-4) and data.new_vel.y>0 then
		local col = collider(data.new_pos.x, phy.bounds.max.y-4, 0, 100, 8, false, nil, true)
		data = rb_col_response(rb, col, data)
	elseif (data.new_pos.y<=phy.bounds.min.y+4) and data.new_vel.y<0 then
		local col = collider(data.new_pos.x, phy.bounds.min.y-4, 0, 100, 8, false, nil, true)
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
	local threshold = 0.125--atan2(c.w/2, c.h/2)
		if (angle<threshold)  then n = col_left(c)
	elseif (angle==threshold) then n = vec_add(col_left(c), col_up(c))
	elseif (angle<threshold*3)  then n = col_up(c)
	elseif (angle==threshold*3) then n = vec_add(col_right(c), col_up(c))
	elseif (angle<threshold*5)  then n = col_right(c)
	elseif (angle==threshold*5) then n = vec_add(col_right(c), col_down(c))
	elseif (angle<threshold*7)  then n = col_down(c)
	elseif (angle==threshold*7) then n = vec_add(col_left(c), col_down(c))
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

function randomPermutation(n)
	local availables = {}
	local permutation = {}
	for i=1,n do
		add(availables, i)
	end
	for i=1, n do
		local j=flr((rnd()*1000)%#availables)
		local v=availables[j+1]
		del(availables, v)
		add(permutation, v)
	end
	return permutation
end

function colour_to_score(c)
	return  (c == 10) and 2
	or ((c == 14) and 3
	or ((c == 11) and 5
	or ((c == 8) and 4
	or ((c == 1) and 3
	or ((c == 4) and 7
	or 1)))))
end

particles = {}
nparts = 0
--pcl = {}

function create_raw_particles(x, y, lt, np, draw)
	local pcl={
		x=x,
		y=y,
		lifetime=lt,
		draw=draw,
		timer=0.0,
		npart=np
	}
	add(particles, pcl)
	nparts += np
	return pcl
end

function blood(pos, simulated)
	local pcl=create_raw_particles(pos.x, pos.y, .2, 2, draw_blood)
	pcl.simulated=simulated
	init_blood(pcl)
end

function init_blood(pcl)
	pcl.pcs = {}
	for i=1,pcl.npart,1 do
		local a=rnd(1)
		local pc = {
			x=pcl.x, y=pcl.y,
			s={x=cos(a)*rnd(2),	y=-abs(sin(a))-2-rnd(2)},
			lt=pcl.lifetime*(rnd(0.4)+1)
		}
		add(pcl.pcs, pc)
	end
end

function draw_blood(pcl)
	for pc in all(pcl.pcs) do
		local p = (pc.lt / pcl.lifetime)
		circfill(pc.x, pc.y,p,8)
		pc.s.y += 1
		pc.x+=pc.s.x
		pc.y+=pc.s.y
		pc.lt-=1/30
		if (pc.lt<=0) del(pcl.pcs, pc)
	end
	if #pcl.pcs==0 then
		pcl.timer=pcl.lifetime+1
	end
end

function draw_particles()
	for pcl in all(particles) do
		if (pcl.timer >= pcl.lifetime and pcl.lifetime > 0) then
			nparts -= pcl.npart
			del(particles, pcl)
		else
			pcl.draw(pcl)
		end
	end
end

__gfx__
00a77a000000000000077700006fff700f000000c000c00000777777777777005555555556666666655555555555555566666661666666666666666166666666
007777000000fc0000007000006ff6fffcf00000cc0cc00007222255551111705555557555666666665555555555555666666615666666666666666166666666
0766667011000c000077777000ccccff0c000000ccccc00072222255551111175555557555566666666555555555556666666155666666666666666166666666
07788770001cccff0007b70000fccf70f0f00000cc0ccccc72222255551111175555557555556666666655555555566666661555666666666666666166666666
07255170111cccff0007b70007fcc60000000000c000ccc072222255551111175555557555555666666665555555666666615555666666666666666166666666
0788887000000c000007b700ff6446000000000000000c0072222555555111175555557555555566666666555556666666155555666666666666666166666666
0778877000000c0000007000ff644600000000000000ccc072222555555111175555557555555556666666655566666661555555666666666666666166666666
0777777000000f000000700007f4460000000000000ccccc75555555555555575555555555555555666666665666666615555555111111116666666166666666
77788777777777776777777655aa55aa77777777777777777777777777777777555555555555555555555555667777665555555558888885633333b6bbb3bbbb
7778877777733777677677765aa55aa577555577775555777711117777dddd7755555555575555555555557567bbbb7655555555588788853333333bbbb33bbb
777887777773377767677776aa55aa557755557777555577771ddd7777daaa775555555555755555555557557bb32b3755555555588788853333333bbbb333bb
888888887773377767787776a55aa55a7755557777555577771ddd7777daaa775775577555575555555555557b3bb3b755555555588788856334333bbb3333bb
88888888733333376788877655aa55aa7755557777555577771ddd7777daaa775555555555557555555555557bbdbbb7555555555887888563344366bb33333b
7778877777333377677876765aa55aa57711117777dddd77771ddd7777daaa775555555555555755557555557bbb3bb7555555555887888566644666b3333333
777887777773377767776776aa55aa55771ddd7777daaa77771ddd7777daaa7755555555555555755755555567b3bb76555555555887888566544566bb5445bb
777887777777777767777776a55aa55a7777777777777777777777777777777755555555555555555555555566777766555555555888888566555566b544445b
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
55555555555555555555555555555555666666665555555555555555555555555555555551666666666666515555555555555555555555555555555555555555
5ffffffffffffffffffffff555555555699966665575555555555555555555555555575551666666666666515755555557777775555555555555555555555555
5ffffffffffffffffffffff555555555966999665755555555555555555555555555557551666666666666515755555555555555555555555555555555555555
5ffffffffffffffffffffff555555555999669665555555555555555555555555555555551666666666666515755555555555555555555555777777555555555
5ffffffffffffffffffffff555555555696699665555555555555555555555555555555551666666666666515755555555555555555555555555555557777775
5ffffffffffffffffffffff555555555699969665555555555555575575555555555555551666666666666515755555555555555555555555555555555555555
5ffffffffffffffffffffff555555555699996665555555555555755557555555555555551666666666666515755555555555555577777755555555555555555
5ffffffffffffffffffffff555555555666666665555555555555555555555555555555551666666666666515555555555555555555555555555555555555555
88888888766666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff776666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff777666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff777766660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff777776660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff777777660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff777777760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000001010100010101010000000400040101010101010101010101010101040404040101010101010101010101010101010101010101010000000001010000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020000000000000000000000000001090100000000000000000000000000010104000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0f220f0f0f0f0f0f0f0f0f0f0f0f1e28292929292a1e0f36370f0f36370f0f36370f0f0f0f0f0f0f0f0f0f0e3b2b2b2b0f0f0f0f0f0f0f0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0f220f0f0f0f0f0f0f0f0f0f0f0f0f4b4b4b4b4b4b0f3634323736272737363535370f0f0f0f0f0f0f0f0f0e3b2b2b2b1e0f0f2425252525261e0f0f0f1e
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f242251515151510f0f0f0d0d0d0d0c1c1c1c1c1c1c093132303331323033313032330d0d0d0d0d0d0f0f0f0e3b2b2b2b0f0f0f2114161617230f0808080f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f211422141414220f0f0c1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c1c090f0f0e3b2b2b2b0f0f0f2122222222230f1c1c1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f211622161716220f0c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c090f0e3b2b2b2b1e0f0c1c1c1c1c1c1c1c1c1c1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0f0f0f0f0f0f0f0c1c1c0b0f0f0f0f0f0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0f0f0f0f0f0a1c1c0f0e3b2b2b2b0f0e1c1c1c4c1c4c1c4c1c1c1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e0f0f0f0f0f0f0f0f1c1c0b0f0f0f0f0f0e2c2c2c1f1f2c2c1f2c2c2c1f2c2c2c1f2c2d0f0f0f0f0f0e1c1c0f0e3b2b2b2b0f0e1c1c0b0d0d0d0d0d0a1c1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004d4d4d4d4d4d4d4d4d1c1c0f0f1b0f0f1b0e2c1f2c2c2c2c2c2c2c2c2c2c2c1f2c2c2c2d0f0f0f0f0f0e084b0f0e3b2b2b2b1e0e084b0e2c2c2c2c2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004c4c4c4c4c4c4c4c4c1c1c0f0f0f1e1e0f0e2c2c2c1f2c2c2c2c1f2c2c2c2c2c2c2c1f2d0f0f0f0f0f0e084b0f0e3b2b2b2b0f0e084b0e2c2c2c2c2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a0f0d0d0f0f0f0f0f1c1c0f0f0f1e1e0f0e2c1f2c2c2c2c2c2c2c2c2c1f2c2c2c2c1f2d0f0f0f0f0f0e084b0f0e3b2b2b2b0f0e084b0e2c1f2c2c2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e1f2d0f0f0f0f0f1c1c0f0f1b0f0f1b0e2c2c1f2c2c2c2c1f2c2c2c2c1f2c2c2c2c2d0f0f0f0f0f0e084b0f0e3b2b2b2b1e0e1c1c0e2c2c2c2c2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2e2f0f0f0f0f0f1c1c090f0f0f0f0f0e2e2e2e2e2e2e24252525252525252525262f0f0f0f0f0f0e084b0f0e3c3d3d3e0f0c1c1c0e2c2c2c1f2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0d0d0f0f0f0f0f0a1c1c090f0f0f0f0f282a2a2a2a2921162217221022142217232a0f0f0f0d0d0c1c1c090d0d0d0d0d0c1c1c1c0e2c2c2c2c2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2c2d0f0f0f0f0f0f0a1c1c090f0f0f0f0f0f0f0f0f0f21222222222222222222230f0f0f0c1c4d1c1c1c1c1c4d4d4d4d1c1c1c1c0e2c2c2c2c2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e1f2d0f1b0f0f0f0f0f0a1c1c090f0f0f0f0f0f0f0f1e21152214221122152216231e0f0c46454c1c1c1c1c1c4c4c4c4c1c1c1c1c0e2c2c1f2c2d0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e0e2e2f0f0f0f0f0f0f0f0f0a1c1c090f0f0f0f0f0f0f0f21222222222022222222230f0c46450b0f0a1c1c0b0f0f0f0f0f0a1c1c1c0e2e2e2e2e2f0f084b0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d0d0d0d0d0f0f0f0f0f0f0f0f0a1c1c090d0d0d0d0d0d0d0d0d0d0c131313090d0d0d0c46450b0f0f0e084b0f0f3839393a0f0a1c1c0f0f0f0f0f0f0c1c1c0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004d4d4d4d4d4d4d4d4d4d4d4d4d4d1c1c1c1c13131313131c1d4e181c1c1c1c1c184e1d181c0b0d0d0d0e084b0f0e3b3b3b3b0f0f1c1c0f0f0f0f0c1c1c1c1c09
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c090f0f0f0f0f282a0a1c1c1c1c1c0b28292a0f0e2c2c2d0e084b0f0e3b2b2b2b1e0f084b0f0f0f0c1c1c1c1c1c1c
000000000000002425252525252525252526000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004c4c4c4c4c4c4c4c4c4c4c4c4c4c1c1c1c1c1c090f0f0f0f0f4a0e4c1c1c1c4c0f490f0f0f0e2c1f2d0e084b0f0e3b2b2b2b0f0f084b0f0f0f1c1c0b0f0a1c1c
000000000000002115221522102214221523000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a0f0d0d0f0f0f0f0f0f0f0f0f0f0f0f0f0a1c1c090f0f0f0f4a0e4c1c1c1c4c0f490f0f0f0e2e2e2f0e084b0f0e3b2b2b2b0f0f084b0f0f0f1c1c0f1b0f1c1c
000000000000002122222222222222222223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2c2d0f0f0f0f0f0f0f0f0f0f0f0f0f0f0a1c1c090f0f0f4a0f0a0808080b0f490f0f0f0f0f0f0f0e084b0f0e3b2b2b2b1e0f084b0f0f0f1c1c090f0c1c1c
000000000000002115221422112215221423000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e1f2d0f1b0f0f0f0f0f0f0f0f0f0f0f0f0f0a1c1c090f0f4a0f0f0f0f0f0f0f490f0f0f0f0d0d0d0e084b0f0e3b2b2b2b0f0f084b0f0f0f0a1c1c1c1c1c0b
000000000000002122222222202222222223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2e2f0f0f0f0f0f0f0f0f3650370f0f0f0f0f0a1c1c090f4a0f1e0f1e0f1e0f490f0f0f0e2c2c2d0e084b0f0e3b2b2b2b0f0f1c47090f0f0f0a1c1c1c0b0f
000000000000000d0d0d0c131313090d0d0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0d0d0f0f0f0f0f0f0f36322732370f3650370f0a1c1c094a2829292929292a490f0f0f0e2c1f2d0e084b0f0e3b2b2b2b1e0f0a4847090d0d0d0d0d0d0d0d
000000000000001d1818181818181818181d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2d2d0f0f0f0f0f0f0d31343430330d3130331e0f0a1c1c090d0d0d0d0d0d0d0d0d0f0f0e2e2e2f0e084b0f0e3b2b2b2b0f0f0f0a1c1c4d4d4d4d4d4d4d4d
000000000000002b2b2b2b2b2b2b2b2b2b2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e1f2d0f1b0f0f0f0f0a1c1c1c1c1c1c1c1c1c1c4d1c4d1c4d1c4d1c4d1c4d1c4d1c090f0f0f0f0f0e084b0f0e3b2b2b2b0f0f0f0e1c1c1c1c1c1c1c1c1c1c
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2f2f0f0f0f0f0f0f0f0f0f0c1c0f0f0f0f0a1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c090d0d0d0d0c1c1c0f0e3b2b2b2b1e0f0f0c1c1c4c4c4c4c4c4c4c4c
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0f0d0d0f0f0f0f0f0f0f1e0f4c1c0f1e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0a1c1c1c4d1c4d1c1c1c0f0e3b2b2b2b0f0f0c46450b0f0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2c2d0f0f0f0f0f0f0f0f0f4c1c0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0a1c1c1c1c1c1c1c0b0f0e3c3d3d3e0d0c46450b0f0f0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e1f2d0f1b0f0f0f0f0f1e0f4c1c0f1e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0c1c1c1c1c1c46450b0f0f0f0f0f0f0f0f0f0f
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b0e2e2f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0c08080808081c1c0b0f0f0f0f0f0f0f0f0f0f0f
__sfx__
0106000022550245502455224552275502755000000000002b5502b55000000000002c5502c550000000000027550275502755227552000000000000000000002b5502b550000000000029550295500000000000
010600002754027540275422754200000000000000000000295402954000000000002754027540000000000026542265422654026540275402754000000000002254022540000000000024540000002454000000
010600000c0300c0300c0200c01000000000000c0300c0300c0400c02000000000000c0300c03000000000000c0300c0300c0200c01000000000000c0300c0300c0400c02000000000000c0300c0300000000000
010600000a0300a0300a0200a01000000000000a0300a0300a0400a02000000000000a0300a03000000000000a0300a0300a0200a01000000000000a0300a0300a0400a02000000000000a0300a0300000000000
010600000703007030070200701000000000000703007030070400702000000000000703007030000000000007030070300702007010000000000007030070300704007020000000000007030070300000000000
010600000803008030080200801000000000000803008030080400802000000000000803008030000000000008030080300802008010000000000008030080300804008020000000000008030080300000000000
010600002e5402e5402e5422e542000000000000000000002e5402e5402e5422e542000000000000000000002e5402e54000000000002c5402c54000000000002b5402b540000000000026542265420000000000
010600002754027540275422754200000000000000000000295402954000000000002754027540000000000022542225422254022540275402754000000000002454024540245302452024510245100000000000
0106000022540245402454224542275402754000000000002b5402b54000000000002c5402c540000000000027540275402754227542000000000000000000002b5402b540000000000029540295400000000000
010600000c7530000000000000003f225196001800000000256222561500000000003f225000003f225000003f2250000000000000000c753000000000000000256222561500000000003f225000000000000000
010600000c7530000000000000003f225196001800000000256222561500000000003f225000003f225000003f2250000000000000000c7530000000000000002562225615000000000000000000000000000000
01060000165401854018542185421b5401b54000000000001f5401f5400000000000205402054000000000001b5401b5401b5421b542000000000000000000001f5401f54000000000001d5401d5400000000000
010600001b5401b5401b5421b542000000000000000000001d5401d54000000000001b5401b54000000000001a5421a5421a5401a5401b5401b54000000000001654016540000000000018540000001854000000
010600001b5401b5401b5421b542000000000000000000001d5401d54000000000001b5401b5400000000000165421654216540165401b5401b54000000000001854018540185301852018510185100000000000
010600000a0320a0320a0220a0120c0300c0300c0200c0100c0000000000000000000c0300c0300c0200c01000000000000000000000070300703007020070100000000000000000000000032000320002000010
010600000a0320a0320a0220a0120c0300c0300c0200c0100c0000000000000000000c0300c0300c0200c0100000000000000000000007030070300702007010000000000000000000000c0320c0320c0200c010
010600000c7530000000000000003f2250000000000000002562225615000000000000000000000c753000000c7530000000000000000c753000000000000000256222561500000000003f225000000000000000
010600001b5401b5401b5421b542000000000000000000001d5401d54000000000001b5401b5400000000000165421654216540165401b5401b54000000000001654016540165301652018540185401853018520
010600002754027540275422754200000000000000000000295402954000000000002754027540000000000022542225422254022540275402754000000000002254022540225302252024540245402453024520
010600001852018520185221852218512185120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600002452024520245222452224512245120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01050000187401b7401f740187301b7301f730187301b7201f720187201b7101f710187101b7101f710187101b7101f7100000000000000000000000000000000000000000000000000000000000000000000000
010600000c7530000000000000003f225000000000000000256222561500000000003f225000000c753000000c7530000000000000000c753000003f22500000256222561500000000003f225000003f22500000
010600001f5401f5401f5421f54222540225402254022540275402754027540275402654026540265402654000000000000000000000275402754027542275422654026540265402654027540275402754227542
010600002954029540295422954200000000000000000000275402754027540275402654026540265422654200000000000000000000275402754027540275402254022540225422254224500245002450024500
010600002b5402b5402b5422b542000000000000000000002c5402c5402c5402c5402754027540275422754200000000000000000000265402654127541275401f5401f5401f5421f54200000000000000000001
010600002654026540265422654200000000000000000000275402754027540275402654026540265422654222540225402254222542265002650027500275002454524540245402454024530245252451524515
01060000187601876518760187650c7600c76518760187650c7600c765000000000018760187650c7600c76500000000000000000000187601876500000000001876018765000000000018760187650000000000
01060000167601676516760167650a7600a76516760167650a7600a765000000000016760167650a7600a76500000000000000000000167601676500000000001676016765000000000016760167650000000000
010600001376013765137601376507760077651376013765077600776500000000001376013765077600776500000000000000000000137601376500000000001376013765000000000013760137650000000000
010600001476014765147601476508760087651476014765087600876500000000001476014765087600876508700087000000000000147601476508700087001476014765087000870014760147651476014765
010600000c753000003f2003f2003f2203f2150000000000256222561525600256003f2203f2150c753256003f2203f2150c753000000c7530c70033220332152562225615000003f20033220332152560000000
010600000c753000003f2003f2003f2203f2150000000000256222561525600256003f2203f2150c753256003f2203f2150c753000000c7530c700332203321525622256153f1003f10033220332153f2203f215
010600001b7601b7651b7601b7650f7600f7651b7601b7650f7600f76500000000001b7601b7650f7600f765000000000000000000001b7601b76500000000001b7601b76500000000001b7601b7650000000000
010600001d7601d7651d7601d76511760117651d7601d765117601176500000000001d7601d7651176011765000000000000000000001b7601b76500000000001d7601d76500000000001d7601d7650000000000
010600001f7601f7651f7601f76513760137651f7601f765137601376500000000001f7601f765137601376500000000000000000000137601376500000000001f7601f7650c700000001f7601f7651f7601f765
010600001812018120181101812000000181001811500000181201812018110181200000000000181150000018120181201811018120000000000018115000001813018130181201811000000000001811500000
010600001f1201f1201f1101f12000000000001f115000001f1201f1201f1101f11000000000001f115000001f1201f1201f1101f12000000000001f115000001f1201f1201f1101f12000000000001f11500000
01060000187601876518760187650c7600c76518760187650c7600c765000000000018760187650c7600c76500000000000000000000187601876500000000001876018765000000000016760167650000000000
010600001876018765000000000018760187651876018765167601676500000000001876018760187401874018720187150000018700187000000000000000001870018700187001870018700187000000000000
011000002114021140211401b1401b1401b1402113021130211301b1201b1201b1202111021110211101b1101b1101b1102111021110211151b0001b0001b0000000000000000000000000000000000000000000
010a00003004032040370403704000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00003275032740327403274032720327103271032710327103271032710327100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0103000024540275412b5413754137541375413754137541000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800003f53100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 02404344
00 02424344
01 02084944
00 03014a44
00 04084344
00 05064344
00 02084344
00 03014344
00 04084344
00 05074344
00 0802090b
00 01020a0c
00 01030a0c
00 0803090b
00 08050a0b
00 0105090c
00 0803090b
00 12030911
00 0e131415
00 10424344
00 0f424344
00 16424344
00 17104344
00 18104344
00 17104344
00 190a4344
00 17104344
00 180a4344
00 17104344
00 1a0a4344
00 241b1f25
00 241c2025
00 241d1f25
00 241e2025
00 241b1f25
00 24212025
00 24221f25
00 24232025
00 241b1f25
00 24262025
00 241b1f25
02 64272065

