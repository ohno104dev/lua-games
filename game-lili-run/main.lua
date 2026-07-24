local SCREEN_WIDTH = 960
local SCREEN_HEIGHT = 540
local PIXEL_SCALE = 3
local VIRTUAL_WIDTH = SCREEN_WIDTH / PIXEL_SCALE
local VIRTUAL_HEIGHT = SCREEN_HEIGHT / PIXEL_SCALE
local GROUND_HEIGHT = 78
local PLAYER_X = 140
local GRAVITY = 2400
local JUMP_VELOCITY = -720
local JUMP_HOLD_FORCE = -2000
local MAX_JUMP_HOLD = 0.16
local JUMP_RELEASE_DAMP = 0.42
local START_SPEED = 340
local MAX_SPEED = 610
local SPEED_RAMP = 5
local MIN_OBSTACLE_GAP = 300
local MAX_OBSTACLE_GAP = 460
local DAY_LENGTH = 22
local BONUS_SCORE = 100
local JUMP_BUFFER_TIME = 0.12
local COYOTE_TIME = 0.1
local PLAYER_GROUND_DRAW_OFFSET = 10

local state = {}
local fonts = {}
local canvas
local controls = {
	mouseCrouch = false,
	mouseJump = false,
	crouchTouches = {},
	jumpTouches = {},
}
local GROUND_LINE_COLOR = { 0.88, 0.88, 0.88 }
local ROAD_FILL_COLOR = { 0.36, 0.50, 0.30 }
local ROAD_PEBBLE_COLOR = { 0.24, 0.36, 0.20 }
local ROAD_PEBBLE_HIGHLIGHT = { 0.52, 0.68, 0.42 }
local paletteSets = {
	day = {
		skyTop = { 0.63, 0.80, 0.95 },
		skyBottom = { 0.79, 0.89, 0.98 },
		player = { 0.17, 0.32, 0.46 },
		obstacle = { 0.19, 0.37, 0.54 },
		flyer = { 0.25, 0.43, 0.60 },
		bonus = { 0.85, 0.94, 1.00 },
		text = { 0.19, 0.33, 0.46 },
		textSoft = { 0.58, 0.70, 0.84 },
		skyline = { 0.43, 0.58, 0.74 },
	},
	night = {
		skyTop = { 0.03, 0.05, 0.10 },
		skyBottom = { 0.10, 0.14, 0.24 },
		player = { 0.80, 0.89, 0.96 },
		obstacle = { 0.66, 0.78, 0.90 },
		flyer = { 0.57, 0.71, 0.85 },
		bonus = { 0.90, 0.97, 1.00 },
		text = { 0.91, 0.96, 1.00 },
		textSoft = { 0.44, 0.58, 0.72 },
		skyline = { 0.50, 0.64, 0.79 },
	},
}

local function mixColor(a, b, t)
	return {
		a[1] + (b[1] - a[1]) * t,
		a[2] + (b[2] - a[2]) * t,
		a[3] + (b[3] - a[3]) * t,
	}
end

local function currentPalette()
	local cycle = (math.sin(state.dayTimer * math.pi * 2 / DAY_LENGTH - math.pi / 2) + 1) * 0.5
	local nightBlend = math.max(0, (cycle - 0.55) / 0.45)
	local palette = {}

	for key, color in pairs(paletteSets.day) do
		palette[key] = mixColor(color, paletteSets.night[key], nightBlend)
	end

	palette.groundAccent = GROUND_LINE_COLOR

	return palette, nightBlend
end

local function updateCanvas(width, height)
	SCREEN_WIDTH = math.max(320, width or love.graphics.getWidth())
	SCREEN_HEIGHT = math.max(240, height or love.graphics.getHeight())
	VIRTUAL_WIDTH = SCREEN_WIDTH / PIXEL_SCALE
	VIRTUAL_HEIGHT = SCREEN_HEIGHT / PIXEL_SCALE

	if canvas then
		canvas:release()
	end

	canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
	canvas:setFilter("nearest", "nearest")
end

local function resetControls()
	controls.mouseCrouch = false
	controls.mouseJump = false
	controls.crouchTouches = {}
	controls.jumpTouches = {}
end

local function fileExists(path)
	return love.filesystem.getInfo(path) ~= nil
end

local function loadFirstImage(paths)
	for _, path in ipairs(paths) do
		if fileExists(path) then
			return love.graphics.newImage(path), path
		end
	end

	return nil, nil
end

