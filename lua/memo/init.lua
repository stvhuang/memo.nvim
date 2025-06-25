local M = {}

M.config = { path = nil }

local function expand_and_resolve_path(path)
    return vim.uv.fs_realpath(vim.fs.normalize(path))
end

local function get_link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    local start_pos = 1
    while true do
        local link_start, link_end, _, path = line:find("%[([^%]]*)%]%(([^%)]+)%)", start_pos)

        if not link_start then
            break
        end

        if col >= link_start and col <= link_end then
            return path
        end

        start_pos = link_end + 1
    end

    return nil
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

function M.setup(opts)
    M.config = vim.tbl_extend("force", M.config, opts or {})
    if M.config.path == nil then
        vim.notify("memo: path is required in config", vim.log.levels.ERROR)
        return
    end
    M.config.path = expand_and_resolve_path(M.config.path)

    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.md",
        callback = function(ev)
            local buf_path = expand_and_resolve_path(vim.api.nvim_buf_get_name(ev.buf))
            if buf_path:sub(1, #M.config.path) == M.config.path then
                vim.keymap.set("n", "<CR>", function()
                    open_link()
                end, { buffer = ev.buf, desc = "(memo) follow markdown link" })
            end
        end,
    })
end

function M.open()
    vim.cmd.edit(M.config.path .. "/README.md")
end

return M
