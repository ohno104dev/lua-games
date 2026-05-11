function love.load()
	target = {}
	target.x = 300
	target.y = 300
	target.radius = 50

	pigeon = {}
	pigeon.x = 100
	pigeon.y = 100
	pigeon.radius = 50

	superman = {}
	superman.x = 400
	superman.y = 400
	superman.radius = 50

	score = 0
	timer = 0
	gameState = 1

	targetDt = 0
	pigeonDt = 0
	supermanDt = 0

	gameFont = love.graphics.newFont(40)

	sprites = {}
	sprites.sky = love.graphics.newImage('sprites/sky.png')
	sprites.target = love.graphics.newImage('sprites/target.png')
	sprites.crosshairs = love.graphics.newImage('sprites/crosshairs.png')
	sprites.pigeon = love.graphics.newImage('sprites/pigeon.png')
	sprites.superman = love.graphics.newImage('sprites/superman.png')

	love.mouse.setVisible(false)
end

--  detal time
function love.update(dt)
	if timer > 0 then
		timer = timer - dt
		pigeonDt = pigeonDt +dt
		supermanDt = supermanDt +dt
		targetDt = targetDt +dt

		if targetDt > 0.3 then
			target.x = math.random(target.radius, love.graphics.getWidth() - target.radius)
			target.y = math.random(target.radius, love.graphics.getHeight() - target.radius)
			targetDt = 0
		end
		if pigeonDt > 0.3 then
			pigeon.x = math.random(pigeon.radius, love.graphics.getWidth() - pigeon.radius)
			pigeon.y = math.random(pigeon.radius, love.graphics.getHeight() - pigeon.radius)
			pigeonDt = 0
		end

		if supermanDt > 0.2 then
			superman.x = math.random(superman.radius, love.graphics.getWidth() - superman.radius)
			superman.y = math.random(superman.radius, love.graphics.getHeight() - superman.radius)
			supermanDt = 0
		end
	end
	if timer < 0 then
		timer = 0
		gameState = 1
	end
end

function love.draw()
	love.graphics.draw(sprites.sky, 0, 0)
	
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(gameFont)
	love.graphics.print("Score: " .. score, 5, 5)
	love.graphics.print("Time: " .. math.ceil(timer), 600, 5)

	if gameState == 1 then
		love.graphics.printf("Click anywhere to begin!  DON'T HIT THE PIGEONS!", 0, 250, love.graphics.getWidth(), "center")
	end

	if gameState == 2 then
		love.graphics.draw(sprites.target, target.x - target.radius, target.y - target.radius)
		love.graphics.draw(sprites.pigeon, pigeon.x - pigeon.radius, pigeon.y - pigeon.radius)
		love.graphics.draw(sprites.superman, superman.x - superman.radius, superman.y - superman.radius)
	end
	love.graphics.draw(sprites.crosshairs, love.mouse.getX() - 20, love.mouse.getY() - 20)
end

function love.mousepressed(x, y, button, istouch, presses)
	if button == 1 and gameState == 2 then
		local mouseToTarget = distanceBetween(x, y, target.x,target.y)
		local mouseToPigeon = distanceBetween(x, y, pigeon.x,pigeon.y)
		local mouseToSuperman = distanceBetween(x, y, superman.x,superman.y)
		if mouseToTarget < target.radius then
			score = score + 1
			target.x = math.random(target.radius, love.graphics.getWidth() - target.radius)
			target.y = math.random(target.radius, love.graphics.getHeight() - target.radius)
		end

		if mouseToPigeon < pigeon.radius then
			score = score - 2
			pigeon.x = math.random(pigeon.radius, love.graphics.getWidth() - pigeon.radius)
			pigeon.y = math.random(pigeon.radius, love.graphics.getHeight() - pigeon.radius)
		end

		if mouseToSuperman < superman.radius then
			score = score + 5
			superman.x = math.random(superman.radius, love.graphics.getWidth() - superman.radius)
			superman.y = math.random(superman.radius, love.graphics.getHeight() - superman.radius)
		end

	elseif button == 1 and gameState == 1 then
		gameState = 2
		timer = 10
		score = 0
	end
end

function distanceBetween(x1, y1, x2, y2)
	return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end