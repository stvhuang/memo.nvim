local function expand_and_resolve_path(path)
    path = vim.fs.normalize(path)
    path = vim.uv.fs_realpath(path)

    return path
end

local function get_link_under_cursor()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local result = nil

    vim.treesitter.get_parser(0, "markdown"):for_each_tree(function(tree, ltree)
        if result or ltree:lang() ~= "markdown_inline" then
            return
        end

        local node = tree:root():named_descendant_for_range(row - 1, col, row - 1, col)
        while node do
            if node:type() == "link_destination" then
                result = vim.treesitter.get_node_text(node, 0)
                return
            end

            node = node:parent()
        end
    end)

    return result
end

local function open_link()
    local link = get_link_under_cursor()
    if not link then
        vim.notify("memo: No markdown link under cursor", vim.log.levels.WARN)
        return
    end

    local current_file = vim.api.nvim_buf_get_name(0)
    local current_dir = vim.fs.dirname(current_file)
    local target_path = current_dir .. "/" .. link
    target_path = expand_and_resolve_path(target_path)

    vim.cmd.edit(target_path)
end

local M = {
    config = {
        path = nil,
    },
}

function M.setup(opts)
    M.config = vim.tbl_extend("force", M.config, opts or {})
    if M.config.path == nil then
        vim.notify("memo: path is required in config", vim.log.levels.ERROR)
        return
    end
    M.config.path = expand_and_resolve_path(M.config.path)

    vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(ev)
            local buf_path = expand_and_resolve_path(vim.api.nvim_buf_get_name(ev.buf))
            if buf_path:sub(1, #M.config.path) == M.config.path then
                vim.keymap.set("n", "<CR>", function()
                    open_link()
                end, { buffer = ev.buf, desc = "(memo) follow markdown link" })
            end
        end,
        pattern = "*.md",
    })
end

function M.open()
    vim.cmd.edit(M.config.path .. "/README.md")
end

return M
