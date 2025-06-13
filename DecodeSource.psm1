function decodesource ($encodedsource, [string]$mode = 'urldecode', [int]$number, [switch]$save, $outfile, [switch]$help) {# Decode a file or string to screen based on mode, with optional file save.

function usage {Write-Host -f cyan "`nUsage: decodesource `"source string/file`" <auto/base64/deflate/gzip/hex/htmlentity/reverse/unicode/urldecode/quotedprintable/zlib> <number for urldecode iterations> -save <outfile> -help`n"; return}

if ($help) {# Inline help.
function wordwrap ($field, [int]$maximumlinelength = 65) {# Modify fields sent to it with proper word wrapping.
if ($null -eq $field -or $field.Length -eq 0) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()

foreach ($line in $field -split "`n") {if ($line.Trim().Length -eq 0) {$wrapped += ''; continue}
$remaining = $line.Trim()
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1

foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakChar = $char; $breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1; $breakChar = ''}
$chunk = $segment.Substring(0, $breakIndex + 1).TrimEnd(); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1).TrimStart()}

if ($remaining.Length -gt 0) {$wrapped += $remaining}}
return ($wrapped -join "`n")}

function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -f yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; Write-Host -f yellow ("-" * 100)
if ($lines.Count -gt 1) {wordwrap $lines[1] 100| Out-String | Out-Host -Paging}; Write-Host -f yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}

$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

if (-not $encodedsource) {usage; return}

# Set default for URLDecoding and verify sourcetype.
if (-not $number) {$number = 3}
if (Test-Path $encodedsource) {$fileContent = Get-Content -Path $encodedsource -Raw; $source = (Resolve-Path $encodedsource).Path}
else {$fileContent = $encodedsource; $source = "String input"}
$decodedString = $fileContent

# Define decoders.
function AutoDetect {param([string]$s); $scores = @{}
# Base64
if ($s -match '^[A-Za-z0-9+/]+={0,2}$' -and ($s.Length % 4 -eq 0)) {try {$bytes = [Convert]::FromBase64String($s); $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
if ($decoded.Length -gt 0) {$printables = ($decoded.ToCharArray() | Where-Object {$_ -match '[\x20-\x7E]'}).Count; $ratio = $printables / $decoded.Length
if ($ratio -ge 0.8) {$scores['base64'] = 5} 
elseif ($ratio -ge 0.5) {$scores['base64'] = 3} 
else {$scores['base64'] = 1}}} catch {$scores['base64'] = 0}}
# GZip, ZLib, Deflate
if ($s -match '^[A-Za-z0-9+/]+={0,2}$' -and ($s.Length % 4 -eq 0)) {try {$bytes = [System.Convert]::FromBase64String($s); $header = ($bytes[0..1] -join ' '); switch ($header) {'31 139' { $scores['gzip'] = 5 }; '120 156' { $scores['zlib'] = 5 }; '120 1'   { $scores['zlib'] = 5 }}; $scores['deflate'] = 2} catch {}}
# Hex
if ($s -match '^[0-9A-Fa-f]+$' -and ($s.Length % 2 -eq 0)) {try {$bytes = for ($i = 0; $i -lt $s.Length; $i += 2) {[Convert]::ToByte($s.Substring($i,2),16)}; $decoded = [System.Text.Encoding]::UTF8.GetString($bytes); $printables = ($decoded.ToCharArray() | Where-Object {$_ -match '[\x20-\x7E]'}).Count; $ratio = $printables / $decoded.Length; if ($ratio -ge 0.8) {$scores['hex'] = 5} else {$scores['hex'] = 3}} catch {}}
# URL encoding
if ($s -match '%[0-9A-Fa-f]{2}') {$scores['urldecode'] = ($s -split '%[0-9A-Fa-f]{2}').Count}
# HTML Entities
if ($s -match '&[a-z]+;') {$scores['htmlentity'] = ($s -split '&[a-z]+;').Count}
# Quoted-printable
if ($s -match '=[0-9A-Fa-f]{2}') {$scores['quotedprintable'] = ($s -split '=[0-9A-Fa-f]{2}').Count}
# Unicode escape
if ($s -match '\\u[0-9A-Fa-f]{4}') {$scores['unicode'] = ($s -split '\\u[0-9A-Fa-f]{4}').Count}
# Reverse string: low score, last resort
$scores['reverse'] = 0.5
# Return best match
if ($scores.Count -gt 0) {return $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1}
return $null}

function Base64Decode {param([string]$s); try {$bytes = [Convert]::FromBase64String($s); return [System.Text.Encoding]::UTF8.GetString($bytes)} catch {Write-Host -f red "`nBase64 decode error: $_.`n"; return $s}}

