local Part = require("part")
local Util = require("util")

local Structure = {}
Structure.__index = Structure

Structure.PARTSIZE = 20

function Structure.create(part, physics, x, y)
	local self = {}
	setmetatable(self, Structure)

	self.thrust = 0

	if part.type == "player" then
		self.body = love.physics.newBody(physics, x, y, "dynamic")
		self.body:setAngularDamping(1)
		self.body:setLinearDamping(0.5)
		self.thrust = part.thrust
		self.torque = part.torque
		self.type = "ship"
	elseif part.type == "anchor" then
		self.body = love.physics.newBody(physics, x, y, "static")
		self.type = "anchor"
	else
		self.body = love.physics.newBody(physics, x, y, "dynamic")
		self.body:setAngularDamping(0.2)
		self.body:setLinearDamping(0.1)
		self.type = "generic"
	end

	self.parts = {part}
	self.partCoords = { {x = 0, y = 0} }
	self.partOrient = {1}
	self.fixtures = {love.physics.newFixture(self.body, part.physicsShape)}

	return self
end

-- The table set to nill.

function Structure:destroy()
	
	end

-- Annex another structure into this one.
-- ** After calling this method, the annexed structure will be destroyed and
-- should be removed from any tables it is referenced in.
-- Parameters:
-- annexee is the structure to annex
-- annexeePart is the block that will connect to this structure
-- orientation is the side of annexee to attach
-- structurePart is the block to connect the structure to
-- side is the side of structurePart to add the annexee to
function Structure:annex(annexee, annexeePart, annexeeSide, structurePart,
	                     structureSide)
	local aIndex = annexee:findPart(annexeePart)
	local bIndex = self:findPart(structurePart)
	local structureOffsetX, structureOffsetY

	if structureSide == 1 then
		structureOffsetX = self.partCoords[bIndex].x
		structureOffsetY = self.partCoords[bIndex].y - 1
	elseif structureSide == 2 then
		structureOffsetX = self.partCoords[bIndex].x + 1
		structureOffsetY = self.partCoords[bIndex].y
	elseif structureSide == 3 then
		structureOffsetX = self.partCoords[bIndex].x
		structureOffsetY = self.partCoords[bIndex].y + 1
	elseif structureSide == 4 then
		structureOffsetX = self.partCoords[bIndex].x - 1
		structureOffsetY = self.partCoords[bIndex].y
	end

	local annexeeOrientation = structureSide - annexeeSide
			while annexeeOrientation < 1 do
				annexeeOrientation = annexeeOrientation + 4
			end

			while annexeeOrientation >4 do
				annexeeOrientation = annexeeOrientation -4
			end

			local annexeeX = annexee.partCoords[aIndex].x
			local annexeeY = annexee.partCoords[aIndex].y

	for i=1,#annexee.parts do

		local x, y
		local annexeeOffsetX = annexee.partCoords[1].x - annexeeX
		local annexeeOffsetY = annexee.partCoords[1].y - annexeeY

		if annexeeOrientation == 1 then
			x = structureOffsetX + annexeeOffsetY
			y = structureOffsetY - annexeeOffsetX
		elseif annexeeOrientation == 2 then
			x = structureOffsetX + annexeeOffsetX
			y = structureOffsetY + annexeeOffsetY
		elseif annexeeOrientation == 3 then
			x = structureOffsetX - annexeeOffsetY
			y = structureOffsetY + annexeeOffsetX
		elseif annexeeOrientation == 4 then
			x = structureOffsetX - annexeeOffsetX
			y = structureOffsetY - annexeeOffsetY
		end

		-- Find out the orientation of the part based on the orientation of
		-- both structures.
		local partOrientation = annexeeOrientation + annexee.partOrient[1] + 2
		-- Make sure partOrientation is between 1 and 4
		while partOrientation > 4 do
			partOrientation = partOrientation - 4
		end
		while partOrientation < 1 do
			partOrientation = partOrientation + 4
		end

		self:addPart(annexee.parts[1], x, y, partOrientation)
		annexee:removePart(annexee.parts[1])
	end
end

function Structure:removeSection(part)	

end

-- Add one part to the structure.
-- x, y are the coordinates in the structure
-- orientation is the orientation of the part according to the structure
function Structure:addPart(part, x, y, orientation)
	local x1, y1, x2, y2, x3, y3, x4, y4 = part.physicsShape:getPoints()
	local width = math.abs(x1 - x3)
	local height = math.abs(y1 - y3)
	local shape = love.physics.newRectangleShape(
		x*self.PARTSIZE, y*self.PARTSIZE, width, height)
	local fixture = love.physics.newFixture(self.body, shape)

	table.insert(self.parts, part)
	table.insert(self.partCoords, {x = x, y = y})
	table.insert(self.partOrient, orientation)
	table.insert(self.fixtures, fixture)
end

-- Check if a part is in this structure.
-- If it is, return the index of the part.
-- If it is not, return nil.
function Structure:findPart(query)
	for i, part in ipairs(self.parts) do
		if part == query then
			return i
		end
	end

	return nil
end

-- Find the specified part and destroy it. If there are no more parts in the
-- structure, then destroy the structure and return 1. Otherwise return nil.
-- ** Always check the return value and remove the reference to the structure
-- if it is destroyed.
function Structure:removePart(part)
	i = self:findPart(part)
	if i then
		self.fixtures[i]:destroy()
		table.remove(self.parts, i)
		table.remove(self.partCoords, i)
		table.remove(self.fixtures, i)
		table.remove(self.partOrient, i)
	end

	-- Signal to the calling function that the structure is empty.
	if #self.parts == 0 then
		return 1
	end
