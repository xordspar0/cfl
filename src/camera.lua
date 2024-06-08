local Animation = require("animation")
local Hud = require("hud")
local PhysicsReferences = require("world/physicsReferences")
local Settings = require("settings")
local log = require("log")
local mathext = require("syntheinrust").mathext
local vector = require("vector")

local Camera = {}
Camera.__index = Camera

function Camera.create()
	local self = {}
	setmetatable(self, Camera)

	self.x = 0
	self.y = 0
	self.angle = 0
	self.zoomInt = 8
	self:adjustZoom(0)
	self.scissor = {x = 0, y = 0, width = 0, height = 0}
	self.gameOver = false

	self.graphics = {}
	setmetatable(self.graphics, self)

	self.hud = Hud()

	self.shieldShader = love.graphics.newShader[[
		extern number radius;
		
		extern vec2 to_world_tran;
		extern mat2 to_world_rot;
		
		vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
			vec4 pixel = Texel(texture, texture_coords );//This is the current pixel color
			
			vec2 world_coords = to_world_rot * (screen_coords - to_world_tran);
			
			number r = world_coords.x * world_coords.x + world_coords.y * world_coords.y;
			number limit = radius * radius;
			
			if(r < limit){
				return vec4(1.0,0.0,0.0,0.5);//red
			}
			else
			{
				return vec4(0,0.0,0.0,0);//clear
			}
		}
	]]

	-- transform screen coords to worlds cords
	--p00x + x * xdx + y * ydx, p00y + x * xdy + y * ydy
	self.shieldShader:send("radius", 100)
	self.shieldShader:send("to_world_tran", {50, 200}) 
	self.shieldShader:send("to_world_rot", {{1, 0}, {0, 1}}) 

	return self
end

function Camera:setTarget(target)
	local duration = 1
	local x, y = self.body:getPosition()
	local angle = self.body:getAngle()

	self.body = target
	self.pan = Animation({x, y, angle}, {target:getX(), target:getY(), target:getAngle()}, duration, "linear")
end

function Camera:getWorldCoords(cursorX, cursorY)
	local scissor = self.scissor
	local xoffset, yoffset = vector.rotate(
		(cursorX - scissor.width/2  - scissor.x) / self.zoom,
		-(cursorY - scissor.height/2 - scissor.y) / self.zoom,
		self.angle)
	return self.x + xoffset, self.y + yoffset
end

function Camera:getScreenCoords(worldX, worldY, a, b)
	local scissor = self.scissor
	local x =  self.zoom * (worldX - self.x) + scissor.x + scissor.width/2
	local y = -self.zoom * (worldY - self.y) + scissor.y + scissor.height/2
	a = self.zoom * a
	b = self.zoom * b
	return x, y, a, b
end

function Camera:getAABB()
	-- Offset for the corners with the same x and y sign.
	local xoffset1, yoffset1 = vector.rotate(
		self.scissor.width /(2 * self.zoom),
		self.scissor.height/(2 * self.zoom),
		self.angle
	)

	-- Offset for the corners with the opposite x and y sign.
	local xoffset2, yoffset2 = vector.rotate(
		-self.scissor.width/(2 * self.zoom),
		self.scissor.height/(2 * self.zoom),
		self.angle
	)

	local points = {
		{
			self.x - xoffset1,
			self.y - yoffset1
		},
		{
			self.x + xoffset2,
			self.y - yoffset2
		},
		{
			self.x + xoffset1,
			self.y + yoffset1
		},
		{
			self.x - xoffset2,
			self.y + yoffset2
		}
	}

	local minX, maxX = self.x, self.x
	local minY, maxY = self.y, self.y

	for _, point in ipairs(points) do
		minX = math.min(minX, point[1])
		minY = math.min(minY, point[2])
		maxX = math.max(maxX, point[1])
		maxY = math.max(maxY, point[2])
	end

	return minX, minY, maxX, maxY
end

-- Make sure the correct transforms are active
function Camera:getAllPoints()
	local scissor = self.scissor
	local pointTable = {}
	local inverseTransform = love.graphics.inverseTransformPoint
	local xdx, xdy, ydx, ydy
	local p00x, p00y = inverseTransform(0, 0)
	local p10x, p10y = inverseTransform(1, 0)
	local p01x, p01y = inverseTransform(0, 1)
	xdx = p10x - p00x
	xdy = p10y - p00y
	ydx = p01x - p00x
	ydy = p01y - p00y
	local ye = scissor.height - 1
	local xe = scissor.width - 1
	for y = 0, ye do
		local row = {}
		for x = 0, xe do
			row[x+1] = {p00x + x * xdx + y * ydx, p00y + x * xdy + y * ydy}
		end
		pointTable[y+1] = row
	end

	return pointTable
end

