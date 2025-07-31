local function get_links()
    local parser = vim.treesitter.get_parser(0, "markdown")
    parser:parse(true)
    local query = vim.treesitter.query.parse("markdown_inline", "(inline_link (link_destination) @dest)")
    local links = {}
    parser:for_each_tree(function(tree, ltree)
        if ltree:lang() == "markdown_inline" then
            for _, dest_node in query:iter_captures(tree:root(), 0) do
                local srow, scol, erow, ecol = dest_node:parent():range()
                table.insert(links, {
                    srow = srow,
                    scol = scol,
                    erow = erow,
                    ecol = ecol,
                    dest = vim.treesitter.get_node_text(dest_node, 0),
                })
            end
        end
    end)
    table.sort(links, function(a, b) return a.srow < b.srow or (a.srow == b.srow and a.scol < b.scol) end)
    return links
end

local function find_link_at_cursor(links)
    local cur = vim.api.nvim_win_get_cursor(0)
    local r, c = cur[1] - 1, cur[2]
    for _, l in ipairs(links) do
        if (r > l.srow or (r == l.srow and c >= l.scol)) and (r < l.erow or (r == l.erow and c < l.ecol)) then
            return l
        end
    end
end

local hl_ns = vim.api.nvim_create_namespace("memo_link_hl")

local function jump_link(forward)
    local links = get_links()
    if #links == 0 then
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]

    local target
    if forward then
        for _, l in ipairs(links) do
            if l.srow > row or (l.srow == row and l.scol > col) then
                target = l
                break
            end
        end
        target = target or links[1]
    else
        for i = #links, 1, -1 do
            local l = links[i]
            if l.srow < row or (l.srow == row and l.scol < col) then
                target = l
                break
            end
        end
        target = target or links[#links]
    end

    vim.api.nvim_win_set_cursor(0, { target.srow + 1, target.scol })

    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, hl_ns, 0, -1)
    vim.api.nvim_buf_set_extmark(bufnr, hl_ns, target.srow, target.scol, {
        end_row = target.erow,
        end_col = target.ecol,
        hl_group = "Search",
    })
end

local function open_link()
    local link = find_link_at_cursor(get_links())
    if not link then
        vim.notify("memo: No markdown link under cursor", vim.log.levels.WARN)
        return
    end

    local current_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    local target_path = vim.fs.normalize(vim.fs.joinpath(current_dir, link.dest))

    vim.cmd.edit(target_path)
end

local function attach_to_buffer(buf, group)
    vim.keymap.set("n", "<CR>", open_link, { buffer = buf, desc = "(memo) follow markdown link" })
    vim.keymap.set("n", "<Tab>", function() jump_link(true) end, { buffer = buf, desc = "(memo) next link" })
    vim.keymap.set("n", "<S-Tab>", function() jump_link(false) end, { buffer = buf, desc = "(memo) prev link" })
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        buffer = buf,
        callback = function()
            local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {})
            if #marks == 0 then
                return
            end
            local cur = vim.api.nvim_win_get_cursor(0)
            if cur[1] - 1 ~= marks[1][2] or cur[2] ~= marks[1][3] then
                vim.api.nvim_buf_clear_namespace(buf, hl_ns, 0, -1)
            end
        end,
    })
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
                attach_to_buffer(ev.buf, group)
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