local function buildFrames(image, frameWidth, frameHeight)
	local frames = {}
	local imageWidth = image:getWidth()
	local imageHeight = image:getHeight()
	local columns = math.max(1, math.floor(imageWidth / frameWidth))
	local rows = math.max(1, math.floor(imageHeight / frameHeight))

	for row = 0, rows - 1 do
		for col = 0, columns - 1 do
			frames[#frames + 1] = love.graphics.newQuad(
				col * frameWidth,
				row * frameHeight,
				frameWidth,
				frameHeight,
				imageWidth,
				imageHeight
			)
		end
	end

	return frames
end

local function makeAnimation(options)
	local image, path = loadFirstImage(options.paths)
	if not image then
		return {
			image = nil,
			path = nil,
			frames = nil,
			frameWidth = options.fallbackWidth,
			frameHeight = options.fallbackHeight,
			frameCount = 1,
			frameTime = options.frameTime or 0.1,
			timer = 0,
			index = 1,
		}
	end

	image:setFilter("nearest", "nearest")

	local frameWidth = options.frameWidth or image:getHeight()
	local frameHeight = options.frameHeight or image:getHeight()
	local frames = buildFrames(image, frameWidth, frameHeight)

	return {
		image = image,
		path = path,
		frames = frames,
		frameWidth = frameWidth,
		frameHeight = frameHeight,
		frameCount = #frames,
		frameTime = options.frameTime or 0.1,
		timer = 0,
		index = 1,
	}
end

local function makeStaticSprite(path, fallbackWidth, fallbackHeight)
	return makeAnimation({
		paths = { path },
		frameWidth = fallbackWidth,
		frameHeight = fallbackHeight,
		fallbackWidth = fallbackWidth,
		fallbackHeight = fallbackHeight,
		frameTime = 1,
	})
end

local function snapToPixel(value, grid)
	grid = grid or PIXEL_SCALE
	return math.floor(value / grid + 0.5) * grid
end

local function snapSize(value, grid)
	grid = grid or PIXEL_SCALE
	return math.max(grid, math.floor(value / grid + 0.5) * grid)
end

local function updateAnimation(animation, dt, speedFactor)
	if animation.frameCount <= 1 then
		return
	end

	animation.timer = animation.timer + dt * (speedFactor or 1)
	while animation.timer >= animation.frameTime do
		animation.timer = animation.timer - animation.frameTime
		animation.index = (animation.index % animation.frameCount) + 1
	end
end

local function resetGame()
	resetControls()

	state.player = {
		x = PLAYER_X,
		y = SCREEN_HEIGHT - GROUND_HEIGHT,
		width = 96,
		height = 90,
		velocityY = 0,
		onGround = true,
		jumpHeld = false,
		jumpHoldTimer = 0,
		isCrouching = false,
		standingHeight = 90,
		crouchHeight = 54,
		jumpBufferTimer = 0,
		coyoteTimer = COYOTE_TIME,
	}
	state.player.standingWidth = 108
	state.player.crouchWidth = 108
	state.player.height = state.player.standingHeight
	state.player.width = state.player.standingWidth
	state.obstacles = {}
	state.decor = {}
	state.score = 0
	state.scoreSubmitted = false
	state.bonusScore = 0
	state.distance = 0
	state.speed = START_SPEED
	state.spawnTimer = 1.35
	state.started = false
	state.gameOver = false
	state.flashTimer = 0
	state.dayTimer = 0
end

local function addDecor(x)
	local size = love.math.random(3, 7) * PIXEL_SCALE
	state.decor[#state.decor + 1] = {
		x = x or (SCREEN_WIDTH + love.math.random(48, 140)),
		y = SCREEN_HEIGHT - GROUND_HEIGHT + love.math.random(14, 34) * PIXEL_SCALE,
		width = size,
		height = love.math.random(1, 3) * PIXEL_SCALE,
	}
end

local function submitGameScore()
	if state.scoreSubmitted then
		return
	end

	state.scoreSubmitted = true

	if love.js and love.js.eval then
		love.js.eval("if(window.LuaGameScoreboard){window.LuaGameScoreboard.recordScore(" .. state.score .. ");}")
	end
end

