pico-8 cartridge // http://www.pico-8.com
version 21
__lua__
-- configs and global data
game={
	play=false,
}

phy={
	dt=1/60,
}
-->8
-- main program
function _init()

end

function _update60()
	if (game.play) then
		game_update()
	else
		menu_update()
	end
end

function _draw()
	cls()
	if (game.play) then
		game_draw()
	else
		menu_draw()
	end
end

-->8
-- game program
function game_update()

end

function game_draw()

end

-->8
-- menu program
function menu_update()

end

function menu_draw()

end