end

-- Find the absolute coordinates of a part given the x and y offset values of
-- the part and the absolute coordinates and angle of the structure it is in.
function Structure:getAbsPartCoords(index)
	local x, y = Util.computeAbsCoords(
		self.partCoords[index].x*self.PARTSIZE,
		self.partCoords[index].y*self.PARTSIZE,
		self.body:getAngle())

	return self.body:getX() + x, self.body:getY() + y, 
		   self.body:getAngle() % (2*math.pi)
end

function Structure:command(orders)
	-- The x and y components of the force
	local Fx = self.thrust * math.cos(self.body:getAngle() - math.pi/2)
	local Fy = self.thrust * math.sin(self.body:getAngle() - math.pi/2)

	for i, order in ipairs(orders) do
		if order == "forward" then
			-- Apply the base force from the playerBlock.
			self.body:applyForce(Fx, Fy, self.body:getX(), self.body:getY())

			-- Apply the force for the engines
			for i,part in ipairs(self.parts) do
				-- Choose parts that have thrust and are pointed the right
				-- direction, but exclude playerBlock, etc.
				if part.thrust and
				part.type == "generic" and
				self.partOrient[i] == 1 then
					part.isActive = true
					self.body:applyForce(Fx, Fy, self:getAbsPartCoords(i))
				end
			end
		elseif order == "back" then
			self.body:applyForce(-Fx, -Fy, self.body:getX(), self.body:getY())

			for i,part in ipairs(self.parts) do
				if part.thrust and
				part.type == "generic" and
				self.partOrient[i] == 3 then
					part.isActive = true
					self.body:applyForce(-Fx, -Fy, self:getAbsPartCoords(i))
				end
			end
		elseif order == "strafeLeft" then
			self.body:applyForce(Fy, -Fx, self.body:getX(), self.body:getY())

			for i,part in ipairs(self.parts) do
				if part.thrust and
				part.type == "generic" and
				self.partOrient[i] == 4 then
					part.isActive = true
					self.body:applyForce(Fy, -Fx, self:getAbsPartCoords(i))
				end
			end
		elseif order == "strafeRight" then
			self.body:applyForce(-Fy, Fx, self.body:getX(), self.body:getY())

			for i,part in ipairs(self.parts) do
				if part.thrust and
				part.type == "generic" and
				self.partOrient[i] == 2 then
					part.isActive = true
					self.body:applyForce(-Fy, Fx, self:getAbsPartCoords(i))
				end
			end
		elseif order == "left" then
			self.body:applyTorque(-self.torque)

			for i,part in ipairs(self.parts) do
				if part.thrust and part.type == "generic" then
					if self.partOrient[i] == 1 and self.partCoords[i].x > 0 then
						part.isActive = true
						self.body:applyForce(Fx, Fy, self:getAbsPartCoords(i))

					elseif self.partOrient[i] == 2 and self.partCoords[i].y > 0 then
						part.isActive = true
						self.body:applyForce(-Fy, Fx, self:getAbsPartCoords(i))

					elseif self.partOrient[i] == 3 and self.partCoords[i].x < 0 then
						part.isActive = true
						self.body:applyForce(-Fx, -Fy, self:getAbsPartCoords(i))

					elseif self.partOrient[i] == 4 and self.partCoords[i].y < 0 then
						part.isActive = true
						self.body:applyForce(Fy, -Fx, self:getAbsPartCoords(i))
					end
				end
			end
		elseif order == "right" then
			self.body:applyTorque(self.torque)

			for i,part in ipairs(self.parts) do
				if part.thrust and part.type == "generic" then
					if self.partOrient[i] == 1 and self.partCoords[i].x < 0 then
						part.isActive = true
						self.body:applyForce(Fx, Fy, self:getAbsPartCoords(i))

					elseif self.partOrient[i] == 2 and self.partCoords[i].y < 0 then
						part.isActive = true
						self.body:applyForce(-Fy, Fx, self:getAbsPartCoords(i))

					elseif self.partOrient[i] == 3 and self.partCoords[i].x > 0 then
						part.isActive = true
						self.body:applyForce(-Fx, -Fy, self:getAbsPartCoords(i))

					elseif self.partOrient[i] == 4 and self.partCoords[i].y > 0 then
						part.isActive = true
						self.body:applyForce(Fy, -Fx, self:getAbsPartCoords(i))
					end
				end
			end
		end
	end
end

function Structure:getPartIndex(locationX,locationY)
	for j, part in ipairs(self.parts) do
		local partX, partY, partAngle = self:getAbsPartCoords(j)
		if Util.vectorMagnitude(locationX - partX, locationY - partY) <
		   part.width/2 then
			local partSide = Util.vectorAngle(
				locationX - partX, 
				locationY - partY) - partAngle 
			partSide = math.floor((partSide*2/math.pi + 3/2) % 4 + 1 )
			return part, partSide
		end
	end
end

function Structure:update()
	for k, part in ipairs(self.parts) do
		if part.isActive then
			part.isActive = false
		end
	end
end

function Structure:draw(globalOffsetX, globalOffsetY)
	for i, part in ipairs(self.parts) do
		local x, y = self:getAbsPartCoords(i)
		part:draw(x, y,
				self.body:getAngle() + (self.partOrient[i] - 1) * math.pi/2,
				globalOffsetX, globalOffsetY)
	end
end

return Structure