local function spawnObstacle()
	local baseY = SCREEN_HEIGHT - GROUND_HEIGHT
	local roll = love.math.random()

	if state.score >= 80 and roll < 0.18 then
		local width = 54
		local height = 33
		local heightBand = love.math.random(1, 4)
		local yOffset = ({ 18, 36, 60, 88 })[heightBand] * PIXEL_SCALE

		state.obstacles[#state.obstacles + 1] = {
			kind = "bonus",
			x = SCREEN_WIDTH + width,
			y = baseY - yOffset,
			width = width,
			height = height,
			value = BONUS_SCORE,
			animation = state.bonusAnimation,
			hitbox = { left = 10, right = 10, top = 6, bottom = 6 },
			floatAmplitude = 8,
			floatSpeed = 3.2,
			floatPhase = love.math.random() * math.pi * 2,
		}
		return
	end

	local spawnFlying = state.score >= 120 and roll < 0.48

	if spawnFlying then
		local obstacleWidth = 126
		local obstacleHeight = 58
		local flightLevel = love.math.random(1, 4)
		local yOffset = ({ 18, 34, 54, 74 })[flightLevel] * PIXEL_SCALE

		state.obstacles[#state.obstacles + 1] = {
			kind = "flying",
			x = SCREEN_WIDTH + obstacleWidth,
			y = baseY - yOffset,
			width = obstacleWidth,
			height = obstacleHeight,
			animation = state.flyingAnimation,
			hitbox = { left = 14, right = 14, top = 16, bottom = 14 },
			floatAmplitude = 10,
			floatSpeed = 2.6,
			floatPhase = love.math.random() * math.pi * 2,
		}
		return
	end

	local widthTiles = 1
	local heightTiles = 3
	if love.math.random() < 0.72 then
		widthTiles = love.math.random(1, 3)
		heightTiles = 1
	end
	local obstacleWidth
	local obstacleHeight
	local obstacleAnimation

	if heightTiles == 3 then
		obstacleWidth = 54
		obstacleHeight = 126
		obstacleAnimation = state.groundAnimations.tower
	elseif widthTiles == 1 then
		obstacleWidth = 72
		obstacleHeight = 60
		obstacleAnimation = state.groundAnimations.house1
	elseif widthTiles == 2 then
		obstacleWidth = 132
		obstacleHeight = 66
		obstacleAnimation = state.groundAnimations.house2
	else
		obstacleWidth = 192
		obstacleHeight = 66
		obstacleAnimation = state.groundAnimations.house3
	end

	state.obstacles[#state.obstacles + 1] = {
		kind = "ground",
		x = SCREEN_WIDTH + obstacleWidth,
		y = baseY,
		width = obstacleWidth,
		height = obstacleHeight,
		widthTiles = widthTiles,
		heightTiles = heightTiles,
		animation = obstacleAnimation,
		spriteGroundOffset = heightTiles == 3 and 16 or 12,
		hitbox = heightTiles == 3
			and { left = 10, right = 10, top = 18, bottom = 4 }
			or { left = 8, right = 8, top = 20, bottom = 4 },
	}
end

local function intersects(a, b)
	return a.x < b.x + b.width
		and b.x < a.x + a.width
		and a.y - a.height < b.y
		and b.y - b.height < a.y
end

local function canJump()
	return state.player.onGround or state.player.coyoteTimer > 0
end

local function beginJump()
	local player = state.player
	player.velocityY = JUMP_VELOCITY
	player.onGround = false
	player.jumpHeld = true
	player.jumpHoldTimer = 0
	player.jumpBufferTimer = 0
	player.coyoteTimer = 0
	player.isCrouching = false
	player.height = player.standingHeight
	player.width = player.standingWidth
end

local function tryJump()
	if state.gameOver then
		resetGame()
		return
	end

	state.started = true
	state.player.jumpBufferTimer = JUMP_BUFFER_TIME

	if canJump() then
		beginJump()
	end
end

local function releaseJump()
	if state.player.velocityY < 0 then
		state.player.velocityY = state.player.velocityY * JUMP_RELEASE_DAMP
	end
	state.player.jumpHeld = false
end

local function setCrouch(active)
	local player = state.player
	if state.gameOver then
		return
	end

	state.started = true
	player.isCrouching = active

	if active and player.onGround then
		player.height = player.crouchHeight
		player.width = player.crouchWidth
	else
		player.height = player.standingHeight
		player.width = player.standingWidth
	end
end

local function getPlayerBounds()
	local player = state.player
	if player.isCrouching and player.onGround then
		return {
			x = player.x + 18,
			y = player.y - 2,
			width = player.width - 36,
			height = player.height - 8,
		}
	end

	return {
		x = player.x + 24,
		y = player.y - 4,
		width = player.width - 44,
		height = player.height - 14,
	}