function DeflateDecode {param([string]$s); $bytes = [System.Convert]::FromBase64String($s); if ($bytes.Length -ge 2) {$b0 = $bytes[0]; $b1 = $bytes[1]
if ($b0 -eq 0x78 -and ($b1 -eq 0x01 -or $b1 -eq 0x9C -or $b1 -eq 0xDA -or $b1 -eq 0x5E -or $b1 -eq 0xBB)) {Write-Host -f cyan "`nDetected zlib header, using zlib decode."; return Decode-Zlib -Bytes $bytes}}
Write-Host -f cyan "`nNo zlib header detected, using raw deflate decode."; return Decode-DeflateRaw -Bytes $bytes}

function Decode-Zlib {param([byte[]]$Bytes); $deflateBytes = $Bytes[2..($Bytes.Length - 1)]; $ms = New-Object IO.MemoryStream(, $deflateBytes); $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress); $sr = New-Object IO.StreamReader($ds); try {return $sr.ReadToEnd()} catch {Write-Host -f red "`nZlib decode failed: $_.`n"; return $null} finally {$sr.Close(); $ds.Close(); $ms.Close()}}

function Decode-DeflateRaw {param([byte[]]$Bytes); try {$ms = New-Object IO.MemoryStream(, $Bytes); $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress); $sr = New-Object IO.StreamReader($ds); $result = $sr.ReadToEnd(); $sr.Close(); $ds.Close(); $ms.Close(); return $result} catch {Write-Host -f red "`nRaw deflate decode error: $_.`n"; return ""}}

function GZipDecode {param([string]$s); try {$bytes = [System.Convert]::FromBase64String($s); $ms = New-Object System.IO.MemoryStream(,$bytes); $gzip = New-Object System.IO.Compression.GzipStream($ms, [IO.Compression.CompressionMode]::Decompress); $reader = New-Object System.IO.StreamReader($gzip, [System.Text.Encoding]::UTF8); return $reader.ReadToEnd()} catch {Write-Host -f red "`nGZipDecode failed: $_.`n"; return $null}}

function HexDecode {param([string]$s); try {if ($s.Length % 2 -ne 0) {throw "Hex string must have even length"}; $bytes = for ($i = 0; $i -lt $s.Length; $i += 2) {[Convert]::ToByte($s.Substring($i,2),16)}; return [System.Text.Encoding]::UTF8.GetString($bytes)} catch {Write-Host -f red "`nHex decode error: $_.`n"; return $s}}

function HtmlEntityDecode {param([string]$s); return [System.Net.WebUtility]::HtmlDecode($s)}

function QuotedPrintableDecode {param([string]$s); try {$cleaned = ($s -replace "=\r?\n", ""); return [regex]::Replace($cleaned, "=([0-9A-Fa-f]{2})", {param($m) [char][System.Convert]::ToInt32($m.Groups[1].Value,16)})} catch {Write-Host -f red "`nQuotedPrintable decode error: $_.`n"; return $s}}

function ReverseString {param([string]$s); $chars = $s.ToCharArray(); [Array]::Reverse($chars); return -join $chars}

function UnicodeEscapeDecode {param([string]$s); try {return ([regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {param($m) [char]([convert]::ToInt32($m.Groups[1].Value, 16))}))} catch {Write-Host -f red "`nUnicode escape decode error: $_.`n"; return $s}}

function URLDecode {param([string]$s); try{$cleaned = $s -replace '(?<=\w|\%)\+(?=\w|\%)', ' '; return [uri]::UnescapeDataString($cleaned)}
 catch {Write-Host -f red "`nURLDecode error: $_.`n"; return $s}}

function ZlibDecode {param([string]$s); try {$bytes = [Convert]::FromBase64String($s); $ms = [System.IO.MemoryStream]::new(); $ms.Write($bytes, 2, $bytes.Length - 2); $ms.Position = 0; $zlib = [System.IO.Compression.DeflateStream]::new($ms, [IO.Compression.CompressionMode]::Decompress); $reader = [System.IO.StreamReader]::new($zlib); return $reader.ReadToEnd()} catch {Write-Host -f red "`nZlib decode error: $_.`n"; return $s}}

# Set decoder based on user input.
if ($mode.ToLower() -eq 'auto') {$guess = AutoDetect -s $decodedString; if ($guess) {Write-Host -f green "`nAuto-detect: Likely encoding is '$($guess.Key)' (score: $($guess.Value))"; $mode = $guess.Key} 
else {Write-Host -f red "`nAuto-detect failed: Could not confidently determine encoding."; return}}

