local localPath = scriptPath()
dofile(localPath.."stateMachine.lua")

-- dialog
dialogInit()
local screens = {'nil'}
for i, screen in ipairs(stateMachine.screens) do
  table.insert(screens, screen.name)
end

addTextView('while failed <= ')
addEditNumber('opt_failed', 5)
addTextView(' do')
newRow()
addTextView('\t\tstateMachine:goto(')
newRow()
addTextView('\t\t\t')
addSpinner('opt_state1', screens, screens[#screens >= 2 and 2 or 1])
newRow()
addTextView('\t\t\t')
addSpinner('opt_state2', screens, screens[#screens >= 3 and #screens or 1])
newRow()
addTextView('\t\t\t')
addSpinner('opt_state3', screens, 'nil')
newRow()
addTextView('\t\t\t')
addEditText('opt_states', 'nil,nil,nil')
newRow()
addTextView('\t\t)')
newRow()
addTextView('\t\twait(')
addEditNumber('opt_delay', 5)
addTextView(')  -- seconds')
newRow()
addTextView('end')
dialogShow('settings')

opt_states = table.concat({opt_state1, opt_state2, opt_state3, opt_states}, ',')
local states = {}
for state in string.gmatch(opt_states, '([^,]+)') do
  state = state:gsub('%s+', "")
  if state ~= '' and state ~= 'nil' then
    table.insert(states, state)
  end
end
toast('goto(' .. table.concat(states, ", ") .. ')')

failed = 0
while failed <= opt_failed do
  if not stateMachine:goto(unpack(states)) then
    stateMachine:debug('failed')
    wait(10)
    failed = failed + 1
  end

  failed = 0
  wait(opt_delay)
end
scriptExit('failed ' .. failed .. ' times')
