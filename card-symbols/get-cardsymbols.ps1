$scryfall = "https://svgs.scryfall.io/card-symbols/{0}.svg"

$colors = (
    'WU',
    'WB',
    'BR',
    'BG',
    'UB',
    'UR',
    'RG',
    'RW',
    'GW',
    'GU',
    'W',
    'U',
    'B',
    'R',
    'G',
    'C',
    'X'
)


$colors | ForEach-Object {
    $c = $_
    $uri = $scryfall -f $c
    Write-Output "$uri > $c.png"
    magick -background none -size 100x100 "$uri" "$c.png"
}