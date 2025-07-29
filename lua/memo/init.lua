local function get_link_under_cursor()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local node = vim.treesitter.get_parser(0, "markdown"):named_node_for_range({ row - 1, col, row - 1, col }, { ignore_injections = false })

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
    local target_path = vim.fs.normalize(vim.fs.joinpath(current_dir, link))

    vim.cmd.edit(target_path)
end

local M = {
    config = {
        dir = nil,
        entry_point = "README.md",
    },
}

function M.setup(opts)
    M.config = vim.tbl_extend("force", M.config, opts or {})
    if M.config.dir == nil then
        vim.notify("memo: `dir` is required in config", vim.log.levels.ERROR)
        return
    end
    local resolved = vim.uv.fs_realpath(vim.fs.normalize(M.config.dir))
    if resolved == nil then
        vim.notify("memo: `dir` does not exist: " .. M.config.dir, vim.log.levels.ERROR)
        return
    end
    M.config.dir = resolved
    local prefix = M.config.dir .. "/"

    local group = vim.api.nvim_create_augroup("memo", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "markdown",
        callback = function(ev)
            local name = vim.api.nvim_buf_get_name(ev.buf)
            if name == "" then
                return
            end

            local normalized = vim.fs.normalize(name)
            local buf_path = vim.uv.fs_realpath(normalized) or normalized
            if vim.startswith(buf_path, prefix) then
                vim.keymap.set("n", "<CR>", open_link, { buffer = ev.buf, desc = "(memo) follow markdown link" })
            end
        end,
    })
end

function M.open()
    if M.config.dir == nil then
        vim.notify("memo: not configured; call setup() first", vim.log.levels.ERROR)
        return
    end
    vim.cmd.edit(vim.fs.joinpath(M.config.dir, M.config.entry_point))
end

return M
