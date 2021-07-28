_GlobalCallbacks = _GlobalCallbacks or {}

_G.globals = {_store = _GlobalCallbacks}

function globals._create(f)
  table.insert(globals._store, f)
  return #globals._store
end

function globals._execute(id, args)
  globals._store[id](args)
end