end

local function getObstacleBounds(obstacle)
	local hitbox = obstacle.hitbox or { left = 0, right = 0, top = 0, bottom = 0 }
	local bobOffset = obstacle.bobOffset or 0
	return {
		x = obstacle.x + hitbox.left,
		y = obstacle.y + bobOffset - hitbox.bottom,
		width = obstacle.width - hitbox.left - hitbox.right,
		height = obstacle.height - hitbox.top - hitbox.bottom,
	}
end

local function drawSky()
	local palette, nightBlend = currentPalette()
	local bands = 4
	for i = 0, bands - 1 do
		local t = i / (bands - 1)
		local r = palette.skyTop[1] + (palette.skyBottom[1] - palette.skyTop[1]) * t
		local g = palette.skyTop[2] + (palette.skyBottom[2] - palette.skyTop[2]) * t
		local b = palette.skyTop[3] + (palette.skyBottom[3] - palette.skyTop[3]) * t
		love.graphics.setColor(r, g, b)
		love.graphics.rectangle("fill", 0, math.floor(i * SCREEN_HEIGHT / bands), SCREEN_WIDTH, math.ceil(SCREEN_HEIGHT / bands))
	end

	local daylight = 1 - nightBlend
	if daylight > 0.1 then
		local glowBands = 3
		for i = 0, glowBands - 1 do
			local t = i / (glowBands - 1)
			local alpha = (1 - t) * 0.02 * daylight
			love.graphics.setColor(0.90, 0.96, 1.00, alpha)
			love.graphics.rectangle("fill", 0, SCREEN_HEIGHT * 0.08 + i * 14, SCREEN_WIDTH, 48)
		end
	end
end

local function drawCityBackdrop()
	local palette, nightBlend = currentPalette()
	local horizonY = SCREEN_HEIGHT - GROUND_HEIGHT
	local farBaseY = horizonY - 18
	local skylineBaseY = horizonY
	local farOffset = -((state.distance or 0) * 0.08 % SCREEN_WIDTH)
	local frontOffset = -((state.distance or 0) * 0.24 % SCREEN_WIDTH)

	local farBuildings = {
		{ 42, 34, 84 }, { 112, 20, 58 }, { 182, 42, 66 }, { 246, 14, 54 },
		{ 336, 28, 72 }, { 430, 18, 86 }, { 536, 12, 92 }, { 658, 30, 58 },
		{ 736, 30, 70 }, { 842, 24, 74 }
	}
	for repeatIndex = 0, 1 do
		love.graphics.setColor(palette.textSoft[1], palette.textSoft[2], palette.textSoft[3], 0.20 + nightBlend * 0.12)
		local wrap = repeatIndex * SCREEN_WIDTH
		for _, b in ipairs(farBuildings) do
			love.graphics.rectangle("fill", b[1] + farOffset + wrap, farBaseY - b[3], b[2], b[3])
		end
	end

	love.graphics.setColor(palette.skyline[1], palette.skyline[2], palette.skyline[3], 0.90)
	local skyline = {
		{ kind = "rect", x = 0, w = 72, h = 62 },
		{ kind = "tower", x = 78, w = 34, h = 88 },
		{ kind = "tower", x = 122, w = 50, h = 128 },
		{ kind = "shard", x = 186, w = 54, h = 120 },
		{ kind = "rect", x = 246, w = 42, h = 158 },
		{ kind = "tower", x = 298, w = 40, h = 96 },
		{ kind = "crown", x = 350, w = 56, h = 82 },
		{ kind = "rect", x = 420, w = 54, h = 76 },
		{ kind = "tower", x = 472, w = 68, h = 168 },
		{ kind = "tower", x = 554, w = 44, h = 102 },
		{ kind = "tower", x = 612, w = 44, h = 90 },
		{ kind = "tower", x = 664, w = 50, h = 108 },
		{ kind = "rect", x = 726, w = 40, h = 80 },
		{ kind = "crown", x = 780, w = 66, h = 86 },
		{ kind = "rect", x = 860, w = 84, h = 92 },
	}

	local function drawTower(x, w, h)
		love.graphics.rectangle("fill", x + 10, skylineBaseY - h, w - 20, h)
		love.graphics.rectangle("fill", x, skylineBaseY - 26, w, 26)
	end

	local function drawShard(x, w, h)
		love.graphics.polygon("fill", x, skylineBaseY, x + 12, skylineBaseY - h, x + w, skylineBaseY)
	end

	local function drawCrown(x, w, h)
		love.graphics.rectangle("fill", x, skylineBaseY - h + 22, w, h - 22)
		love.graphics.polygon("fill", x, skylineBaseY - h + 22, x + 16, skylineBaseY - h, x + 32, skylineBaseY - h + 18)
		love.graphics.polygon("fill", x + 20, skylineBaseY - h + 22, x + 34, skylineBaseY - h, x + 48, skylineBaseY - h + 18)
		love.graphics.polygon("fill", x + 38, skylineBaseY - h + 22, x + 52, skylineBaseY - h, x + w, skylineBaseY - h + 18)
	end

	for repeatIndex = 0, 1 do
		local wrap = repeatIndex * SCREEN_WIDTH
		for _, item in ipairs(skyline) do
			local drawX = item.x + frontOffset + wrap
			if item.kind == "rect" then
				love.graphics.rectangle("fill", drawX, skylineBaseY - item.h, item.w, item.h)
			elseif item.kind == "tower" then
				drawTower(drawX, item.w, item.h)
			elseif item.kind == "shard" then
				drawShard(drawX, item.w, item.h)
			elseif item.kind == "crown" then
				drawCrown(drawX, item.w, item.h)
			end
		end
	end

	if nightBlend > 0.4 then
		for i = 1, 6 do
			local starX = 24 + ((i * 53) % (SCREEN_WIDTH - 60))
			local starY = 20 + ((i * 31) % 120)
			love.graphics.setColor(0.95, 0.96, 1.0, 0.35 + nightBlend * 0.65)
			love.graphics.rectangle("fill", starX, starY, 6, 6)
		end
	end
