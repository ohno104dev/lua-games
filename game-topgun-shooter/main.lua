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
	player.speed = 260
	player.damage = false
	player.aimX = player.x
	player.aimY = player.y - 100
	player.usingTouchAim = false

	mainFont = love.graphics.newFont(30)
	subFont = love.graphics.newFont(15)

	ufos = {}
	bullets = {}
	touchControls = {
		moveId = nil,
		moveStartX = 0,
		moveStartY = 0,
		moveX = 0,
		moveY = 0,
		dx = 0,
		dy = 0,
		radius = 58
	}

	score = 0
	gameState = 1
	maxTime = 3
	timer = maxTime
end

function love.update(dt)
	if gameState == 2 then
		local moveX = 0
		local moveY = 0

		if love.keyboard.isDown("d") then
			moveX = moveX + 1
		end
		if love.keyboard.isDown("a") then
			moveX = moveX - 1
		end
		if love.keyboard.isDown("s") then
			moveY = moveY + 1
		end
		if love.keyboard.isDown("w") then
			moveY = moveY - 1
		end

		moveX = moveX + touchControls.dx
		moveY = moveY + touchControls.dy

		local moveLength = math.sqrt(moveX * moveX + moveY * moveY)
		if moveLength > 1 then
			moveX = moveX / moveLength
			moveY = moveY / moveLength
		end

		player.x = clamp(player.x + moveX * player.speed * dt, 0, love.graphics.getWidth())
		player.y = clamp(player.y + moveY * player.speed * dt, 0, love.graphics.getHeight())
		updateTouchAim()
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

				score = score + u.kind * 50
				if u.kind == 3 then
					maxTime = maxTime + 0.3
					timer = math.max(timer, maxTime)
				end
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
		love.graphics.printf({{1,1,0},"Click or tap anywhere to begin!"}, 0, 50, love.graphics.getWidth(), "center")
		love.graphics.setFont(subFont)
		love.graphics.printf({{0.8,0.8,0},"A,W,S,D to move!"}, 0, 120, love.graphics.getWidth(), "center")
		love.graphics.printf({{0.8,0.8,0},"Tap the right side to shoot!"}, 0, 140, love.graphics.getWidth(), "center")
	end
	love.graphics.setFont(mainFont)
	love.graphics.print("Score: " .. score, 8, 8)

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
		love.graphics.draw(sprites.bullet, b.x, b.y, nil, 0.3, 0.3, sprites.bullet:getWidth()/2,sprites.bullet:getHeight()/2)
	end

	for i =#bullets, 1, -1 do
		local b = bullets[i]
		if b.x < 0 or b.y < 0 or b.x > love.graphics.getWidth() or b.y > love.graphics.getHeight() then
			table.remove(bullets, i)
		end
	end

	drawTouchControls()
end

function love.keypressed(key)
	if key == "space" then
		swapnUfo()
	end
end

function love.mousepressed(x, y, button, istouch)
	if istouch then
		return
	end

	if button == 1 and gameState == 2 then
		spawnBullet(x, y)
	elseif button == 1 and gameState == 1 then
		startGame()
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	if istouch then
		return
	end

	if not player.usingTouchAim then
		player.aimX = x
		player.aimY = y
	end
end

function playerMouseAngle()
	return math.atan2(player.y - player.aimY, player.x - player.aimX) + math.pi
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
	ufo.speed = 100 + math.random(10) * 30
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

function spawnBullet(targetX, targetY)
	player.aimX = targetX or player.aimX
	player.aimY = targetY or player.aimY

	local bullet = {}
	bullet.x = player.x
	bullet.y = player.y
	bullet.speed = 800
	bullet.dead = false
	bullet.direction = playerMouseAngle()
	table.insert(bullets, bullet)
end

function distanceBetween(x1, y1, x2, y2)
	return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function love.touchpressed(id, x, y)
	if gameState == 1 then
		startGame()
		return
	end

	if gameState ~= 2 then
		return
	end

	if isMoveZone(x, y) and touchControls.moveId == nil then
		touchControls.moveId = id
		touchControls.moveStartX = x
		touchControls.moveStartY = y
		touchControls.moveX = x
		touchControls.moveY = y
		updateMoveTouch(x, y)
	elseif x >= love.graphics.getWidth() * 0.5 then
		spawnBullet()
	end
