local parser = require "todo.parser"
local formatter = require "todo.formatter"
local summary = require "todo.summary"
local vts = vim.treesitter

local M = {}

M.compare_line_lists = function(lines1, lines2)
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

local function build_h3_section(lines, h3_state, h3_tasks)
  vim.list_extend(lines, { "", "### " .. h3_state })
  if not h3_tasks then
    return lines
  end
  vim.list_extend(lines, { "" })
  for _, task in ipairs(h3_tasks) do
    local text = vts.get_node_text(task, 0)
    for line in text:gmatch "[^\r\n]+" do
      table.insert(lines, line)
    end
  end
  return lines
end

local function build_h2_section(name, h2_tasks, h3_states)
  local lines = { "", "## " .. name }

  for _, h3_state in ipairs(h3_states) do
    build_h3_section(lines, h3_state, h2_tasks[h3_state])
  end
  return lines
end

M.format_as_lines = function(options, bufnr)
  -- ensure h1 header, it makes parsing simple
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
  if not (#lines == 1 and lines[1]:match "^# ") then
    lines = { "# " .. options.title }
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, lines)
  end
  vim.list_extend(lines, { "", options.open.name, options.done.name })

  local tasks = parser.parse_tasks(options, bufnr)
  vim.b.tdf_tasks = tasks
  local h2_state = "open"
  local h3_states = {}
  for _, v in pairs(options.open.states) do
    table.insert(h3_states, v["name"])
  end
  vim.list_extend(lines, build_h2_section(options[h2_state].name, tasks[h2_state], h3_states))
  h2_state = "done"
  h3_states = vim.tbl_keys(tasks[h2_state])
  table.sort(h3_states, function(a, b)
    return a > b
  end)
  vim.list_extend(lines, build_h2_section(options[h2_state].name, tasks[h2_state], h3_states))
  return lines
end

function M.format(options)
  if vim.bo.filetype ~= "markdown" then
    vim.notify("Not a markdown file", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = M.format_as_lines(options, bufnr)
  local lines2 = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if not M.compare_line_lists(lines, lines2) then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  summary.auto_update_summary(options, bufnr)
end

return M