end

local function drawGround()
	local palette = currentPalette()
	local topY = SCREEN_HEIGHT - GROUND_HEIGHT

	love.graphics.setColor(ROAD_FILL_COLOR)
	love.graphics.rectangle("fill", 0, topY, SCREEN_WIDTH, GROUND_HEIGHT)

	for x = 18, SCREEN_WIDTH, 64 do
		love.graphics.setColor(ROAD_PEBBLE_COLOR)
		love.graphics.rectangle("fill", x, topY + 16 + ((x / 8) % 6), 2, 8)
		love.graphics.rectangle("fill", x + 4, topY + 18 + ((x / 10) % 8), 2, 6)
		love.graphics.rectangle("fill", x + 10, topY + 15 + ((x / 12) % 5), 2, 7)
		love.graphics.setColor(ROAD_PEBBLE_HIGHLIGHT)
		love.graphics.rectangle("fill", x + 22, topY + 12 + ((x / 7) % 5), 2, 5)
		love.graphics.rectangle("fill", x + 28, topY + 17 + ((x / 9) % 4), 2, 4)
	end

	love.graphics.setColor(palette.groundAccent)
	love.graphics.rectangle("fill", 0, topY, SCREEN_WIDTH, 3)

	for x = 0, SCREEN_WIDTH, 56 do
		love.graphics.setColor(palette.groundAccent[1], palette.groundAccent[2], palette.groundAccent[3], 0.75)
		love.graphics.rectangle("fill", x, topY + 2, love.math.random(2, 6), 1)
	end

	for x = 160, SCREEN_WIDTH, 320 do
		love.graphics.setColor(palette.groundAccent[1], palette.groundAccent[2], palette.groundAccent[3], 0.55)
		love.graphics.line(
			x,
			topY + 3,
			x + 8,
			topY - 1,
			x + 16,
			topY + 3,
			x + 24,
			topY + 3
		)
	end

	for _, pebble in ipairs(state.decor) do
		love.graphics.setColor(palette.groundAccent[1], palette.groundAccent[2], palette.groundAccent[3], 0.16)
		love.graphics.rectangle("fill", pebble.x, pebble.y, pebble.width, pebble.height)
	end
end

local function drawAnimation(animation, x, y, width, height, fallbackColor, snapGrid)
	if snapGrid then
		x = snapToPixel(x, snapGrid)
		y = snapToPixel(y, snapGrid)
		width = snapSize(width, snapGrid)
		height = snapSize(height, snapGrid)
	end

	if animation.image and animation.frames then
		local quad = animation.frames[animation.index]
		local scaleX = width / animation.frameWidth
		local scaleY = height / animation.frameHeight
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(animation.image, quad, x, y, 0, scaleX, scaleY)
		return
	end

	love.graphics.setColor(fallbackColor)
	love.graphics.rectangle("fill", x, y, width, height)
