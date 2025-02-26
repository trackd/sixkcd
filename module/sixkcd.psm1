class xkcd {
    [int] $id
    [datetime] $Date
    [string] $Title
    [uri] $Image
    [string] $Alt
}
function Get-xkcdobj {
    [CmdletBinding()]
    param(
        [int]$id
    )
    $url = 'https://xkcd.com/{0}/info.0.json'
    $x = Invoke-RestMethod ($url -f $id)
    [xkcd]@{
        id    = $x.num
        Date  = Get-Date -Year $x.year -Month $x.month -Day $x.day
        Title = $x.safe_title
        Image = $x.img
        Alt   = $x.alt
    }
}
function Import-xkcd {
    [CmdletBinding()]
    param()
    $dict = [System.Collections.Generic.Dictionary[int, xkcd]]::new()
    $json = Get-Content -Raw "$PSScriptRoot\sixkcd.json" | ConvertFrom-Json
    foreach ($x in $json) {
        if (!$dict.ContainsKey($x.id)) {
            $dict.add($x.id, [xkcd]@{
                    id    = $x.id
                    Date  = $x.Date
                    Title = $x.Title
                    Image = $x.Image
                    Alt   = $x.Alt
                })
        }
    }
    return $dict
}
function Update-xkcd {
    [CmdletBinding()]
    param()
    [int]$Newest = (Invoke-RestMethod 'https://xkcd.com/info.0.json').num
    [int]$Lastcached = @($script:cache.Get_Keys())[-1]
    if ($Newest -gt $Lastcached) {
        $Lastcached..$Newest | ForEach-Object {
            if (!$script:cache.ContainsKey($_)) {
                $t = Get-xkcdobj $_
                $script:cache.add($t.id, $t)
            }
        }
        $script:cache.GetEnumerator() | ForEach-Object {
            $_.Value
        } | ConvertTo-Json | Set-Content "$PSScriptRoot\sixkcd.json"
    }
}
function prettyxkcd {
    param(
        [string]$sixel,
        [xkcd] $xkcd
    )
    $colors = Get-PSReadLineOption
    $line = '━' * $host.ui.RawUI.WindowSize.Width
    $sb = [System.Text.StringBuilder]::new()
    $null = & {
        $sb.AppendLine($line).
        Append($PSStyle.Bold).
        Append('# xkcd ').
        Append($colors.NumberColor).
        AppendLine($PSStyle.FormatHyperlink($xkcd.id, ('https://xkcd.com/' + $xkcd.id))).
        Append($PSStyle.Reset).
        Append('Title: ').
        Append($colors.StringColor).
        Append($xkcd.Title).
        Append($PSStyle.Reset).
        Append(' Date: ').
        Append($colors.TypeColor).
        Append($xkcd.Date.ToShortDateString()).
        Append($PSStyle.Reset).
        Append($PSStyle.Bold).
        Append(' Image: ').
        Append($PSStyle.Foreground.Blue).
        AppendLine($PSStyle.FormatHyperlink(([system.io.path]::GetFileNameWithoutExtension($xkcd.image)), $xkcd.Image)).
        Append($PSStyle.Reset).
        AppendLine($line).
        AppendLine().
        AppendLine($sixel).
        Append($colors.OperatorColor).
        Append($PSStyle.Italic).
        Append($xkcd.Alt).
        Append($PSStyle.Reset).
        AppendLine()
    }
    $sb.ToString()
}
function Get-xkcd {
    <#
    .DESCRIPTION
    displays XKCD comics in the console using Sixel images.
    .PARAMETER Number
    The number of the XKCD comic to display.
    .PARAMETER Width
    The width of the Sixel image.
    .PARAMETER OnlySixel
    Only display the Sixel image.
    .PARAMETER Latest
    Display the latest XKCD comic.
    .PARAMETER xkcd
    The XKCD object to display.
    #>
    [cmdletbinding()]
    param(
        [Parameter(Position = 0)]
        [int] $Number,
        [Parameter(Position = 1)]
        [int] $Width,
        [switch] $OnlySixel,
        [Alias('Newest')]
        [switch] $Latest,
        [Parameter(ValueFromPipeline)]
        [xkcd] $xkcd
    )
    begin {
        $params = @{}
        if ($Width) {
            $params.Width = $Width
        }
    }
    process {
        if ($Number) {
            $xkcd = $script:cache[$Number]
        }
        elseif ($Latest) {
            # +1 is just for 404 missing.
            $xkcd = $script:cache[$script:cache.count + 1]
        }
        elseif (-Not $xkcd) {
            # comic 404 might error here some day, but thats just gonna be a bit fun i think.
            $random = Get-Random -Minimum 1 -Maximum $script:cache.Count
            $xkcd = $script:cache[$random]
        }
        if ($xkcd) {
            if ($OnlySixel) {
                return ConvertTo-Sixel -Uri $xkcd.Image @params
            }
            prettyxkcd -xkcd $xkcd -Sixel (ConvertTo-Sixel -Uri $xkcd.Image @params)
        }
    }
}

function Search-xkcd {
    <#
    .DESCRIPTION
    Search for XKCD comics by title or alt text.
    .PARAMETER Title
    The title of the XKCD comic to search for.
    .PARAMETER Alt
    The alt text of the XKCD comic to search for.
    .PARAMETER MaxResults
    The maximum number of results to return.
    .PARAMETER Width
    The width of the Sixel image.
    .PARAMETER List
    List the results instead of displaying them.
    .PARAMETER OnlySixel
    Only display the Sixel image.
    #>
    [cmdletbinding()]
    param(
        [string] $Title,
        [string] $Alt,
        [int] $MaxResults = 3,
        [int] $Width,
        [Switch] $List,
        [switch] $OnlySixel
    )
    $params = @{}
    if ($Width) {
        $params.Width = $Width
    }
    if ($OnlySixel) {
        $params.OnlySixel = $true
    }
    foreach ($x in $script:cache.GetEnumerator()) {
        if ($MaxResults -eq 0) {
            break
        }
        if ($Title) {
            if ($x.Value.Title -match $Title) {
                if ($List) {
                    $x.Value
                }
                else {
                    $x.Value | Get-xkcd @params
                }
                $MaxResults--
                continue
            }
        }
        if ($Alt) {
            if ($x.Value.Alt -match $Alt) {
                if ($List) {
                    $x.Value
                }
                else {
                    $x.Value | Get-xkcd @params
                }
                $MaxResults--
                continue
            }
        }
    }
}

$script:cache = Import-xkcd
Update-xkcd
