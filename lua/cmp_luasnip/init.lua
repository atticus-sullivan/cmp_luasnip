local cmp = require("cmp")
local util = require("vim.lsp.util")

local source = {}

local snip_cache = {}
local doc_cache = {}

local function get_documentation(snip, data)
	local header = (snip.name or "") .. " _ `[" .. data.filetype .. "]`\n"
	local docstring = {"", "```" .. vim.bo.filetype, snip:get_docstring(), "```" }
	local documentation = { header .. '---', (snip.dscr or ""), docstring }
	documentation = util.convert_input_to_markdown_lines(documentation)
	documentation = table.concat(documentation, "\n")
	doc_cache[data.filetype] = doc_cache[data.filetype] or {}
	doc_cache[data.filetype][data.ft_indx] = documentation
	return documentation
end

source.new = function()
	return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
	return "\\%([^[:alnum:][:blank:]]\\|\\w\\+\\)"
end

function source:is_available()
	local ok, _ = pcall(require, "luasnip")
	return ok
end

function source:get_debug_name()
	return "luasnip"
end

function source:complete(params, callback)
	if snip_cache[params.context.filetype] ~= nil then
		callback(snip_cache[params.context.filetype])
		return
	end

	local filetypes = { params.context.filetype, "all" }
	local items = {}

	for i = 1, #filetypes do
		local ft_table = require("luasnip").snippets[filetypes[i]]
		if ft_table then
			for j, snip in ipairs(ft_table) do
        local word = snip.trigger
        if snip.regTrig then
          word = require('cmp_luasnip.regex')(params.context.cursor_line, snip.trigger)
        end
				items[#items + 1] = {
					word = word,
					label = word,
					kind = cmp.lsp.CompletionItemKind.Snippet,
					data = {
						filetype = filetypes[i],
						ft_indx = j,
					},
				}
			end
		end
	end
	snip_cache[params.context.filetype] = items
	callback(items)
end

function source:resolve(completion_item, callback)
	local snip = require("luasnip").snippets[completion_item.data.filetype][completion_item.data.ft_indx]
	local documentation
	if
		doc_cache[completion_item.data.filetype]
		and doc_cache[completion_item.data.filetype][completion_item.data.ft_indx]
	then
		documentation = doc_cache[completion_item.data.filetype][completion_item.data.ft_indx]
	else
		documentation = get_documentation(snip, completion_item.data)
	end
	completion_item.documentation = {
		kind = cmp.lsp.MarkupKind.Markdown,
		value = documentation,
	}
	callback(completion_item)
end

function source:execute(completion_item, callback)
	local snip = require("luasnip").snippets[completion_item.data.filetype][completion_item.data.ft_indx]
	if snip.regTrig then
		-- if trigger is a pattern, expand "pattern" instead of actual snippet.
		snip = snip:get_pattern_expand_helper()
	else
		snip = snip:copy()
	end
	snip:trigger_expand(Luasnip_current_nodes[vim.api.nvim_get_current_buf()])
	callback(completion_item)
end

return source
