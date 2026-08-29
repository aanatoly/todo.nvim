local parser = require "todo.parser"
local formatter = require "todo.formatter"
local summary = require "todo.summary"

local M = {}

local default_opts = {
  filetype = "markdown",
  title = "Personal Todo List",
  footnote = "> [!HINT] formatted by todo.nvim",
  open = {
    name = "Open",
    icon = " ",
    default = "Todo",
    states = {
      { name = "WIP", icon = " " },
      { name = "Todo", icon = " " },
      { name = "Soon", icon = " " },
    },
  },
  done = {
    name = "Done",
    icon = " ",
    states = {
      { name = "today", icon = " " },
    },
  },
}

M.setup = function(user_opts)
  local opts = vim.tbl_deep_extend("force", default_opts, user_opts or {})
  if user_opts and user_opts.open and user_opts.open.states then
    opts.open.states = user_opts.open.states
  end

  local augroup = vim.api.nvim_create_augroup("TodoPlugin", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "markdown",
    callback = function(args)
      local bufnr = args.buf
      if parser.is_formatted(opts, bufnr) then
        summary.auto_update_summary(opts, bufnr)
      end
    end,
  })

  vim.api.nvim_create_user_command("TodoFormat", function()
    formatter.format(opts)
  end, {})
end

return M
