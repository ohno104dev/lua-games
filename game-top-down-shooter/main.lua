function love.load()
	math.randomseed(os.time())

	sprites = {}
	sprites.space = love.graphics.newImage('sprites/space.jpeg')
	sprites.player = love.graphics.newImage('sprites/player.png')
	sprites.bullet = love.graphics.newImage('sprites/bullet.png')
	sprites.ufo1 = love.graphics.newImage('sprites/ufo1.png')
	sprites.ufo2 = love.graphics.newImage('sprites/ufo2.png')
	sprites.ufo3 = love.graphics.newImage('sprites/ufo3.png')

	player = {}
	player.x = love.graphics.getWidth() / 2
	player.y = love.graphics.getHeight() / 2
	player.speed = 180
	player.damage = false

	mainFont = love.graphics.newFont(30)
	subFont = love.graphics.newFont(15)

	ufos = {}
	bullets = {}

	score = 0
	gameState = 1
	maxTime = 1.8
	timer = maxTime
end

function love.update(dt)
	if gameState == 2 then
		if love.keyboard.isDown("d") and player. x < love.graphics.getWidth() then
			player.x = player.x + player.speed * dt
		end
		if love.keyboard.isDown("a") and player.x > 0 then
			player.x = player.x - player.speed * dt
		end
		if love.keyboard.isDown("w") and player.y > 0 then
			player.y = player.y - player.speed * dt
		end
		if love.keyboard.isDown("s") and player.y < love.graphics.getHeight() then
			player.y = player.y + player.speed * dt
		end
	end
	for i, u in ipairs(ufos) do
		u.x = u.x + math.cos(ufoPlayerAngle(u)) * u.speed * dt
		u.y = u.y + math.sin(ufoPlayerAngle(u)) * u.speed * dt

		if distanceBetween(u.x, u.y, player.x, player.y) < 30 then
			for i, u in ipairs(ufos) do
				ufos[i] = nil

				if player.damage  then
					gameState = 1
					player.x = love.graphics.getWidth() / 2
					player.y = love.graphics.getHeight() / 2
					player.damage = false
				else
					player.damage = true
					player.speed = player.speed * 2
				end


			end
		end
	end

	for i, b in ipairs(bullets) do
		b.x = b.x + math.cos(b.direction) * b.speed * dt
		b.y = b.y + math.sin(b.direction) * b.speed * dt
	end

	for i, u in ipairs(ufos) do
		for j, b in ipairs(bullets) do
			if distanceBetween(u.x, u.y, b.x, b.y) < 20 then
				u.dead = true
				b.dead = true

				score = score + u.kind
			end
		end
	end

	for i =#ufos,1 , -1 do
		local u = ufos[i]
		if u.dead == true then
			table.remove(ufos, i)
		end
	end

	for i =#bullets,1 , -1 do
		local u = bullets[i]
		if u.dead == true then
			table.remove(bullets, i)
		end
	end

	if gameState == 2 then
		timer = timer - dt
		if timer <= 0 then
			swapnUfo()
			maxTime = 0.9 * maxTime
			timer = maxTime
		end
	end
end

function love.draw()
	love.graphics.draw(sprites.space, 0, 0, 0, love.graphics.getWidth() / sprites.space:getWidth(), love.graphics.getHeight() / sprites.space:getHeight())
	if player.damage and gameState ~= 1 then
		love.graphics.setColor(1,0,0)
		love.graphics.draw(sprites.player, player.x, player.y, playerMouseAngle(), 1.5, 1.5
	, sprites.player:getWidth()/2,sprites.player:getHeight()/2)
	else
		love.graphics.draw(sprites.player, player.x, player.y, playerMouseAngle(), 1.5, 1.5
		, sprites.player:getWidth()/2,sprites.player:getHeight()/2)
	end
	love.graphics.setColor(1,1,1)

	if gameState == 1 then
		love.graphics.setFont(mainFont)
		love.graphics.printf({{1,1,0},"Click anywhere to begin!"}, 0, 50, love.graphics.getWidth(), "center")
		love.graphics.setFont(subFont)
		love.graphics.printf({{0.8,0.8,0},"A,W,S,D to move!"}, 0, 100, love.graphics.getWidth(), "center")
		love.graphics.printf({{0.8,0.8,0},"right click to shoot!"}, 0, 120, love.graphics.getWidth(), "center")
	end
	love.graphics.setFont(mainFont)
	love.graphics.printf({{1,1,0},"Score: ".. score}, 0, love.graphics.getHeight() - 100, love.graphics.getWidth(), "center")

	for i, u in ipairs(ufos) do 
		if u.kind == 1 then
			love.graphics.draw(sprites.ufo1, u.x, u.y, ufoPlayerAngle(u), 1.5, 1.5, sprites.ufo1:getWidth()/2,sprites.ufo1:getHeight()/2)
		end

		if u.kind == 2 then
			love.graphics.draw(sprites.ufo2, u.x, u.y, ufoPlayerAngle(u), 1.5, 1.5, sprites.ufo2:getWidth()/2,sprites.ufo2:getHeight()/2)
		end

		if u.kind == 3 then
			love.graphics.draw(sprites.ufo3, u.x, u.y, ufoPlayerAngle(u), 1.5, 1.5, sprites.ufo3:getWidth()/2,sprites.ufo3:getHeight()/2)
		end
	end

	for i, b in ipairs(bullets) do 
		love.graphics.draw(sprites.bullet, b.x, b.y, nil, 0.5, nil, sprites.bullet:getWidth()/2,sprites.bullet:getHeight()/2)
	end

	for i =#bullets, 1, -1 do
		local b = bullets[i]
		if b.x < 0 or b.y < 0 or b.x > love.graphics.getWidth() or b.y > love.graphics.getHeight() then
			table.remove(bullets, i)
		end
	end
end

function love.keypressed(key)
	if key == "space" then
		swapnUfo()
	end
end

function love.mousepressed(x, y, button)
	if button == 1 and gameState == 2 then
		spawnBullet()
	elseif button == 1 and gameState == 1 then
		gameState = 2
		maxTime = 1.8
		timer = maxTime
		score = 0
		player.damage = false
		player.speed = 180
	end
end

function playerMouseAngle()
	return math.atan2(player.y - love.mouse.getY(), player.x - love.mouse.getX()) + math.pi
end

function ufoPlayerAngle(ufo)
	-- return math.atan2(player.y - ufo.y, player.x - ufo.x) - math.pi
	return math.atan2(player.y - ufo.y, player.x - ufo.x)
end

function swapnUfo()
	local ufo = {}
	ufo.x = 0
	ufo.y = 0
	ufo.kind = (math.random(0,3) % 3) + 1
	ufo.speed = 100 + math.random(10) * 20
	ufo.dead = false

	local side = math.random(1, 4)
	if side == 1 then
		ufo.x = -30
		ufo.y = math.random(0,love.graphics.getHeight())
	elseif side == 2 then
		ufo.x = love.graphics.getWidth() + 30
		ufo.y = math.random(0,love.graphics.getHeight())
	elseif side == 3 then
		ufo.x = math.random(0,love.graphics.getWidth())
		ufo.y = -30
	elseif side == 4 then
		ufo.x = math.random(0,love.graphics.getWidth())
		ufo.y = love.graphics.getHeight() + 30
	end

	table.insert(ufos, ufo)
end

function spawnBullet()
	local bullet = {}
	bullet.x = player.x
	bullet.y = player.y
	bullet.speed = 500
	bullet.dead = false
	bullet.direction = playerMouseAngle()
	table.insert(bullets, bullet)
end

function distanceBetween(x1, y1, x2, y2)
	return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end