pico-8 cartridge // http://www.pico-8.com
version 21
__lua__
-- configs and global data
game={
	play=true,
}

phy={
	dt=1/60,
	friction=0.5,
	bounce=0.5
}

cam={
	x=0,
	y=0
}
-->8
-- main program
function _init()
	a=rigidbody(64,64,0, 10,10)
	b=collider(90,64,0, 20,20)
end

function _update60()
	cls()

	if (game.play) then
		game_update()
	else
		menu_update()
	end
end

function _draw()
	if (game.play) then
		game_draw()
	else
		menu_draw()
	end
end

-->8
-- game program
function game_update()
	local input = vector(0,0)
	if (btn(0)) input.x-=1
	if (btn(1)) input.x+=1
	if (btn(2)) input.y-=1
	if (btn(3)) input.y+=1
	input = vec_mul(input, vector(40, 40))
	a.acc = vec_add(a.acc, input)

	physics_update()
end

function game_draw()
	if (col_overlap_col(a, b)) then
		color(7)
	else
		color(13)
	end
	col_draw(a)
	col_draw(b)
end

-->8
-- menu program
function menu_update()

end

function menu_draw()

end

-->8
-- physics
colliders={}
rigidbodies={}

function physics_update()
	for i=1, #rigidbodies do
		rb_update(rigidbodies[i])
	end
end

function rigidbody(x, y, r, w, h)
	local rb = collider(x, y, r, w, h, true)
	rb.acc = vector(0, 0)
	rb.vel = vector(0, 0)
	rb.mom = 0
	rb.tor = 0
	add(rigidbodies, rb)
	return rb
end

function rb_update(rb)
	local dt=vector(phy.dt, phy.dt)
	
	local new_acc = vec_sub(rb.acc, vec_mul(rb.vel, vector(phy.friction, phy.friction)))
	
	local new_vel = vec_add(rb.vel, vec_mul(new_acc, dt))
	local new_pos = vec_add(rb.pos, vec_mul(new_vel, dt))
	
	local new_tor = rb.tor - rb.mom * phy.friction
	local new_mom = rb.mom + new_tor * phy.dt
	local new_rot = rb.rot + new_mom * phy.dt
	
	local new_col = collider(new_pos.x, new_pos.y, new_rot, rb.w, rb.h, false, true)
	print(rb.tor)
	for i=1, #colliders do
		local col = colliders[i]
		if (col != rb) then
			if (not col.trg) then
				local hit = col_overlap_col(new_col, col)
				if (hit) then
					local norm = col_normal(new_col, hit)
					local loc_hit = inv_tr_point(new_col, hit)
					local loc_hit_norm = inv_tr_vector(new_col, norm)
					local loc_hit_tan =  mul_mat_vec(rot_matrix(0.25), loc_hit_norm)

					local v = vec_dot(new_vel, norm) * (1 + phy.bounce)

					new_vel = vec_sub(new_vel, vec_mul(vector(v,v),norm))
					
					new_pos = vec_add(rb.pos, vec_mul(new_vel, dt))
					new_col.pos = new_pos
				end
			end
		end
	end
	rb.acc = vector(0,0)
	rb.vel = new_vel
	rb.pos = new_pos
	rb.mom = new_mom
	rb.rot = new_rot
end

function collider(x, y, r, w, h, trg, ign)
	local c = transform(x, y, r)
	c.w = w
	c.h = h
	c.trg = trg
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
	print(angle)
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

__gfx__
00a77a00000f00ff000b00000000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700000cccff000b30000007ff70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
076666700000ccc0000b3000666fccf6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
077887704004ccc000bbb300444cccff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07888870444440cf00bbb300444cccff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07888870000400000bbbbb30f66fcc66000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0778877000040000000450007ff70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0777777000044000004445000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007777870000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007778880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555577870000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555556770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555556770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555556770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555556770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000555556770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000