-- Make sure the correct transforms are active
function Camera:testPoints(testFunctions)
	local scissor = self.scissor
	local table_insert = table.insert
	local inverseTransform = love.graphics.inverseTransformPoint
	local xdx, xdy, ydx, ydy
	local p00x, p00y = inverseTransform(0, 0)
	local p10x, p10y = inverseTransform(1, 0)
	local p01x, p01y = inverseTransform(0, 1)
	xdx = p10x - p00x
	xdy = p10y - p00y
	ydx = p01x - p00x
	ydy = p01y - p00y
	local ye = scissor.height - 1
	local xe = scissor.width - 1
	local drawPoints = {}
	local pointList = {}
	local l = 1
	for y = 0, ye do
		for x = 0, xe do
			local result
			for _, test in ipairs(testFunctions) do
				result = result or test(
					p00x + x * xdx + y * ydx, p00y + x * xdy + y * ydy)
			end

			if result then
				pointList[l] = x
				pointList[l+1] = y
				l = l + 2
				if l >= 250 then
					table_insert(drawPoints, pointList)
					pointList = {}
					l = 1
				end
			end
		end
	end

	return drawPoints
end

function Camera:adjustZoom(step)

	self.zoomInt = self.zoomInt + step

	local remainder = self.zoomInt%6
	local exponential = (self.zoomInt - remainder)/6

	self.zoom = 10 ^ exponential

	if remainder == 1 then
		self.zoom = self.zoom * 1.5 --10 ^ (1 / 6) = 1.47
	elseif remainder == 2 then
		self.zoom = self.zoom * 2   --10 ^ (2 / 6) = 2.15
	elseif remainder == 3 then
		self.zoom = self.zoom * 3   --10 ^ (3 / 6) = 3.16
	elseif remainder == 4 then
		self.zoom = self.zoom * 5   --10 ^ (4 / 6) = 4.64
	elseif remainder == 5 then
		self.zoom = self.zoom * 7   --10 ^ (5 / 6) = 6.81
	end
end

function Camera:setScissor(x, y, width, height)
	self.scissor = {x = x, y = y, width = width, height = height}
end

function Camera:limitCursor(cursorX, cursorY)
	local width = self.scissor.width
	local height = self.scissor.height

	return mathext.clamp(cursorX, 0, width), mathext.clamp(cursorY, 0, height)
end

function Camera:print(string, x, y)
	x = x or 0
	y = y or 0
	local scissor = self.scissor
	love.graphics.print(string, scissor.x + x, scissor.y + y)
end


local function debugDraw(fixture)
	love.graphics.push("all")
	love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
	love.graphics.setLineWidth(2/Settings.PARTSIZE)

	local shape = fixture:getShape()
	local type = shape:getType()

	if type == "circle" then
		local x, y = shape:getPoint()
		x, y = fixture:getBody():getWorldPoint(x, y)
		love.graphics.circle("line", x, y, shape:getRadius())
	elseif type == "polygon" then
		love.graphics.polygon("line", fixture:getBody():getWorldPoints(shape:getPoints()))
	else
		error("Unhandled shape type \"" .. type .. "\"")
	end

	love.graphics.pop()
end

function Camera:drawWorldObjects(player, debugmode)

	local startTime, endTime, duration
	startTime = love.timer.getTime( )


	local drawOrder = {
		"visual",
		"projectiles",
		"missile",
		"general",
		"shield"
	}
	if debugmode then
		table.insert(drawOrder, "sensor")
	end

	local fixtureList = {}

	for _, c in ipairs(drawOrder) do
		fixtureList[PhysicsReferences.categories[c]] = {}
	end

	local function callback(fixture)
		local category = fixture:getFilterData()
		if fixtureList[category] then
			table.insert(fixtureList[category], fixture)
		end
		return true
	end

	local a, b, c, d = player.camera:getAABB()
	player.world.physics:queryBoundingBox(a, b, c, d, callback)


	local drawMode
	if self.zoom < 0.1 then
		drawMode = 4
	elseif self.zoom < 1 then
		drawMode = 3
	elseif self.zoom < 10 then
		drawMode = 2
	else
		drawMode = 1
	end

	endTime = love.timer.getTime( )
	duration = endTime - startTime
	startTime = endTime
	if duration > 0.0001 then
		log:warn("Drawing World Objects setup tasks took too long: " .. duration)
	end

	for _, category in ipairs(drawOrder) do
		local categoryNumber = PhysicsReferences.categories[category]
		for _, fixture in ipairs(fixtureList[categoryNumber]) do
			local object = fixture:getUserData()
			if object.draw then object:draw(fixture, player.showHealth, drawMode) end
			if debugmode then
				debugDraw(fixture)
			end
		end
	end

	endTime = love.timer.getTime( )
	duration = endTime - startTime
	startTime = endTime
	if duration > 0.0004 then
		log:warn("Drawing World Objects main loop took too long: " .. duration)
	end

	local shieldCategoryNumber = PhysicsReferences.categories["shield"]

	local testPointFunctions = {}
	for _, shieldFixture in ipairs(fixtureList[shieldCategoryNumber]) do
		table.insert(testPointFunctions, shieldFixture:getUserData().testPoint())
	end
	player.shieldPoints = player.camera:testPoints(testPointFunctions)


	endTime = love.timer.getTime( )
	duration = endTime - startTime
	startTime = endTime
	if duration > 0.0005 then
		log:warn("Drawing World Objects shields took too long: " .. duration)
	end

