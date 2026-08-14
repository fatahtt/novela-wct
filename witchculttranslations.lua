-- Witch Cult Translations source for NoveLA
-- Based on the public LNReader WCT parser and adapted to NoveLA's Lua source API.
id       = "witchculttranslations"
name     = "Witch Cult Translations"
version  = "1.0.0"
baseUrl  = "https://witchculttranslation.com"
language = "en"
icon     = "https://witchculttranslation.com/wp-content/uploads/2020/04/cropped-WCT-logo-1.png"

local function absUrl(href)
  if not href or href == "" then return "" end
  if string_starts_with(href, "http://") or string_starts_with(href, "https://") then
    return href
  end
  if string_starts_with(href, "//") then return "https:" .. href end
  return url_resolve(baseUrl, href)
end

local function isWctUrl(url)
  return url ~= "" and regex_match(
    url,
    "^https?://(?:www%.)?witchculttranslation%.com/"
  ) ~= nil
end

local function applyStandardContentTransforms(text)
  if not text or text == "" then return "" end
  text = string_normalize(text)
  local domain = "witchculttranslation.com"
  text = regex_replace(text, "(?i)" .. domain .. ".*?\\n", "")
  text = regex_replace(
    text,
    "(?i)\\A[\\s\\p{Z}\\uFEFF]*((Chapter\\s+\\d+)[^\\n\\r]*[\\n\\r\\s]*)+",
    ""
  )
  text = string_trim(text)
  return text
end

-- WCT hosts one main Re:Zero web novel rather than a normal multi-novel catalog.
function getCatalogList(index)
  if index > 0 then
    return { items = {}, hasNext = false }
  end

  local r = http_get(baseUrl .. "/table-of-content/")
  if not r.success then
    return { items = {}, hasNext = false }
  end

  local cover = html_attr(r.body, ".entry-content h1 img", "src")
  if cover == "" then
    cover = html_attr(r.body, ".entry-content img", "src")
  end

  return {
    items = {{
      title = "Re:Zero kara Hajimeru Isekai Seikatsu",
      url = baseUrl .. "/table-of-content/",
      cover = absUrl(cover)
    }},
    hasNext = false
  }
end

function getCatalogSearch(index, query)
  if index > 0 then
    return { items = {}, hasNext = false }
  end

  local q = string_clean(query):lower()
  local title = "Re:Zero kara Hajimeru Isekai Seikatsu"

  if q == "" or title:lower():find(q, 1, true) then
    return getCatalogList(0)
  end

  return { items = {}, hasNext = false }
end

function getBookTitle(bookUrl)
  return "Re:Zero kara Hajimeru Isekai Seikatsu"
end

function getBookCoverImageUrl(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end

  local cover = html_attr(r.body, ".entry-content h1 img", "src")
  if cover == "" then
    cover = html_attr(r.body, ".entry-content img", "src")
  end

  return cover ~= "" and absUrl(cover) or nil
end

function getBookDescription(bookUrl)
  return "Fan translation of the Re:Zero web novel by Witch Cult Translations. The table of contents currently links to translated material from Arc 1 through Arc 10, including chapters hosted by WCT and some externally credited translations."
end

function getChapterList(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then
    log_error("Witch Cult Translations: failed to load table of contents")
    return {}
  end

  local chapters = {}
  local seen = {}

  -- The WCT table of contents keeps chapter links inside .entry-content.
  -- Only links hosted on witchculttranslation.com are retained.
  for _, a in ipairs(html_select(r.body, ".entry-content li a[href]")) do
    local url = absUrl(a.href)
    local title = string_clean(a.text)

    if title ~= "" and isWctUrl(url) and not seen[url] then
      -- Ignore navigation links accidentally appearing inside the content.
      if not regex_match(url, "/table-of-content/?$") then
        seen[url] = true
        table.insert(chapters, {
          title = title,
          url = url
        })
      end
    end
  end

  return chapters
end

function getChapterListHash(bookUrl)
  local r = http_get(bookUrl)
  if not r.success then return nil end

  -- A hash-like value based on the current TOC size and latest chapter URL.
  local links = html_select(r.body, ".entry-content li a[href]")
  local count = 0
  local last = ""

  for _, a in ipairs(links) do
    local url = absUrl(a.href)
    if isWctUrl(url) and not regex_match(url, "/table-of-content/?$") then
      count = count + 1
      last = url
    end
  end

  return tostring(count) .. ":" .. last
end

function getChapterText(html, url)
  -- Keep the article's readable text while stripping WordPress/navigation junk.
  local cleaned = html_remove(
    html,
    "script",
    "style",
    "nav",
    "header",
    "footer",
    ".sharedaddy",
    ".jp-relatedposts",
    "#jp-post-flair",
    "#patreon-snippet",
    ".post-navigation",
    ".comments-area"
  )

  local content = html_select_first(cleaned, ".entry-content")
  if not content then return "" end

  return applyStandardContentTransforms(html_text(content.html))
end
