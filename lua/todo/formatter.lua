local parser = require "todo.parser"
local summary = require "todo.summary"
local vts = vim.treesitter

local M = {}

local function compare_line_lists(lines1, lines2)
  if #lines1 ~= #lines2 then
    return false
  end
  for i, line in ipairs(lines1) do
    if line ~= lines2[i] then
      return false
    end
  end
  return true
end

local function build_h3_section(lines, h3_state, h3_tasks, bufnr)
  vim.list_extend(lines, { "", "### " .. h3_state })
  if not h3_tasks then
    return lines
  end
  vim.list_extend(lines, { "" })
  for _, task in ipairs(h3_tasks) do
    local text = vts.get_node_text(task, bufnr)
    for line in text:gmatch "[^\r\n]+" do
      table.insert(lines, line)
    end
  end
  return lines
end

local function build_h2_section(name, h2_tasks, h3_states, bufnr)
  local lines = { "", "## " .. name }

  for _, h3_state in ipairs(h3_states) do
    build_h3_section(lines, h3_state, h2_tasks[h3_state], bufnr)
  end
  return lines
end

M.format_as_lines = function(options, bufnr)
  local lines = { "# " .. (parser.parse_title(bufnr) or options.title) }

  local tasks = parser.parse_tasks(options, bufnr)
  local h2_state = "open"
  local h3_states = {}
  for _, v in pairs(options.open.states) do
    table.insert(h3_states, v["name"])
  end
  local h2_lines = build_h2_section(options[h2_state].name, tasks[h2_state], h3_states, bufnr)
  vim.list_extend(lines, h2_lines)
  h2_state = "done"
  h3_states = vim.tbl_keys(tasks[h2_state])
  table.sort(h3_states, function(a, b)
    return a > b
  end)
  h2_lines = build_h2_section(options[h2_state].name, tasks[h2_state], h3_states, bufnr)
  vim.list_extend(lines, h2_lines)
  vim.list_extend(lines, {"", options.footnote})
  return lines
end

M.format = function(options)
  if vim.bo.filetype ~= "markdown" then
    vim.notify("Not a markdown file", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = M.format_as_lines(options, bufnr)
  local lines2 = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if not compare_line_lists(lines, lines2) then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  summary.auto_update_summary(options, bufnr)
end

return M