end

local function drawPixelBird(x, y, width, height, color, snapGrid)
	if snapGrid then
		x = snapToPixel(x, snapGrid)
		y = snapToPixel(y, snapGrid)
		width = snapSize(width, snapGrid)
		height = snapSize(height, snapGrid)
	end
	love.graphics.setColor(color)
	love.graphics.rectangle("fill", x + 6, y + 6, width - 12, height - 10)
	love.graphics.rectangle("fill", x + 12, y, width - 24, 8)
	love.graphics.rectangle("fill", x, y + 10, 10, 8)
	love.graphics.rectangle("fill", x + width - 10, y + 10, 10, 8)
end

local function drawPixelBonus(x, y, width, height, color, snapGrid)
	if snapGrid then
		x = snapToPixel(x, snapGrid)
		y = snapToPixel(y, snapGrid)
		width = snapSize(width, snapGrid)
		height = snapSize(height, snapGrid)
	end
	love.graphics.setColor(color)
	love.graphics.rectangle("fill", x + 6, y, width - 12, height)
	love.graphics.rectangle("fill", x, y + 6, width, height - 12)
	love.graphics.setColor(1, 1, 1, 0.45)
	love.graphics.rectangle("fill", x + 6, y + 6, width - 12, height - 12)
end

local function drawPlayer()
	local player = state.player
	local palette = currentPalette()
	local animation = state.playerRunAnimation
	if player.isCrouching and player.onGround then
		animation = state.playerCrouchAnimation
	end
	drawAnimation(
		animation,
		player.x,
		player.y - player.height + PLAYER_GROUND_DRAW_OFFSET,
		player.width,
		player.height,
		palette.player,
		1
	)
end

local function drawObstacles()
	local palette = currentPalette()
	for _, obstacle in ipairs(state.obstacles) do
		local bobOffset = obstacle.bobOffset or 0
		local groundOffset = obstacle.spriteGroundOffset or 0
		if obstacle.kind == "bonus" and obstacle.animation and obstacle.animation.path then
			drawAnimation(obstacle.animation, obstacle.x, obstacle.y + bobOffset - obstacle.height, obstacle.width, obstacle.height, palette.bonus, 1)
		elseif obstacle.kind == "bonus" then
			drawPixelBonus(obstacle.x, obstacle.y + bobOffset - obstacle.height, obstacle.width, obstacle.height, palette.bonus, 1)
		elseif obstacle.kind == "flying" and (not obstacle.animation or not obstacle.animation.path) then
			drawPixelBird(obstacle.x, obstacle.y + bobOffset - obstacle.height, obstacle.width, obstacle.height, palette.flyer, 1)
		else
			drawAnimation(
				obstacle.animation,
				obstacle.x,
				obstacle.y + bobOffset - obstacle.height + groundOffset,
				obstacle.width,
				obstacle.height,
				obstacle.kind == "flying" and palette.flyer or palette.obstacle,
				1
			)
		end
	end
end

local function drawBackgroundLayer()
	love.graphics.push()
	love.graphics.scale(1 / PIXEL_SCALE, 1 / PIXEL_SCALE)
	drawSky()
	drawCityBackdrop()
	drawGround()
	love.graphics.pop()
end

local function drawHud()
	local palette = currentPalette()
	love.graphics.setColor(palette.text)
	love.graphics.setFont(fonts.score)
	love.graphics.print(string.format("Score %05d", state.score), 26, 22)
end

local function isMobileOrTabletLayout()
	local shortSide = math.min(SCREEN_WIDTH, SCREEN_HEIGHT)
	local longSide = math.max(SCREEN_WIDTH, SCREEN_HEIGHT)

	return SCREEN_HEIGHT > SCREEN_WIDTH
		or (SCREEN_WIDTH <= 1024 and SCREEN_HEIGHT >= 700)
		or (shortSide <= 1024 and longSide <= 1366)
end

