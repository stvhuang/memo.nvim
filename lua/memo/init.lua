local function expand_and_resolve_path(path)
    path = vim.fs.normalize(path)
    path = vim.uv.fs_realpath(path)

    return path
end

local function get_link_under_cursor()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local node = vim.treesitter
        .get_parser(0, "markdown")
        :named_node_for_range({ row - 1, col, row - 1, col }, { ignore_injections = false })

    while node do
        if node:type() == "link_destination" then
            return vim.treesitter.get_node_text(node, 0)
        end

        if node:type() == "inline_link" then
            local dest = node:named_child(1)
            return dest and vim.treesitter.get_node_text(dest, 0)
        end

        node = node:parent()
    end
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
            if vim.startswith(buf_path, M.config.path) then
                vim.keymap.set("n", "<CR>", open_link, { buffer = ev.buf, desc = "(memo) follow markdown link" })
            end
        end,
        pattern = "*.md",
    })
end

function M.open()
    vim.cmd.edit(M.config.path .. "/README.md")
end

return M
