local parser = require "todo.parser"

local M = {}

--- Wrap virt_lines in a box with optional padding and border highlight.
--- virt_lines format: { { {text, hl}, ... }, ... }
--- padding: number of spaces between text and vertical border
--- border_hl: highlight group for the box borders
local function box_wrap(virt_lines, padding, border_hl)
  padding = padding or 1
  border_hl = border_hl or "Comment"

  -- Compute display width of longest line
  local maxw = 0
  for _, line in ipairs(virt_lines) do
    local w = 0
    for _, cell in ipairs(line) do
      w = w + vim.fn.strdisplaywidth(cell[1])
    end
    if w > maxw then
      maxw = w
    end
  end

  local pad_str = string.rep(" ", padding)

  -- Box characters
  local TL, TR = "╭", "╮"
  local BL, BR = "╰", "╯"
  local H = "─"
  local V = "│"

  -- Top border
  local top = {
    { TL, border_hl },
    { string.rep(H, maxw + 2 * padding), border_hl },
    { TR, border_hl },
  }

  -- Middle lines
  local body = {}
  for _, line in ipairs(virt_lines) do
    local new = { { V, border_hl }, { pad_str, border_hl } }
    local curw = 0
    for _, cell in ipairs(line) do
      table.insert(new, cell)
      curw = curw + vim.fn.strdisplaywidth(cell[1])
    end
    if curw < maxw then
      table.insert(new, { string.rep(" ", maxw - curw), border_hl })
    end
    table.insert(new, { pad_str, border_hl })
    table.insert(new, { V, border_hl })
    table.insert(body, new)
  end

  -- Bottom border
  local bottom = {
    { BL, border_hl },
    { string.rep(H, maxw + 2 * padding), border_hl },
    { BR, border_hl },
  }

  -- Combine everything
  local wrapped = { top }
  vim.list_extend(wrapped, body)
  table.insert(wrapped, bottom)

  return wrapped
end

local function locate_virt_text(bufnr)
  local old_pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  local lnum = vim.fn.search("^##\\s\\+", "W")
  vim.api.nvim_win_set_cursor(0, old_pos)
  return lnum
end

local box = {
  full = "│",
  low = "╵",
  high = "╷",
}

local function update_virt_text(options, bufnr, ns, stats)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local pos = 1
  local name_len = math.max(unpack { #options.open.name, #options.done.name })
  local lines = {}

  for _, h2_state in ipairs { "open", "done" } do
    local line = {}
    table.insert(
      line,
      { string.format("% " .. name_len .. "s  ", options[h2_state].name), "Normal" }
    )

    local total = 0
    for _, v in pairs(stats[h2_state]) do
      total = total + v
    end
    table.insert(line, { string.format("% 3d", total), "Number" })
    table.insert(line, { string.format(" %s ", box.full), "Comment" })

    for _, v in ipairs(options[h2_state].states) do
      table.insert(line, { "  ", "Normal" })
      table.insert(line, { v.icon, "keyword" })
      table.insert(line, { v.name, "Normal" })
      table.insert(line, { ":", "Comment" })
      table.insert(line, { "" .. (stats[h2_state][v.name] or 0), "Number" })
      table.insert(line, { "  ", "Normal" })
    end
    table.insert(lines, line)
  end
  local lno = locate_virt_text(bufnr) - 1
  if lno < 0 then
    lno = 0
  end
  if options.border then
    lines = box_wrap(lines)
  else
    table.insert(lines, { { "", "Normal" } })
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, lno, -1, {
    virt_lines = lines,
    virt_lines_above = true,
  })
end

M.update_summary = function(options, bufnr)
  if not parser.is_formatted(options, bufnr) then
    return
  end

  local tasks = parser.parse_tasks(options, bufnr)
  local stats = { open = {}, done = {} }
  for h2_state, h2_tasks in pairs(tasks) do
    for h3_state, h3_tasks in pairs(h2_tasks) do
      stats[h2_state][h3_state] = vim.tbl_count(h3_tasks)
    end
  end
  if vim.deep_equal(vim.b.tdf_info.stats, stats) then
    return
  end
  vim.b.tdf_info.stats = vim.deepcopy(stats)
  local today = os.date "%Y-%m-%d"
  stats.done["today"] = stats.done[today] or 0
  stats.done[today] = nil
  update_virt_text(options, bufnr, vim.b.tdf_info.ns, stats)
end

M.auto_update_summary = function(options, bufnr)
  if vim.b.tdf_info then
    return
  end

  vim.b.tdf_info = {
    ns = vim.api.nvim_create_namespace "todo",
  }
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    buffer = bufnr,
    callback = function()
      M.update_summary(options, bufnr)
    end,
  })
  M.update_summary(options, bufnr)
end

return M
