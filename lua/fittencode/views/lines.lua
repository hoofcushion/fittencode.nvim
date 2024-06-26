local api = vim.api
local fn = vim.fn

local Base = require('fittencode.base')
local Color = require('fittencode.color')
local Config = require('fittencode.config')
local Log = require('fittencode.log')

local M = {}

---@type integer
local namespace = api.nvim_create_namespace('FittenCode/InlineCompletion')

---@type VirtText?
local committed_virt_text = nil

---@class VirtLine
---@field text string
---@field hl string

---@alias VirtText VirtLine[]

---@param line string
---@return boolean
local function is_whitespace_line(line)
  return string.len(line) == 0 or line:match('^%s*$') ~= nil
end

---@param chars string
local function feedkeys(chars)
  local keys = api.nvim_replace_termcodes(chars, true, false, true)
  api.nvim_feedkeys(keys, 'in', true)
end

local function undojoin()
  feedkeys('<C-g>u')
end

function M.tab()
  feedkeys('<Tab>')
end

---@param suggestions? Suggestions
---@return VirtText|nil
local function generate_virt_text(suggestions)
  if suggestions == nil then
    return
  end
  ---@type VirtText
  local virt_text = {}
  for _, line in ipairs(suggestions) do
    local color = Color.FittenSuggestion
    if is_whitespace_line(line) then
      color = Color.FittenSuggestionWhitespace
    end
    table.insert(virt_text, { { line, color } })
  end
  return virt_text
end

local function set_extmark(virt_text)
  if virt_text == nil or vim.tbl_count(virt_text) == 0 then
    return
  end

  Log.debug('Setting extmark: {}', virt_text)

  local row, col = Base.get_cursor()

  if Config.internal.virtual_text.inline then
    api.nvim_buf_set_extmark(0, namespace, row, col, {
      virt_text = virt_text[1],
      virt_text_pos = 'inline',
      hl_mode = 'combine',
    })
  else
    api.nvim_buf_set_extmark(0, namespace, row, col, {
      virt_text = virt_text[1],
      -- eol will added space to the end of the line
      virt_text_pos = 'overlay',
      hl_mode = 'combine',
    })
  end

  table.remove(virt_text, 1)

  if vim.tbl_count(virt_text) > 0 then
    api.nvim_buf_set_extmark(0, namespace, row, 0, {
      virt_lines = virt_text,
      hl_mode = 'combine',
    })
  end
end

---@param virt_height integer
local function move_to_center_vertical(virt_height)
  if virt_height == 0 then
    return
  end
  local row, _ = Base.get_cursor()
  local relative_row = row - fn.line('w0')
  local height = api.nvim_win_get_height(0)
  local center = math.ceil(height / 2)
  height = height - vim.o.scrolloff
  if relative_row + virt_height > height and math.abs(relative_row + 1 - center) > 2 and row > center then
    vim.cmd([[norm! zz]])
    -- [0, lnum, col, off, curswant]
    local curswant = fn.getcurpos()[5]
    -- 1-based row
    fn.cursor({ row + 1, curswant })
  end
end

---@param row integer
---@param col integer
---@param lines string[]
local function append_text_at_pos(row, col, lines)
  local count = vim.tbl_count(lines)
  for i = 1, count, 1 do
    local line = lines[i]
    local len = string.len(line)
    if i == 1 then
      if len ~= 0 then
        api.nvim_buf_set_text(0, row, col, row, col, { line })
      end
    else
      local max = api.nvim_buf_line_count(0)
      local try_row = row + i - 1
      if try_row >= max then
        api.nvim_buf_set_lines(0, max, max, false, { line })
      else
        if string.len(api.nvim_buf_get_lines(0, try_row, try_row + 1, false)[1]) ~= 0 then
          api.nvim_buf_set_lines(0, try_row, try_row, false, { line })
        else
          api.nvim_buf_set_text(0, try_row, 0, try_row, 0, { line })
        end
      end
    end
  end
end

---@param row integer
---@param col integer
---@param lines string[]
local function move_cursor_to_text_end(row, col, lines)
  local count = vim.tbl_count(lines)
  if count == 1 then
    local first_len = string.len(lines[1])
    if first_len ~= 0 then
      api.nvim_win_set_cursor(0, { row + 1, col + first_len })
    end
  else
    local last_len = string.len(lines[count])
    api.nvim_win_set_cursor(0, { row + count, last_len })
  end
end

---@param fx? function
---@return any
local function format_wrap(fx)
  local fmts = {
    { 'autoindent',    false },
    { 'smartindent',   false },
    { 'formatoptions', '' },
    { 'textwidth',     0 },
  }
  for _, fmt in ipairs(fmts) do
    fmt[3] = vim.bo[fmt[1]]
    vim.bo[fmt[1]] = fmt[2]
  end

  local ret = nil
  if fx then
    ret = fx()
  end

  for _, fmt in ipairs(fmts) do
    vim.bo[fmt[1]] = fmt[3]
  end
  return ret
end

---@param lines string[]
function M.set_text(lines)
  format_wrap(function()
    local row, col = Base.get_cursor()
    undojoin()
    -- Emit events `CursorMovedI` `CursorHoldI`
    append_text_at_pos(row, col, lines)
    move_cursor_to_text_end(row, col, lines)
  end)
end

---@param suggestions? Suggestions
function M.render_virt_text(suggestions)
  committed_virt_text = generate_virt_text(suggestions)
  move_to_center_vertical(vim.tbl_count(committed_virt_text or {}))
  -- api.nvim_command('redraw!')
  api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  set_extmark(committed_virt_text)
end

function M.clear_virt_text()
  M.render_virt_text()
  -- api.nvim_command('redraw!')
end

-- When we edit some complex documents, extmark will not be able to draw correctly.
-- api.nvim_set_decoration_provider(namespace, {
--   on_win = function()
--     api.nvim_buf_clear_namespace(0, namespace, 0, -1)
--     set_extmark(committed_virt_text)
--   end,
-- })

return M