switch ($mode.ToLower()) {
'base64' {$decodedString = Base64Decode -s $decodedString}
'deflate' {$decodedString = DeflateDecode -s $decodedString}
'gzip' {$decodedString = GZipDecode -s $decodedString}
'hex' {$decodedString = HexDecode -s $decodedString}
'htmlentity' {$decodedString = HtmlEntityDecode -s $decodedString}
'quotedprintable' {$decodedString = QuotedPrintableDecode -s $decodedString}
'reverse' {$decodedString = ReverseString -s $decodedString}
'unicode' {$decodedString = UnicodeEscapeDecode -s $decodedString}
'urldecode' {for ($i = 0; $i -lt $number; $i++) {$decodedString = URLDecode -s $decodedString}}
'zlib' {$decodedString = ZlibDecode -s $decodedString}
default {usage; return}}

# Output.
Write-Host -f cyan "`n$source"
# File saving if chosen.
if (($save) -and (Test-Path $encodedsource) -and -not $outfile) {$baseName = [System.IO.Path]::GetFileNameWithoutExtension($source); $extension = [System.IO.Path]::GetExtension($source); $newFileName = "$baseName - decoded$extension"; Set-Content $newFileName $decodedString; Write-Host -f cyan "Output saved to: $newFileName"}
# Custom destination file save.
elseif (($save) -and (Test-Path $encodedsource) -and $outfile) {Set-Content $outfile $decodedString; Write-Host -f cyan "Output saved to: $outfile"}
# Output to screen.
Write-Host -f yellow ("-" * 100); Write-Host "$fileContent"; Write-Host -f yellow ("-" * 100); Write-Host "$decodedString"; Write-Host -f yellow ("-" * 100); ""}

Export-ModuleMember -Function decodesource

<#
## Overview

This started out as a simple URLDecoder tool, in order to allow security personnel to decode strings iteratively if necessary, but I decided to expand it, by adding more decode methodologies. So, I started digging into what could be accomplished natively in PowerShell without extensions and these are the ones I came up with. Yes, the "reverse" method is kind of silly and no I did not include ROT-13, because my Caesar tool already does that and a lot more, but this list covers pretty much everything else:

• Base64
• Deflate
• GZip
• Hex
• HTMLEntity
• QuotedPrintable
• Reverse
• Unicode
• URLDecode *
• ZLip

Usage: decodesource "source string/file" decodemethod <number for urldecode iterations> -save <outfile> -help

One important note is that I did not use the traditional method of URLDecoding, which is to use the native System Web HttpUtility, because this is readily abused by threat actors and I do not want this utility getting mistaken for anything other than legitimate software. Therefore, I used the safer UnescapeDataString method and applied some Regex logic around the plus sign "+" to " " space character conversions that is so easily handled by the web utility, but not handled as gracefully by this alternate method.

While this method may not be 100% accurate in all cases, I believe the trade off with what is essentially human readable text in either case, still allows for a reasonable decoding method that should make this safely detected by even the most aggressive antimalware and antivirus software programs.
## Examples

In order to test each of the decoding methods, you can use these samples:

decodesource "SGVsbG8gV29ybGQh" base64
decodesource "eJzLSM3JyVcozy/KSVEEAB0JBF4=" deflate
decodesource "H4sIAAAAAAAACvNIzcnJ11EIzy/KSVFUCMnILFbILFZIVMjJz0tPLVIoSS0uUchNLS5OTE/VAwB8FnlLLAAAAA==" gzip
decodesource "48656c6c6f20576f726c6421" hex
decodesource "Hello&nbsp;World&#33;" htmlentity
decodesource "Hello=20World=21" quotedprintable
decodesource "!dlroW olleH" reverse
decodesource "\u0048\u0065\u006c\u006c\u006f\u0020\u0057\u006f\u0072\u006c\u0064\u0021" unicode
decodesource "Hello%20World%21" urldecode
decodesource "eJzLSM3JyVcozy/KSVEEAB0JBF4=" zlib

I wasn't able to get a smaller sample successfully compressed and decompressed using GZip. So, I used a longer sample, but I doubt that this will be a problem in real-world use.

In order to test the auto-detection mechanism, use the same samples as above, but replace the decode method with "auto" and let the heuristics work their magic:

decodesource "SGVsbG8gV29ybGQh" auto
decodesource "eJzLSM3JyVcozy/KSVEEAB0JBF4=" auto
decodesource "H4sIAAAAAAAACvNIzcnJ11EIzy/KSVFUCMnILFbILFZIVMjJz0tPLVIoSS0uUchNLS5OTE/VAwB8FnlLLAAAAA==" auto
decodesource "48656c6c6f20576f726c6421" auto
decodesource "Hello&nbsp;World&#33;" auto
decodesource "Hello=20World=21" auto
decodesource "!dlroW olleH" auto
decodesource "\u0048\u0065\u006c\u006c\u006f\u0020\u0057\u006f\u0072\u006c\u0064\u0021" auto
decodesource "Hello%20World%21" auto
decodesource "eJzLSM3JyVcozy/KSVEEAB0JBF4=" auto

Enjoy and happy threat hunting!
##>
