"""Regression test for the Interact hook; requires lupa (Lua 5.1)."""
import sys
from pathlib import Path

if len(sys.argv) > 1:
    sys.path.insert(0, sys.argv[1])
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / "OctoGather.lua").read_text()
hook = source.split("local function InstallInteractHook()", 1)[1].split(
    "local function ResourceFromLootMessage", 1
)[0]

def check(body):
    lua = LuaRuntime()
    lua.execute("""
        local lastInteractTime, interactWrapper = 0, nil
        local originalInteract -- simulates the old shared upvalue if present
        local calls = 0
        GetTime = function() return 123 end
        Interact = function(flag)
            assert(flag == 1)
            calls = calls + 1
            return 'result', flag
        end
        local function InstallInteractHook()
    """ + body + """
        InstallInteractHook()
        local first = Interact
        InstallInteractHook()
        assert(Interact == first, 'Repeated install should do nothing')
        local a, b = Interact(1)
        assert(a == 'result' and b == 1 and calls == 1)
        assert(lastInteractTime == 123)
        local previous = Interact
        Interact = function(flag) return previous(flag) end
        InstallInteractHook()
        debug.sethook(function() error('recursive hook loop') end, '', 10000)
        a, b = Interact(1)
        debug.sethook()
        assert(a == 'result' and b == 1 and calls == 2)
        Interact = function(flag) calls = calls + 1; return 'replacement' end
        InstallInteractHook()
        assert(Interact(1) == 'replacement' and calls == 3)
        Interact = nil
        InstallInteractHook()
        assert(Interact == nil)
    """)

try:
    check(hook.replace('local originalInteract = Interact', 'originalInteract = Interact'))
except Exception as exc:
    assert 'recursive hook loop' in str(exc), str(exc)
    print('Confirmed: old hook recurses when another addon chains it.')
else:
    raise AssertionError('Old bug was not reproduced')
check(hook)
print('PASS: fixed hook, repeat installs, chaining, replacement, argument/return preservation.')