end

function love.touchmoved(id, x, y)
	if id == touchControls.moveId then
		updateMoveTouch(x, y)
	end
end

function love.touchreleased(id)
	if id == touchControls.moveId then
		touchControls.moveId = nil
		touchControls.dx = 0
		touchControls.dy = 0
		player.usingTouchAim = false
	end
end

function love.resize(width, height)
	player.x = clamp(player.x, 0, width)
	player.y = clamp(player.y, 0, height)
end

function startGame()
	gameState = 2
	maxTime = 1.8
	timer = maxTime
	score = 0
	player.damage = false
	player.speed = 260
	player.x = love.graphics.getWidth() / 2
	player.y = love.graphics.getHeight() / 2
	player.aimX = player.x
	player.aimY = player.y - 100
	player.usingTouchAim = false
end

function isMoveZone(x, y)
	return shouldDrawTouchControls()
		and x <= love.graphics.getWidth() * 0.45
		and y >= love.graphics.getHeight() * 0.45
end

function updateMoveTouch(x, y)
	local maxDistance = touchControls.radius
	local dx = x - touchControls.moveStartX
	local dy = y - touchControls.moveStartY
	local distance = math.sqrt(dx * dx + dy * dy)

	if distance > maxDistance then
		dx = dx / distance * maxDistance
		dy = dy / distance * maxDistance
	end

	touchControls.moveX = touchControls.moveStartX + dx
	touchControls.moveY = touchControls.moveStartY + dy
	touchControls.dx = dx / maxDistance
	touchControls.dy = dy / maxDistance
	updateTouchAim()
end

function updateTouchAim()
	if touchControls.moveId == nil then
		return
	end

	local aimLength = math.sqrt(touchControls.dx * touchControls.dx + touchControls.dy * touchControls.dy)
	if aimLength < 0.16 then
		return
	end

	local aimDistance = 140
	player.aimX = player.x + touchControls.dx / aimLength * aimDistance
	player.aimY = player.y + touchControls.dy / aimLength * aimDistance
	player.usingTouchAim = true
end

function drawTouchControls()
	if not shouldDrawTouchControls() then
		return
	end

	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	local radius = getTouchControlRadius()
	local centerX = math.max(radius + 24, width * 0.18)
	local centerY = height - radius - 28
	local knobX = centerX
	local knobY = centerY

	touchControls.radius = radius

	if touchControls.moveId ~= nil then
		centerX = touchControls.moveStartX
		centerY = touchControls.moveStartY
		knobX = touchControls.moveX
		knobY = touchControls.moveY
	end

	love.graphics.setColor(1, 1, 1, 0.18)
	love.graphics.circle("fill", centerX, centerY, radius)
	love.graphics.setColor(1, 1, 1, 0.42)
	love.graphics.setLineWidth(3)
	love.graphics.circle("line", centerX, centerY, radius)
	love.graphics.setColor(1, 1, 0.2, 0.55)
	love.graphics.circle("fill", knobX, knobY, radius * 0.38)

	love.graphics.setColor(1, 1, 1, 0.22)
	love.graphics.circle("fill", width - radius - 34, height - radius - 28, radius * 0.72)
	love.graphics.setColor(1, 0.85, 0.2, 0.55)
	love.graphics.circle("line", width - radius - 34, height - radius - 28, radius * 0.72)
	love.graphics.setLineWidth(1)
	love.graphics.setColor(1, 1, 1, 1)
end

function shouldDrawTouchControls()
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	local shortSide = math.min(width, height)
	local longSide = math.max(width, height)
	local aspect = longSide / shortSide

	return height > width
		or (shortSide <= 500 and longSide <= 950)
		or (shortSide >= 720 and shortSide <= 1024 and longSide <= 1368 and aspect <= 1.65)
end

function getTouchControlRadius()
	return math.min(64, math.max(42, math.min(love.graphics.getWidth(), love.graphics.getHeight()) * 0.09))
end

function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(value, maxValue))
end