local function drawCenterMessage()
	local palette = currentPalette()
	love.graphics.setColor(palette.text)
	love.graphics.setFont(fonts.title)

	if state.gameOver then
		love.graphics.printf("Lili fell behind", 0, 126, SCREEN_WIDTH, "center")
		love.graphics.setFont(fonts.small)
		if isMobileOrTabletLayout() then
			love.graphics.printf("Tap right side to restart", 0, 186, SCREEN_WIDTH, "center")
		else
			love.graphics.printf("Press jump to restart", 0, 186, SCREEN_WIDTH, "center")
		end
	elseif not state.started then
		love.graphics.printf("Lili Run", 0, 126, SCREEN_WIDTH, "center")
		love.graphics.setFont(fonts.small)
		if isMobileOrTabletLayout() then
			love.graphics.printf("Left side crouch, right side jump", 0, 186, SCREEN_WIDTH, "center")
		else
			love.graphics.printf("Jump with space/up, crouch with down/s", 0, 186, SCREEN_WIDTH, "center")
		end
	end
end

function love.load()
	love.math.setRandomSeed(os.time())
	love.graphics.setDefaultFilter("nearest", "nearest")
	updateCanvas(love.graphics.getWidth(), love.graphics.getHeight())

	fonts.title = love.graphics.newFont(12 * PIXEL_SCALE)
	fonts.score = love.graphics.newFont(28)
	fonts.small = love.graphics.newFont(20)

	state.playerRunAnimation = makeAnimation({
		paths = {
			"sprites/lili-run.png",
		},
		frameWidth = 120,
		frameHeight = 100,
		fallbackWidth = 120,
		fallbackHeight = 100,
		frameTime = 0.09,
	})

	state.playerCrouchAnimation = makeAnimation({
		paths = {
			"sprites/lili-down.png",
		},
		frameWidth = 120,
		frameHeight = 60,
		fallbackWidth = 120,
		fallbackHeight = 60,
		frameTime = 0.11,
	})

	state.groundAnimations = {
		house1 = makeStaticSprite("sprites/house1.png", 120, 100),
		house2 = makeStaticSprite("sprites/house2.png", 240, 120),
		house3 = makeStaticSprite("sprites/house3.png", 360, 120),
		tower = makeStaticSprite("sprites/tp101.png", 60, 240),
	}
	state.flyingAnimation = makeStaticSprite("sprites/airplane.png", 180, 83)
	state.bonusAnimation = makeStaticSprite("sprites/chicken.png", 60, 37)

	resetGame()

	for i = 1, 7 do
		addDecor((i - 1) * 150 + love.math.random(-24, 24))
	end
end

