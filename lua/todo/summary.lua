local parser = require "todo.parser"

local M = {}

local function update_virt_text(options, bufnr, ns, stats)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for line, h2_state in ipairs { "open", "done" } do
    local parts = {}

    local total = 0
    for _, v in pairs(stats[h2_state]) do
      total = total + v
    end
    table.insert(parts, { string.format("% 3d", total), "Number" })

    for _, v in ipairs(options[h2_state].states) do
      table.insert(parts, { "    ", "Normal" })
      table.insert(parts, { v.icon, "keyword" })
      table.insert(parts, { v.name, "Normal" })
      table.insert(parts, { ":", "Comment" })
      table.insert(parts, { "" .. (stats[h2_state][v.name] or 0), "Number" })
    end
    vim.api.nvim_buf_set_extmark(bufnr, ns, line + 1, -1, {
      virt_text = parts,
      virt_text_pos = "eol",
    })
  end
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
end

return M
