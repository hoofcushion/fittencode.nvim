local api = vim.api
local fn = vim.fn

local Base = require('fittencode.base')

local M = {}

---@return string
function M.nt_sep()
  return '\\'
end

---@return string
function M.kernel_sep()
  return '/'
end

---@param s string
---@return string
function M.to_nt(s)
  return (s:gsub(M.kernel_sep(), M.nt_sep()))
end

---@param s string
---@return string
function M.to_kernel(s)
  return (s:gsub(M.nt_sep(), M.kernel_sep()))
end

---@param s string
---@return string
function M.to_native(s)
  return Base.is_windows() and M.to_nt(s) or M.to_kernel(s)
end

function M.nvim_sep()
  if Base.is_kernel() or (Base.is_windows() and vim.opt.shellslash._value == true) then
    return M.kernel_sep()
  end
  return M.nt_sep()
end

function M.name(buffer)
  local path = api.nvim_buf_get_name(buffer)
  return fn.fnamemodify(path, ':t')
end

return M