function love.update(dt)
	local player = state.player

	if state.started and not state.gameOver then
		state.speed = math.min(MAX_SPEED, state.speed + SPEED_RAMP * dt)
		state.distance = state.distance + state.speed * dt
		state.score = math.floor(state.distance / 12) + state.bonusScore
		state.dayTimer = state.dayTimer + dt
		player.jumpBufferTimer = math.max(0, player.jumpBufferTimer - dt)
		player.coyoteTimer = player.onGround and COYOTE_TIME or math.max(0, player.coyoteTimer - dt)

		if player.jumpBufferTimer > 0 and canJump() then
			beginJump()
		end

		if player.jumpHeld and not player.onGround and player.jumpHoldTimer < MAX_JUMP_HOLD then
			player.velocityY = player.velocityY + JUMP_HOLD_FORCE * dt
			player.jumpHoldTimer = player.jumpHoldTimer + dt
		end

		player.velocityY = player.velocityY + GRAVITY * dt
		player.y = player.y + player.velocityY * dt

		local groundY = SCREEN_HEIGHT - GROUND_HEIGHT
		if player.y >= groundY then
			player.y = groundY
			player.velocityY = 0
			player.onGround = true
			player.jumpHeld = false
			player.jumpHoldTimer = 0
			player.coyoteTimer = COYOTE_TIME
			player.height = player.isCrouching and player.crouchHeight or player.standingHeight
			player.width = player.isCrouching and player.crouchWidth or player.standingWidth
		end

		state.spawnTimer = state.spawnTimer - dt
		if state.spawnTimer <= 0 then
			local lastObstacle = state.obstacles[#state.obstacles]
			local canSpawn = not lastObstacle or lastObstacle.x < SCREEN_WIDTH - MIN_OBSTACLE_GAP
			if canSpawn then
				spawnObstacle()
				local spacing = love.math.random(MIN_OBSTACLE_GAP, MAX_OBSTACLE_GAP)
				state.spawnTimer = spacing / state.speed + love.math.random() * 0.3
			else
				state.spawnTimer = 0.08
			end
		end

		for index = #state.obstacles, 1, -1 do
			local obstacle = state.obstacles[index]
			obstacle.x = obstacle.x - state.speed * dt
			obstacle.floatPhase = (obstacle.floatPhase or 0) + dt * (obstacle.floatSpeed or 0)
			obstacle.bobOffset = obstacle.floatAmplitude and math.sin(obstacle.floatPhase) * obstacle.floatAmplitude or 0
			local playerBounds = getPlayerBounds()

			if obstacle.x + obstacle.width < -20 then
				table.remove(state.obstacles, index)
			elseif intersects(playerBounds, getObstacleBounds(obstacle)) then
				if obstacle.kind == "bonus" then
					state.bonusScore = state.bonusScore + obstacle.value
					state.score = math.floor(state.distance / 12) + state.bonusScore
					table.remove(state.obstacles, index)
				else
					state.gameOver = true
					state.flashTimer = 0.15
					submitGameScore()
				end
			end
		end
	end

	local decorSpeed = state.started and state.speed or START_SPEED * 0.2
	for index = #state.decor, 1, -1 do
		local pebble = state.decor[index]
		pebble.x = pebble.x - decorSpeed * 0.45 * dt
		if pebble.x + pebble.width < 0 then
			table.remove(state.decor, index)
			local farthestX = SCREEN_WIDTH
			for _, item in ipairs(state.decor) do
				if item.x > farthestX then
					farthestX = item.x
				end
			end
			addDecor(farthestX + love.math.random(72, 180))
		end
	end

	updateAnimation(state.playerRunAnimation, dt, player.onGround and math.max(1, state.speed / START_SPEED) or 0.45)
	updateAnimation(state.playerCrouchAnimation, dt, player.isCrouching and player.onGround and math.max(1, state.speed / START_SPEED) or 0.3)

	if state.flashTimer > 0 then
		state.flashTimer = math.max(0, state.flashTimer - dt)
	end
end

function love.draw()
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	drawBackgroundLayer()

	if state.flashTimer > 0 then
		love.graphics.setColor(1, 1, 1, state.flashTimer * 4)
		love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
	end
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(canvas, 0, 0, 0, PIXEL_SCALE, PIXEL_SCALE)
	drawObstacles()
	drawPlayer()
	drawHud()
	drawCenterMessage()
end

function love.resize(width, height)
	local oldGroundY = SCREEN_HEIGHT - GROUND_HEIGHT
	local playerWasOnGround = state.player and state.player.onGround

	updateCanvas(width, height)

	if state.player then
		state.player.x = math.min(state.player.x, SCREEN_WIDTH - state.player.width)
		if playerWasOnGround or state.player.y >= oldGroundY - 1 then
			state.player.y = SCREEN_HEIGHT - GROUND_HEIGHT
		else
			state.player.y = math.min(state.player.y, SCREEN_HEIGHT - GROUND_HEIGHT)
		end
	end
end

function love.keypressed(key)
	if key == "space" or key == "up" or key == "w" then
		tryJump()
	elseif key == "down" or key == "s" then
		setCrouch(true)
	end
end

function love.keyreleased(key)
	if key == "space" or key == "up" or key == "w" then
		releaseJump()
	elseif key == "down" or key == "s" then
		setCrouch(false)
	end
end

local function hasActiveTouches(touches)
	return next(touches) ~= nil
end

local function isLeftControl(x)
	return x < SCREEN_WIDTH * 0.5
end

function love.mousepressed(x, _, button, istouch)
	if istouch then
		return
	end

	if button == 1 then
		if isMobileOrTabletLayout() and isLeftControl(x) then
			controls.mouseCrouch = true
			setCrouch(true)
		else
			controls.mouseJump = true
			tryJump()
		end
	end
end

function love.mousereleased(_, _, button, istouch)
	if istouch then
		return
	end

	if button == 1 then
		if controls.mouseCrouch then
			controls.mouseCrouch = false
			if not hasActiveTouches(controls.crouchTouches) then
				setCrouch(false)
			end
		end

		if controls.mouseJump then
			controls.mouseJump = false
			releaseJump()
		end
	end
end

function love.touchpressed(id, x)
	if isMobileOrTabletLayout() and isLeftControl(x) then
		controls.crouchTouches[id] = true
		setCrouch(true)
	else
		controls.jumpTouches[id] = true
		tryJump()
	end
end

function love.touchreleased(id)
	if controls.crouchTouches[id] then
		controls.crouchTouches[id] = nil
		if not controls.mouseCrouch and not hasActiveTouches(controls.crouchTouches) then
			setCrouch(false)
		end
	end

	if controls.jumpTouches[id] then
		controls.jumpTouches[id] = nil
		releaseJump()
	end
end
