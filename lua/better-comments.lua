--Taken and modified from: https://github.com/Djancyp/better-comments.nvim/blob/main/lua/better-comment/init.lua
local M = {}

---@class (exact) CommentHighlight
---@field fg string
---@field bg string
---@field bold boolean?
---@field match string?
---@field virtual_text string?

---These strings are passed to string.match!
---@alias BetterComments.tags CommentHighlight[]

local api = vim.api
local cmd = vim.api.nvim_create_autocmd
local treesitter = vim.treesitter
local opts = {
  ---@type BetterComments.tags
  tags = {
    {
      match = "TODO",
      fg = "white",
      bg = "#0a7aca",
      bold = true,
      virtual_text = "",
    },
    {
      match = "FIX|FIXME",
      fg = "white",
      bg = "#f44747",
      bold = true,
      virtual_text = "",
    },
    {
      match = "WARNING",
      fg = "#FFA500",
      bg = "",
      bold = false,
      virtual_text = "",
    },
    {
      match = "!",
      fg = "#f44747",
      bg = "",
      bold = true,
      virtual_text = "",
    },
  },
}

local function get_root(bufnr, filetype)
  local parser = vim.treesitter.get_parser(bufnr, filetype, {})
  local tree = parser:parse()[1]
  return tree:root()
end

---@param list BetterComments.tags
local function create_hl(list)
  for id, hl in pairs(list) do
    vim.api.nvim_set_hl(0, ("BetterComments%s"):format(id), {
      fg = hl.fg,
      bg = hl.bg,
      bold = hl.bold,
    })
  end
end

local function highlight(id, comment, hl_id, hl, buffer_num)
  if not string.match(comment.text, "^--%s*(" .. hl.match .. ")%s") then return end

  if hl.virtual_text and hl.virtual_text ~= "" then
    local ns_id = vim.api.nvim_create_namespace(hl.match)
    local v_opts = {
      id = id,
      virt_text = { { hl.virtual_text, "" } },
      virt_text_pos = "overlay",
      virt_text_win_col = comment.finish + 2,
    }
    api.nvim_buf_set_extmark(buffer_num, ns_id, comment.line, comment.line, v_opts)
  end

  api.nvim_buf_add_highlight(
    buffer_num,
    0,
    ("BetterComments%s"):format(hl_id),
    comment.line,
    comment.col_start,
    comment.finish
  )
end

M.setup = function(config)
  config = config or {}
  config.tags = config.tags or opts.tags ---@type BetterComments.tags

  local augroup = vim.api.nvim_create_augroup("better-comments", { clear = true })
  cmd({ "BufWinEnter", "BufFilePost", "BufWritePost" }, {
    group = augroup,
    callback = function()
      local buffer_num = api.nvim_get_current_buf()
      local ft = api.nvim_get_option_value and api.nvim_get_option_value("filetype", { buf = buffer_num })
        or api.nvim_buf_get_option(buffer_num, "filetype")
      local ft = api.nvim_buf_get_option(buffer_num, "filetype")
      local success = pcall(treesitter.query.parse, ft, [[(comment) @all]])
      if not success then return end
      local comments_tree = treesitter.query.parse(ft, [[(comment) @all]])

      -- FIX: Check if file has treesitter
      local root = get_root(buffer_num, ft)
      local comments = {}
      for _, node in comments_tree:iter_captures(root, buffer_num, 0, -1) do
        local range = { node:range() }
        table.insert(comments, {
          line = range[1],
          col_start = range[2],
          finish = range[4],
          text = vim.treesitter.get_node_text(node, buffer_num),
        })
      end

      if comments == {} then return end
      create_hl(config.tags)

      for id, comment in ipairs(comments) do
        for hl_id, hl in ipairs(config.tags) do
          highlight(id, comment, hl_id, hl, buffer_num)
        end
      end
    end,
  })
end

return M
