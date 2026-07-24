function love.load()
	math.randomseed(os.time())

	target = {}

	pigeon = {}

	superman = {}

	score = 0
	timer = 0
	gameState = 1
	scoreSubmitted = false

	targetDt = 0
	pigeonDt = 0
	supermanDt = 0

	sprites = {}
	sprites.sky = love.graphics.newImage('sprites/sky.png')
	sprites.target = love.graphics.newImage('sprites/target.png')
	sprites.crosshairs = love.graphics.newImage('sprites/crosshairs.png')
	sprites.pigeon = love.graphics.newImage('sprites/pigeon.png')
	sprites.superman = love.graphics.newImage('sprites/superman.png')

	crosshair = {
		x = love.graphics.getWidth() / 2,
		y = love.graphics.getHeight() / 2
	}

	updateLayout()
	resetEntity(target)
	resetEntity(pigeon)
	resetEntity(superman)

	love.mouse.setVisible(false)
end

--  detal time
function love.update(dt)
	if timer > 0 then
		timer = timer - dt
		pigeonDt = pigeonDt +dt
		supermanDt = supermanDt +dt
		targetDt = targetDt +dt

		if targetDt > 0.9 then
			resetEntity(target)
			targetDt = 0
		end
		if pigeonDt > 0.7 then
			resetEntity(pigeon)
			pigeonDt = 0
		end

		if supermanDt > 0.5 then
			resetEntity(superman)
			supermanDt = 0
		end
	end
	if timer <= 0 and gameState == 2 then
		timer = 0
		gameState = 1
		submitGameScore()
	end
end

function love.draw()
	drawBackground()
	
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(gameFont)
	love.graphics.print("Score: " .. score, hudPadding, hudPadding)
	love.graphics.printf("Time: " .. math.ceil(timer), 0, hudPadding, love.graphics.getWidth() - hudPadding, "right")

	if gameState == 1 then
		love.graphics.setFont(promptFont)
		love.graphics.printf("Click or tap anywhere to begin!\nDON'T HIT THE PIGEONS!", promptPadding, love.graphics.getHeight() * 0.42, love.graphics.getWidth() - promptPadding * 2, "center")
	end

	if gameState == 2 then
		drawEntity(sprites.target, target)
		drawEntity(sprites.pigeon, pigeon)
		drawEntity(sprites.superman, superman)
	end

	drawCrosshair()
end

function love.mousepressed(x, y, button, istouch, presses)
	if istouch then
		return
	end

	if button == 1 then
		handlePress(x, y)
	end
end

function love.mousemoved(x, y)
	crosshair.x = x
	crosshair.y = y
end

function love.touchpressed(id, x, y)
	handlePress(x, y)
end

function love.touchmoved(id, x, y)
	crosshair.x = x
	crosshair.y = y
end

function love.resize(width, height)
	updateLayout()
	keepEntityInBounds(target)
	keepEntityInBounds(pigeon)
	keepEntityInBounds(superman)
	crosshair.x = clamp(crosshair.x, 0, width)
	crosshair.y = clamp(crosshair.y, 0, height)
end

function handlePress(x, y)
	crosshair.x = x
	crosshair.y = y

	if gameState == 2 then
		local mouseToTarget = distanceBetween(x, y, target.x, target.y)
		local mouseToPigeon = distanceBetween(x, y, pigeon.x, pigeon.y)
		local mouseToSuperman = distanceBetween(x, y, superman.x, superman.y)
		if mouseToTarget < target.radius then
			score = score + 100
			resetEntity(target)
		end

		if mouseToPigeon < pigeon.radius then
			score = score - 150
			resetEntity(pigeon)
		end

		if mouseToSuperman < superman.radius then
			score = score + 300
			timer = timer + 3
			resetEntity(superman)
		end

	elseif gameState == 1 then
		gameState = 2
		timer = 15
		score = 0
		scoreSubmitted = false
		resetEntity(target)
		resetEntity(pigeon)
		resetEntity(superman)
	end
end

function distanceBetween(x1, y1, x2, y2)
	return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function submitGameScore()
	if scoreSubmitted then
		return
	end

	scoreSubmitted = true

	if love.js and love.js.eval then
		love.js.eval("if(window.LuaGameScoreboard){window.LuaGameScoreboard.recordScore(" .. score .. ");}")
	end
end

function updateLayout()
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	layoutScale = clamp(math.min(width / 800, height / 600), 0.65, 1.12)
	fontScale = clamp(math.min(width / 800, height / 600), 0.65, 1.05)
	hudPadding = math.floor(8 * layoutScale)
	promptPadding = math.floor(24 * layoutScale)
	entityRadius = math.floor(50 * layoutScale)
	crosshairScale = clamp(layoutScale, 0.8, 1.2)
	gameFont = love.graphics.newFont(math.floor(40 * fontScale))
	promptFont = love.graphics.newFont(math.floor(30 * fontScale))

	if target then
		target.radius = entityRadius
	end
	if pigeon then
		pigeon.radius = entityRadius
	end
	if superman then
		superman.radius = entityRadius
	end
end

function drawBackground()
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	local scale = math.max(width / sprites.sky:getWidth(), height / sprites.sky:getHeight())
	local x = (width - sprites.sky:getWidth() * scale) / 2
	local y = (height - sprites.sky:getHeight() * scale) / 2

	love.graphics.draw(sprites.sky, x, y, 0, scale, scale)
end

function drawEntity(sprite, entity)
	local scale = entity.radius * 2 / math.max(sprite:getWidth(), sprite:getHeight())
	love.graphics.draw(sprite, entity.x, entity.y, 0, scale, scale, sprite:getWidth() / 2, sprite:getHeight() / 2)
end

function drawCrosshair()
	local scale = crosshairScale
	love.graphics.draw(sprites.crosshairs, crosshair.x, crosshair.y, 0, scale, scale, sprites.crosshairs:getWidth() / 2, sprites.crosshairs:getHeight() / 2)
end

function resetEntity(entity)
	entity.radius = entityRadius
	entity.x = randomBetween(entity.radius, love.graphics.getWidth() - entity.radius)
	entity.y = randomBetween(entity.radius + gameFont:getHeight(), love.graphics.getHeight() - entity.radius)
end

function keepEntityInBounds(entity)
	entity.radius = entityRadius
	entity.x = clamp(entity.x, entity.radius, love.graphics.getWidth() - entity.radius)
	entity.y = clamp(entity.y, entity.radius + gameFont:getHeight(), love.graphics.getHeight() - entity.radius)
end

function randomBetween(minValue, maxValue)
	if maxValue <= minValue then
		return (minValue + maxValue) / 2
	end

	return minValue + math.random() * (maxValue - minValue)
end

function clamp(value, minValue, maxValue)
	if maxValue < minValue then
		return (minValue + maxValue) / 2
	end

	return math.max(minValue, math.min(value, maxValue))
end
