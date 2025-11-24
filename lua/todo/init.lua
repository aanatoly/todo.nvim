local parser = require "todo.parser"
local formatter = require "todo.formatter"
local summary = require "todo.summary"

local M = {}

M.default_options = {
  filetype = "markdown",
  title = "Personal Todo List",
  open = {
    name = "Open",
    icon = " ",
    default = "todo",
    states = {
      { name = "wip", icon = " " },
      { name = "todo", icon = " " },
      { name = "soon", icon = " " },
    },
  },
  done = {
    name = "Done",
    icon = " ",
    states = {
      -- replaced by current date
      { name = "today", icon = " " },
    },
  },
}

M.options = {}

M.setup = function(opts)
  M.options = vim.tbl_deep_extend("force", M.default_options, opts or {})

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(args)
      local bufnr = args.buf
      if parser.is_formatted(M.options, bufnr) then
        summary.auto_update_summary(M.options, bufnr)
      end
    end,
  })

  vim.api.nvim_create_user_command("TodoFormat", function()
    formatter.format(M.options)
  end, {})
end

return M
