local fn = vim.fn
local api = vim.api
local uv = vim.uv

local M = {}

function M.command(name, func, opts)
  opts = opts or {}
  if type(opts) == 'string' then
    opts = { desc = opts }
  end
  api.nvim_create_user_command(name, func, opts)
end

function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  if type(opts) == 'string' then
    opts = { desc = opts }
  end
  if opts.silent == nil then
    opts.silent = true
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.feedkeys(chars)
  local keys = api.nvim_replace_termcodes(chars, true, false, true)
  api.nvim_feedkeys(keys, 'in', true)
end

function M.augroup(name)
  return api.nvim_create_augroup('Fittencode_' .. name, { clear = true })
end

function M.get_cursor()
  local cursor = api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  return row, col
end

function M.debounce(timer, callback, wait)
  local function destroy_timer()
    if timer then
      if timer:has_ref() then
        timer:stop()
        if not timer:is_closing() then
          timer:close()
        end
      end
      timer = nil
    end
  end
  if not timer then
    timer = uv.new_timer()
    timer:start(
      wait,
      0,
      vim.schedule_wrap(function()
        destroy_timer()
        callback()
      end)
    )
  else
    timer:again()
  end
end

function M.write(data, path, callback)
  uv.fs_open(path, 'w', 438, function(_, fd)
    if fd ~= nil then
      uv.fs_write(fd, data, -1, function(_, _)
        uv.fs_close(fd, function(_, _) end)
        if callback then
          vim.schedule(function()
            callback(path)
          end)
        end
      end)
    end
  end)
end

function M.write_mkdir(data, dir, path, callback)
  uv.fs_mkdir(dir, 448, function(_, _)
    M.write(data, path, callback)
  end)
end

function M.write_temp_file(data, callback)
  M.write(data, fn.tempname(), callback)
end

function M.read(path, callback)
  uv.fs_open(path, 'r', 438, function(_, fd)
    if fd ~= nil then
      uv.fs_fstat(fd, function(_, stat)
        if stat ~= nil then
          uv.fs_read(fd, stat.size, -1, function(_, data)
            uv.fs_close(fd, function(_, _) end)
            if callback then
              vim.schedule(function()
                callback(data)
              end)
            end
          end)
        end
      end)
    end
  end)
end

function M.exists(file)
  return uv.fs_stat(file) ~= nil
end

function M.nt_sep()
  return '\\'
end

function M.kernel_sep()
  return '/'
end

function M.is_windows()
  return uv.os_uname().sysname == 'Windows_NT'
end

function M.is_kernel()
  return uv.os_uname().sysname == 'Linux'
end

function M.to_nt(s)
  return s:gsub(M.kernel_sep(), M.nt_sep())
end

function M.to_kernel(s)
  return s:gsub(M.nt_sep(), M.kernel_sep())
end

function M.to_native(s)
  return M.is_windows() and M.to_nt(s) or M.to_kernel(s)
end

function M.is_alpha(char)
  local byte = char:byte()
  return (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
end

function M.is_space(char)
  local byte = string.byte(char)
  return byte == 32 or byte == 9
end

-- NVIM v0.10.0-dev-2315+g32b49448b
-- Build type: RelWithDebInfo
-- LuaJIT 2.1.1707061634
function M.get_version()
  local version = fn.execute('version')

  local function find_part(offset, part)
    local start = version:find(part, offset)
    if start == nil then
      return nil
    end
    start = start + #part
    local end_ = version:find('\n', start)
    if end_ == nil then
      end_ = #version
    end
    return start, end_, version:sub(start, end_ - 1)
  end

  local _, end_, nvim = find_part(0, 'NVIM ')
  local _, end_, buildtype = find_part(end_, 'Build type: ')
  local _, _, luajit = find_part(end_, 'LuaJIT ')

  return {
    nvim = nvim,
    buildtype = buildtype,
    luajit = luajit,
  }
end

return M
