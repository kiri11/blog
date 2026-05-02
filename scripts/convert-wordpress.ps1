param(
    [string]$ExportPath = "kirill039sblog.WordPress.2026-04-31.xml",
    [string]$SitePath = "kiri11",
    [switch]$DownloadMedia
)

$ErrorActionPreference = "Stop"

function Get-ChildText {
    param($Node, [string]$Name, $Namespaces)
    $child = $Node.SelectSingleNode($Name, $Namespaces)
    if ($null -eq $child) { return "" }
    return $child.InnerText
}

function Escape-TomlString {
    param([string]$Value)
    if ($null -eq $Value) { $Value = "" }
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

function Escape-Html {
    param([string]$Value)
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Normalize-FileName {
    param([string]$Value, [string]$Fallback)
    if ([string]::IsNullOrWhiteSpace($Value)) { $Value = $Fallback }
    $name = $Value.ToLowerInvariant() -replace '[^a-z0-9_-]+', '-'
    $name = $name.Trim('-')
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $Fallback }
    return $name
}

function Get-Terms {
    param($Item, [string]$Domain)
    $terms = New-Object System.Collections.Generic.List[string]
    foreach ($category in $Item.SelectNodes("category")) {
        if ($category.GetAttribute("domain") -eq $Domain) {
            $text = $category.InnerText.Trim()
            if (-not [string]::IsNullOrWhiteSpace($text) -and -not $terms.Contains($text)) {
                $terms.Add($text)
            }
        }
    }
    return @($terms)
}

function Format-TomlArray {
    param([string[]]$Values)
    if ($null -eq $Values -or $Values.Count -eq 0) { return "[]" }
    return "[" + (($Values | ForEach-Object { Escape-TomlString $_ }) -join ", ") + "]"
}

function Format-ZolaDate {
    param([string]$Value)
    if ($Value -match '^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})$') {
        return "$($Matches[1])T$($Matches[2])"
    }
    return $Value
}

function Get-PlainTextPreview {
    param([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return "" }

    $withoutComments = [regex]::Replace($Html, '<section class="historical-comments"[\s\S]*$', '', 'IgnoreCase')
    $paragraphMatches = [regex]::Matches($withoutComments, '<p\b[^>]*>([\s\S]*?)</p>', 'IgnoreCase')
    foreach ($match in $paragraphMatches) {
        $candidate = [System.Net.WebUtility]::HtmlDecode(([regex]::Replace($match.Groups[1].Value, '<[^>]+>', ' ') -replace '\s+', ' ').Trim())
        if ($candidate.Length -gt 0) { return Limit-PreviewText $candidate }
    }

    $blocks = [regex]::Split($withoutComments.Trim(), "(?:\r?\n){2,}")
    foreach ($block in $blocks) {
        $candidate = [System.Net.WebUtility]::HtmlDecode(([regex]::Replace($block, '<[^>]+>', ' ') -replace '\s+', ' ').Trim())
        if ($candidate.Length -gt 0) { return Limit-PreviewText $candidate }
    }

    $text = [System.Net.WebUtility]::HtmlDecode(([regex]::Replace($withoutComments, '<[^>]+>', ' ') -replace '\s+', ' ').Trim())
    return Limit-PreviewText $text
}

function Limit-PreviewText {
    param([string]$Text)
    if ($Text.Length -le 420) { return $Text }

    $cut = $Text.LastIndexOf(" ", [Math]::Min(420, $Text.Length - 1))
    if ($cut -lt 180) { $cut = 420 }
    return $Text.Substring(0, $cut).TrimEnd() + "..."
}

function Get-LeadingImage {
    param([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return $null }

    $content = $Html.TrimStart()
    $leadingPattern = '^(?:\s|&nbsp;|<p>\s*</p>)*(?:<p>\s*)?(?:<a\b[^>]*>\s*)?(?:<div\b[^>]*>\s*)?<img\b[^>]*\bsrc=["'']([^"'']+)["''][^>]*>(?:\s*</a>)?(?:\s*</div>)?(?:\s*</p>)?'
    $match = [regex]::Match($content, $leadingPattern, 'IgnoreCase')
    if (-not $match.Success) { return $null }

    return [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
}

function Render-CommentTree {
    param(
        $Comments,
        [int]$ParentId,
        [int]$Depth
    )

    $html = New-Object System.Text.StringBuilder
    $children = @($Comments | Where-Object { $_.ParentId -eq $ParentId } | Sort-Object Date, Id)
    foreach ($comment in $children) {
        $author = Escape-Html $comment.Author
        $date = Escape-Html $comment.Date
        $url = $comment.Url
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            $safeUrl = Escape-Html $url
            $authorHtml = "<a class=""comment-author"" href=""$safeUrl"" rel=""nofollow noopener"">$author</a>"
        } else {
            $authorHtml = "<span class=""comment-author"">$author</span>"
        }

        [void]$html.AppendLine("<article class=""comment depth-$Depth"" id=""comment-$($comment.Id)"">")
        [void]$html.AppendLine("<div class=""comment-meta"">$authorHtml <time datetime=""$date"">$date</time></div>")
        [void]$html.AppendLine("<div class=""comment-content"">")
        [void]$html.AppendLine($comment.Content)
        [void]$html.AppendLine("</div>")
        $childHtml = [string](Render-CommentTree -Comments $Comments -ParentId $comment.Id -Depth ([Math]::Min($Depth + 1, 5)))
        [void]$html.Append($childHtml)
        [void]$html.AppendLine("</article>")
    }
    return $html.ToString()
}

function Get-MediaPathFromUrl {
    param([string]$Url)
    if ($Url -notmatch '^https?://kiri11\.ru/([^"''<>\s)]+?\.(?:jpg|jpeg|png|gif|webp|svg|pdf|zip|rar|7z|mp3|mp4|mov|avi|wmv))(\?[^"''<>\s)]*)?$') {
        return $null
    }
    $uri = [System.Uri]$Url
    $relative = [System.Uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/'))
    return ($relative -replace '[\\:*?"<>|]', '-')
}

function Convert-MediaUrls {
    param(
        [string]$Html,
        [string]$StaticPath,
        [switch]$DownloadMedia
    )

    $pattern = 'https?://kiri11\.ru/[^"''<>\s)]+?\.(?:jpg|jpeg|png|gif|webp|svg|pdf|zip|rar|7z|mp3|mp4|mov|avi|wmv)(?:\?[^"''<>\s)]*)?'
    return [regex]::Replace($Html, $pattern, {
        param($Match)
        $url = $Match.Value
        $mediaPath = Get-MediaPathFromUrl $url
        if ($null -eq $mediaPath) { return $url }

        $target = Join-Path (Join-Path $StaticPath "assets") $mediaPath
        $targetDir = Split-Path $target -Parent
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

        if ($DownloadMedia -and -not (Test-Path $target)) {
            try {
                Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing -MaximumRedirection 5 -ErrorAction Stop | Out-Null
            } catch {
                Write-Warning "Could not download $url : $($_.Exception.Message)"
            }
        }

        return "/assets/$($mediaPath -replace '\\', '/')"
    })
}

function Get-CodeLanguage {
    param([string]$Attributes)

    if ($Attributes -match '(?:^|\s)(?:lang|language)-([A-Za-z0-9_+#-]+)(?:\s|$|")') {
        return Normalize-CodeLanguage $Matches[1]
    }
    if ($Attributes -match 'brush:\s*([A-Za-z0-9_+#-]+)') {
        return Normalize-CodeLanguage $Matches[1]
    }
    return "text"
}

function Normalize-CodeLanguage {
    param([string]$Language)

    $value = $Language.ToLowerInvariant()
    switch ($value) {
        "c++" { return "cpp" }
        "cplusplus" { return "cpp" }
        "cxx" { return "cpp" }
        "js" { return "javascript" }
        "py" { return "python" }
        "ps1" { return "powershell" }
        "sh" { return "bash" }
        default { return $value }
    }
}

function Convert-CodeBlocks {
    param([string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) { return $Html }

    return [regex]::Replace($Html, '<pre\b([^>]*)>([\s\S]*?)</pre>', {
        param($Match)

        $attributes = $Match.Groups[1].Value
        $code = [System.Net.WebUtility]::HtmlDecode($Match.Groups[2].Value)
        $code = [regex]::Replace($code, '</?code\b[^>]*>', '', 'IgnoreCase')
        $code = $code.Trim("`r", "`n")
        $language = Get-CodeLanguage $attributes
        $fence = if ($code.Contains('```')) { '~~~' } else { '```' }
        return "`n$fence$language`n$code`n$fence`n"
    }, 'IgnoreCase')
}

$resolvedExport = Resolve-Path $ExportPath
$resolvedSite = Resolve-Path $SitePath
$postsPath = Join-Path $resolvedSite "content\posts"
$staticPath = Join-Path $resolvedSite "static"
New-Item -ItemType Directory -Force -Path $postsPath | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $staticPath "assets") | Out-Null

$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.Load($resolvedExport)

$namespaces = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
$namespaces.AddNamespace("wp", "http://wordpress.org/export/1.2/")
$namespaces.AddNamespace("content", "http://purl.org/rss/1.0/modules/content/")
$namespaces.AddNamespace("excerpt", "http://wordpress.org/export/1.2/excerpt/")
$namespaces.AddNamespace("dc", "http://purl.org/dc/elements/1.1/")

$authors = @{}
foreach ($authorNode in $doc.SelectNodes("//wp:author", $namespaces)) {
    $login = Get-ChildText $authorNode "wp:author_login" $namespaces
    $displayName = Get-ChildText $authorNode "wp:author_display_name" $namespaces
    if (-not [string]::IsNullOrWhiteSpace($login)) {
        $authors[$login] = if ([string]::IsNullOrWhiteSpace($displayName)) { $login } else { $displayName }
    }
}

$explicitlyPublishedDraftSlugs = @(
    "igromir-2011",
    "where-to-buy-hard"
)

$publishedPosts = New-Object System.Collections.Generic.List[object]
$skippedPosts = 0
$approvedCommentCount = 0

foreach ($item in $doc.SelectNodes("//item", $namespaces)) {
    $postType = Get-ChildText $item "wp:post_type" $namespaces
    $status = Get-ChildText $item "wp:status" $namespaces
    $title = Get-ChildText $item "title" $namespaces
    $postId = [int](Get-ChildText $item "wp:post_id" $namespaces)
    $slug = Normalize-FileName (Get-ChildText $item "wp:post_name" $namespaces) "post-$postId"
    if ($postType -ne "post") { continue }
    $shouldPublish = $status -eq "publish" -or ($status -eq "draft" -and $explicitlyPublishedDraftSlugs -contains $slug)
    if (-not $shouldPublish) {
        $skippedPosts += 1
        continue
    }

    $date = Format-ZolaDate (Get-ChildText $item "wp:post_date" $namespaces)
    $originalUrl = Get-ChildText $item "link" $namespaces
    $authorLogin = Get-ChildText $item "dc:creator" $namespaces
    $author = if ($authors.ContainsKey($authorLogin)) { $authors[$authorLogin] } else { $authorLogin }
    $body = Get-ChildText $item "content:encoded" $namespaces
    $body = Convert-MediaUrls -Html $body -StaticPath $staticPath -DownloadMedia:$DownloadMedia
    $previewImage = Get-LeadingImage $body
    $body = Convert-CodeBlocks $body
    $excerpt = Get-ChildText $item "excerpt:encoded" $namespaces
    $preview = if (-not [string]::IsNullOrWhiteSpace($excerpt)) {
        Get-PlainTextPreview $excerpt
    } else {
        Get-PlainTextPreview $body
    }
    $tags = Get-Terms $item "post_tag"

    $comments = New-Object System.Collections.Generic.List[object]
    foreach ($commentNode in $item.SelectNodes("wp:comment", $namespaces)) {
        $approved = Get-ChildText $commentNode "wp:comment_approved" $namespaces
        if ($approved -ne "1") { continue }
        $comment = [pscustomobject]@{
            Id = [int](Get-ChildText $commentNode "wp:comment_id" $namespaces)
            ParentId = [int](Get-ChildText $commentNode "wp:comment_parent" $namespaces)
            Author = Get-ChildText $commentNode "wp:comment_author" $namespaces
            Url = Get-ChildText $commentNode "wp:comment_author_url" $namespaces
            Date = Get-ChildText $commentNode "wp:comment_date" $namespaces
            Content = Convert-CodeBlocks (Convert-MediaUrls -Html (Get-ChildText $commentNode "wp:comment_content" $namespaces) -StaticPath $staticPath -DownloadMedia:$DownloadMedia)
        }
        $comments.Add($comment)
    }
    $approvedCommentCount += $comments.Count

    $frontMatter = New-Object System.Text.StringBuilder
    [void]$frontMatter.AppendLine("+++")
    [void]$frontMatter.AppendLine("title = $(Escape-TomlString $title)")
    [void]$frontMatter.AppendLine("date = $(Escape-TomlString $date)")
    [void]$frontMatter.AppendLine("slug = $(Escape-TomlString $slug)")
    [void]$frontMatter.AppendLine("path = $(Escape-TomlString $slug)")
    if (-not [string]::IsNullOrWhiteSpace($excerpt)) {
        [void]$frontMatter.AppendLine("description = $(Escape-TomlString (($excerpt -replace '<[^>]+>', ' ').Trim()))")
    } elseif (-not [string]::IsNullOrWhiteSpace($preview)) {
        [void]$frontMatter.AppendLine("description = $(Escape-TomlString $preview)")
    }
    [void]$frontMatter.AppendLine("")
    [void]$frontMatter.AppendLine("[taxonomies]")
    [void]$frontMatter.AppendLine("tags = $(Format-TomlArray $tags)")
    [void]$frontMatter.AppendLine("")
    [void]$frontMatter.AppendLine("[extra]")
    [void]$frontMatter.AppendLine("wordpress_id = $postId")
    [void]$frontMatter.AppendLine("author = $(Escape-TomlString $author)")
    [void]$frontMatter.AppendLine("author_login = $(Escape-TomlString $authorLogin)")
    [void]$frontMatter.AppendLine("original_url = $(Escape-TomlString $originalUrl)")
    [void]$frontMatter.AppendLine("preview = $(Escape-TomlString $preview)")
    if (-not [string]::IsNullOrWhiteSpace($previewImage) -and $previewImage.StartsWith("/assets/")) {
        [void]$frontMatter.AppendLine("preview_image = $(Escape-TomlString $previewImage)")
    }
    [void]$frontMatter.AppendLine("approved_comment_count = $($comments.Count)")
    [void]$frontMatter.AppendLine("+++")
    [void]$frontMatter.AppendLine("")

    $article = New-Object System.Text.StringBuilder
    [void]$article.Append($frontMatter.ToString())
    [void]$article.AppendLine($body.Trim())
    [void]$article.AppendLine("")
    if ($comments.Count -gt 0) {
        [void]$article.AppendLine("<section class=""historical-comments"" aria-labelledby=""comments-title"">")
        [void]$article.AppendLine("<h2 id=""comments-title"">Comments ($($comments.Count))</h2>")
        $commentsHtml = [string](Render-CommentTree -Comments @($comments.ToArray()) -ParentId 0 -Depth 1)
        [void]$article.Append($commentsHtml)
        [void]$article.AppendLine("</section>")
    }

    $outputFile = Join-Path $postsPath "$slug.md"
    [System.IO.File]::WriteAllText($outputFile, $article.ToString(), [System.Text.UTF8Encoding]::new($false))
    $publishedPosts.Add([pscustomobject]@{ Slug = $slug; Title = $title; Comments = $comments.Count })
}

$manifestPath = Join-Path (Split-Path $resolvedSite -Parent) "migration-summary.txt"
$summary = @(
    "Published posts migrated: $($publishedPosts.Count)"
    "Unpublished WordPress posts skipped: $skippedPosts"
    "Approved historical comments rendered: $approvedCommentCount"
)
[System.IO.File]::WriteAllText($manifestPath, ($summary -join "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "Published posts migrated: $($publishedPosts.Count)"
Write-Host "Unpublished WordPress posts skipped: $skippedPosts"
Write-Host "Approved historical comments rendered: $approvedCommentCount"
