---@tag uparis-header.header

---@brief [[
---
---This module manages the header.
---
---@brief ]]

local M = {}
local config = require "uparis-header.config"
-- local git = require "uparis-header.utils.git"

---Get username.
---@return string|nil
function M.user()
  -- return vim.g.user or (config.opts.git.enabled and git.user()) or config.opts.user
  -- not using vim.g.user because it conflicts with 42header plugin
  return config.opts.user
end

---Get email.
---@return string|nil
function M.email()
  -- return vim.g.mail or (config.opts.git.enabled and git.email()) or config.opts.mail
  -- not using vim.g.email because it conflicts with 42header plugin
  return config.opts.mail
end

---Get left and right comment symbols from the buffer.
---@return string, string
function M.comment_symbols()
  local str = vim.api.nvim_buf_get_option(0, "commentstring")

  if vim.tbl_contains({ "c", "cc", "cpp", "cxx", "tpp", "h" }, vim.bo.filetype) then
    str = "/* %s */"
  elseif vim.bo.filetype == "openscad" then
    str = "// %s #"
  end

  -- Checks the buffer has a valid commentstring.
  if str:find "%%s" then
    local left, right = str:match "(.*)%%s(.*)"

    if right == "" then
      right = left
    end

    return vim.trim(left), vim.trim(right)
  end

  return "#", "#" -- Default comment symbols.
end

---Generate a formatted text line for the header.
---@param text string: The text to include in the line.
---@param ascii string: The ASCII art for the line.
---@return string: The formatted header line.
function M.gen_line(text, ascii)
  local max_length = config.opts.length - config.opts.margin * 2 - #ascii

  text = (text):sub(1, max_length)

  local left, right = M.comment_symbols()
  local left_margin = (" "):rep(config.opts.margin - #left)
  local right_margin = (" "):rep(config.opts.margin - #right)
  local spaces = (" "):rep(max_length - #text)

  return left .. left_margin .. text .. spaces .. ascii .. right_margin .. right
end

---Generate a complete header.
---@return table: A table ontaining all lines of header.
function M.gen_header()
  local ascii = config.opts.asciiart or {}
  local left, right = M.comment_symbols()
  local fill_line = left .. " " .. string.rep("*", config.opts.length - #left - #right - 2) .. " " .. right
  local empty_line = M.gen_line("", "")
  local date = os.date "%Y/%m/%d %H:%M:%S"

  local header = {
    fill_line,
    empty_line,
  }

  local text_map = {
    [1] = "",
    [2] = vim.fn.expand "%:t",
    [3] = "",
    [4] = "By: " .. M.user(),
    [5] = "    <" .. M.email() ,
    [6] = "",
    [7] = "",
    [8] = "",
    [9] = "",
    [10] = "Created: " .. date .. " by " .. M.user(),
    [11] = "Updated: " .. date .. " by " .. M.user(),
  }

  local max_idx = math.max(#ascii, #text_map)

  for idx = 1, max_idx do
    header[#header + 1] = M.gen_line(text_map[idx] or "", ascii[idx] or "")
  end

  header[#header + 1] = empty_line
  header[#header + 1] = fill_line

  return header
end

---Checks if there is a valid header in the current buffer.
---@param header table: The header to compare with the contents of the existing buffer.
---@return boolean: `true` if the header exists, `false` otherwise.
function M.has_header(header)
  if vim.api.nvim_buf_line_count(0) < #header then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, #header, false)
  if #lines < #header then
    return false
  end

  -- Immutable lines that are used for checking.
  local checks = { 1, 2, 3, #header - 1, #header }
  for _, v in pairs(checks) do
    if header[v] ~= lines[v] then
      return false
    end
  end

  return true
end

---Insert a header into the current buffer.
---@param header table: The header to insert.
function M.insert_header(header)
  if not vim.api.nvim_buf_get_option(0, "modifiable") then
    vim.notify("The current buffer cannot be modified.", vim.log.levels.WARN, { title = "UParis Header" })
    return
  end
  -- If the first line is not empty, the blank line will be added after the header.
  if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= "" then
    table.insert(header, "")
  end

  vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

---Update an existing header in the current buffer.
---@param header table: Header to override the current one.
function M.update_header(header)
  local immutable = { 6, 8 }

  -- Copies immutable lines from existing header to updated header.
  for _, value in ipairs(immutable) do
    if header[value] then
      header[value] = vim.api.nvim_buf_get_lines(0, value - 1, value, false)[1]
    end
  end

  vim.api.nvim_buf_set_lines(0, 0, #header, false, header)
end

---Inserts or updates the header in the current buffer.
function M.stdheader()
  local header = M.gen_header()
  if not M.has_header(header) then
    M.insert_header(header)
  else
    M.update_header(header)
  end
end

return M