end

local function shortestPath(angle, newAngle)
	local angleDiff = newAngle - angle
	if angleDiff > math.pi then
		angleDiff = angleDiff - 2*math.pi
	end
	return angle + angleDiff
end

function Camera:update(player, dt)
	if self.body then
		local newX, newY = self.body:getPosition()
		local newAngle = shortestPath(
			self.angle,
			player.isCameraAngleFixed and 0 or self.body:getAngle() % (2*math.pi)
		)

		if self.pan then
			self.x, self.y, self.angle = self.pan:step(dt, {newX, newY, newAngle})

			if self.pan:isDone() then
				self.pan = nil
			end
		else
			self.x, self.y, self.angle = newX, newY, newAngle
		end
	end
end

function Camera:drawPlayer(player, debugmode)
	local compassAngle = 0

	--TODO this no longer makes sense
	local body = self.body
	if body then
		if player.ship == nil then
			self.body = nil
			self.gameOver = true
		else
			local point = {0,0}

			local leader = (player.ship.corePart or {}).leader
			if leader then
				point = leader:getLocation()
			end
			if player.ship.isDestroyed then
				player.ship = nil
			end

			compassAngle = math.atan2(self.x - point[1], self.y - point[2])
				+ math.pi/2 + self.angle
		end
	end

	local startTime, endTime, duration
	startTime = love.timer.getTime( )

	local scissor = self.scissor

	local viewPort = {}
	viewPort.width = scissor.width
	viewPort.height = scissor.height

	local cursorWorldX, cursorWorldY = player.camera:getWorldCoords(player.cursorX, player.cursorY)

	local playerDrawPack = {}
	playerDrawPack.compassAngle = compassAngle
	playerDrawPack.camera = {x = self.x, y = self.y, width = self.scissor.width, height = self.scissor.height}
	playerDrawPack.cursor = {x = player.cursorX, y = player.cursorY, worldX = cursorWorldX, worldY = cursorWorldY, image = player.cursor}
	playerDrawPack.menu = player.menu
	playerDrawPack.partSelector = player.partSelector
	playerDrawPack.gameOver = self.gameOver
	playerDrawPack.selection = player.selected
	playerDrawPack.zoom = self.zoom

	love.graphics.setScissor(unpack(scissor))

	--Set translation for world objects
	love.graphics.translate(scissor.x, scissor.y)
	love.graphics.translate(scissor.width/2, scissor.height/2)
	love.graphics.rotate(self.angle)
	love.graphics.scale(self.zoom, -self.zoom)
	love.graphics.translate(- self.x, - self.y)

	self:drawWorldObjects(player, debugmode)

	endTime = love.timer.getTime( )
	duration = endTime - startTime
	startTime = endTime
	if duration > 0.001 then
		log:warn("Drawing World Objects took too long: " .. duration)
	end

	--Set translation for hud elements that point to world objects
	love.graphics.origin()
	love.graphics.translate(scissor.x, scissor.y)
	love.graphics.translate(scissor.width/2, scissor.height/2)
	love.graphics.rotate(self.angle)
	love.graphics.scale(self.zoom, -self.zoom)
	love.graphics.translate(- self.x, - self.y)

	self.hud:drawLabels(playerDrawPack, viewPort)

	endTime = love.timer.getTime( )
	duration = endTime - startTime
	startTime = endTime
	if duration > 0.001 then
		log:warn("Drawing Hud Labels took too long: " .. duration)
	end

	--Set translation for hud
	love.graphics.origin()
	love.graphics.translate(scissor.x, scissor.y)

	
	love.graphics.setShader(self.shieldShader) --draw something here
	love.graphics.rectangle( "fill", 0, 0, scissor.width, scissor.height)
	love.graphics.setShader()

	--Draw shields
	love.graphics.setColor(31/255, 63/255, 143/255, 95/255)
	local drawPoints = love.graphics.points
	for _, list in ipairs(player.shieldPoints) do
		drawPoints(unpack(list))
	end
	love.graphics.setColor(1, 1, 1, 1)

	self.hud:draw(playerDrawPack, viewPort)

	endTime = love.timer.getTime( )
	duration = endTime - startTime
	startTime = endTime
	if duration > 0.001 then
		log:warn("Drawing Hud took too long: " .. duration)
	end

	--Reset graphics translation
	love.graphics.origin()

	love.graphics.setScissor()
end

return Camera
