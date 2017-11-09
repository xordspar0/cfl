local Controls = require("controls")
local Debug = require("debugTools")
local InGame = require("gamestates/inGame")
local Player = require("player")
local SceneParser = require("sceneParser")
local World = require("world")

local InitWorld = {}

function InitWorld.init(scene, playerHostility, ifSave)
	world = World.create(playerHostility)
	love.physics.setMeter(1) -- there are 20 pixels per meter

	local fileName
	if ifSave then
		fileName = string.format("%s.txt", scene)
	else
		fileName = string.format("/res/scenes/%s.txt", scene)
	end

	local sceneLines = love.filesystem.lines(fileName)
	local ships, shipType = SceneParser.loadScene(sceneLines, world, {0, 0})
	local players = {}
	for i,ship in ipairs(ships) do
		if shipType[i] == 2 then
			if #players == 0 then
				table.insert(players, Player.create(world, Controls.defaults(), ship))
			elseif #players > 0 then
				local joystick = love.joystick.getJoysticks()[#players]
				if joystick then
					table.insert(players, Player.create(world, Controls.defaults(joystick), ship))
				end
			end
		end

		world:addObject(ship)
	end

	InGame.setplayers(players)
	InGame.setWorld(world)

	Debug.setWorld(world)
	Debug.setPlayers(players)
end

return InitWorld
