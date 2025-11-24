local tsc = require "nvim-treesitter.compat"
local vts = vim.treesitter

local M = {}

M.is_formatted = function(options, bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 5, false)
  if #lines < 5 then
    return false
  end
  return lines[1]:match "^# "
    and lines[2] == ""
    and lines[3] == options.open.name
    and lines[4] == options.done.name
    and lines[5] == ""
end

local function iter_tasks(bufnr, root, task_type, cb)
  local query = [[
(section
  (atx_heading
      [
        (atx_h1_marker)
        (atx_h2_marker)
        (atx_h3_marker)
        (atx_h4_marker)
        (atx_h5_marker)
        (atx_h6_marker)
      ] @hdr_marker
      heading_content:(inline) @hdr)
  (list
    (list_item
        (task_list_marker_%s)) @li))
]]
  query = string.format(query, task_type)
  query = tsc.parse_query("markdown", query)
  for _, match, _ in query:iter_matches(root, bufnr, 0, -1) do
    local hdr_t = vts.get_node_text(match[2][1], 0)
    cb(hdr_t, match[3][1])
  end
end

local function fix_task_states(tasks, is_valid_state, default_state)
  local tmp = tasks[default_state] or {}
  for _, k in ipairs(vim.tbl_keys(tasks)) do
    if not is_valid_state(k) then
      vim.list_extend(tmp, tasks[k])
      tasks[k] = nil
    end
  end
  if #tmp > 0 then
    tasks[default_state] = tmp
  end
end

local function fix_open_task_states(tasks, options)
  local function is_valid_state(state)
    for _, v in ipairs(options.open.states) do
      if v.name == state then
        return true
      end
    end
    return false
  end
  local default_state = options.open.default
  fix_task_states(tasks, is_valid_state, default_state)
end

local function fix_done_task_states(tasks, _)
  local function is_valid_state(state)
    return state:match "%d%d%d%d%-%d%d%-%d%d"
  end
  local default_state = tostring(os.date "%Y-%m-%d")
  fix_task_states(tasks, is_valid_state, default_state)
end

local function get_root_node(bufnr, filetype)
  local parser = vts.get_parser(bufnr, filetype)
  if not parser then
    return
  end
  local tree = parser:parse()[1]
  local root = tree:root()
  return root
end

M.parse_tasks = function(options, bufnr)
  local tasks = { open = {}, done = {} }
  local root = get_root_node(bufnr, "markdown")
  if root == nil then
    vim.notify("can't get markdown parser for buffer " .. bufnr)
    return tasks
  end

  local function add_task(tmp_tasks, hdr_t, li)
    if tmp_tasks[hdr_t] == nil then
      tmp_tasks[hdr_t] = {}
    end
    table.insert(tmp_tasks[hdr_t], li)
  end

  iter_tasks(bufnr, root, "unchecked", function(hdr_text, li)
    add_task(tasks["open"], hdr_text, li)
  end)
  fix_open_task_states(tasks["open"], options)

  iter_tasks(bufnr, root, "checked", function(hdr_text, li)
    add_task(tasks["done"], hdr_text, li)
  end)
  fix_done_task_states(tasks["done"], options)

  return tasks
end

return M
