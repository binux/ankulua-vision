local localPath = scriptPath()
dofile(localPath.."stateMachine.lua")

failed = 0
while true do
  if failed > 5 then
    scriptExit('failed 5 times')
  end

  if not stateMachine:goto('__STATE_1__', '__STATE_2__', '__STATE_3__') then
    stateMachine:debug('failed')
    wait(10)
    failed = failed + 1
  end
end
