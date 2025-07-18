function decodesource ($encodedsource, [string]$mode = 'urldecode', [int]$number, [switch]$save, $outfile, [switch]$menu, [switch]$help) {# Decode a file or string to screen based on mode, with optional file save.

# Define decoders.
function AutoDetect {param([string]$s); $scores = @{}
# Base64
if ($s -match '^[A-Za-z0-9+/]+={0,2}$' -and ($s.Length % 4 -eq 0)) {try {$bytes = [Convert]::FromBase64String($s); $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
if ($decoded.Length -gt 0) {$printables = ($decoded.ToCharArray() | Where-Object {$_ -match '[\x20-\x7E]'}).Count; $ratio = $printables / $decoded.Length
if ($ratio -ge 0.8) {$scores['Base64'] = 5} 
elseif ($ratio -ge 0.5) {$scores['Base64'] = 3} 
else {$scores['Base64'] = 1}}} catch {$scores['Base64'] = 0}}
# GZip, ZLib, Deflate
if ($s -match '^[A-Za-z0-9+/]+={0,2}$' -and ($s.Length % 4 -eq 0)) {try {$bytes = [System.Convert]::FromBase64String($s); $header = ($bytes[0..1] -join ' ')
switch ($header) {'31 139' {$scores['GZip'] = 5}
'120 156' {$scores['ZLib'] = 5}
'120 1' {$scores['ZLib'] = 5}}
$scores['Deflate'] = 2}
catch {}}
# Hex
if ($s -match '^[0-9A-Fa-f]+$' -and ($s.Length % 2 -eq 0)) {try {$bytes = for ($i = 0; $i -lt $s.Length; $i += 2) {[Convert]::ToByte($s.Substring($i,2),16)}; $decoded = [System.Text.Encoding]::UTF8.GetString($bytes); $printables = ($decoded.ToCharArray() | Where-Object {$_ -match '[\x20-\x7E]'}).Count; $ratio = $printables / $decoded.Length; if ($ratio -ge 0.8) {$scores['Hexadecimal'] = 5} else {$scores['Hexadecimal'] = 3}} catch {}}
# URL encoding
if ($s -match '%[0-9A-Fa-f]{2}') {$scores['URLDecode'] = ($s -split '%[0-9A-Fa-f]{2}').Count}
# HTML Entities
if ($s -match '&[a-z]+;') {$scores['HTMLEntity'] = ($s -split '&[a-z]+;').Count}
# Quoted-printable
if ($s -match '=[0-9A-Fa-f]{2}') {$scores['QuotedPrintable'] = ($s -split '=[0-9A-Fa-f]{2}').Count}
# Unicode escape
if ($s -match '\\u[0-9A-Fa-f]{4}') {$scores['Unicode'] = ($s -split '\\u[0-9A-Fa-f]{4}').Count}
# Reverse string
if ($s -match '(\s*[.!?]\S[,-;:a-zA-Z\s]+[A-Z]){1,}') {$matches = [regex]::Matches($s, '(\s*[.!?]\S[,-;:a-zA-Z\s]+[A-Z])'); $scores['Reverse'] = $matches.Count}
# Return best match
if ($scores.Count -ge 1 -and $menu) {return $scores.GetEnumerator() | Where-Object {$_.Value -ge 1} | Sort-Object Value -Descending}
elseif ($scores.Count -gt 0 -and -not $menu) {return $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1}
return $null}

function Base64Decode {param([string]$s); try {$bytes = [Convert]::FromBase64String($s); return [System.Text.Encoding]::UTF8.GetString($bytes)} catch {Write-Host -f red "`nBase64 decode error: $_.`n"; return $s}}

function DeflateDecode {param([string]$s); $bytes = [System.Convert]::FromBase64String($s); if ($bytes.Length -ge 2) {$b0 = $bytes[0]; $b1 = $bytes[1]
if ($b0 -eq 0x78 -and ($b1 -eq 0x01 -or $b1 -eq 0x9C -or $b1 -eq 0xDA -or $b1 -eq 0x5E -or $b1 -eq 0xBB)) {Write-Host -f cyan "`nDetected zlib header, using zlib decode."; return DecodeZlib -Bytes $bytes}}
Write-Host -f cyan "`nNo zlib header detected, using raw deflate decode."; return DecodeDeflateRaw -Bytes $bytes}

function DecodeZlib {param([byte[]]$Bytes); $deflateBytes = $Bytes[2..($Bytes.Length - 1)]; $ms = New-Object IO.MemoryStream(, $deflateBytes); $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress); $sr = New-Object IO.StreamReader($ds); try {return $sr.ReadToEnd()} catch {Write-Host -f red "`nZlib decode failed: $_.`n"; return $null} finally {$sr.Close(); $ds.Close(); $ms.Close()}}

function DecodeDeflateRaw {param([byte[]]$Bytes); try {$ms = New-Object IO.MemoryStream(, $Bytes); $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress); $sr = New-Object IO.StreamReader($ds); $result = $sr.ReadToEnd(); $sr.Close(); $ds.Close(); $ms.Close(); return $result} catch {Write-Host -f red "`nRaw deflate decode error: $_.`n"; return ""}}

function GZipDecode {param([string]$s); try {$bytes = [System.Convert]::FromBase64String($s); $ms = New-Object System.IO.MemoryStream(,$bytes); $gzip = New-Object System.IO.Compression.GzipStream($ms, [IO.Compression.CompressionMode]::Decompress); $reader = New-Object System.IO.StreamReader($gzip, [System.Text.Encoding]::UTF8); return $reader.ReadToEnd()} catch {Write-Host -f red "`nGZipDecode failed: $_.`n"; return $null}}

function HexDecode {param([string]$s); try {if ($s.Length % 2 -ne 0) {throw "Hex string must have even length"}; $bytes = for ($i = 0; $i -lt $s.Length; $i += 2) {[Convert]::ToByte($s.Substring($i,2),16)}; return [System.Text.Encoding]::UTF8.GetString($bytes)} catch {Write-Host -f red "`nHex decode error: $_.`n"; return $s}}

function HtmlEntityDecode {param([string]$s); return [System.Net.WebUtility]::HtmlDecode($s)}

function QuotedPrintableDecode {param([string]$s); try {$cleaned = ($s -replace "=\r?\n", ""); return [regex]::Replace($cleaned, "=([0-9A-Fa-f]{2})", {param($m) [char][System.Convert]::ToInt32($m.Groups[1].Value,16)})} catch {Write-Host -f red "`nQuotedPrintable decode error: $_.`n"; return $s}}

function ReverseString {param([string]$s); $chars = $s.ToCharArray(); [Array]::Reverse($chars); return -join $chars}

function UnicodeEscapeDecode {param([string]$s); try {return ([regex]::Replace($s, '\\u([0-9A-Fa-f]{4})', {param($m) [char]([convert]::ToInt32($m.Groups[1].Value, 16))}))} catch {Write-Host -f red "`nUnicode escape decode error: $_.`n"; return $s}}

function URLDecode {param([string]$s); try{$cleaned = $s -replace '(?<=\w|\%)\+(?=\w|\%)', ' '; return [uri]::UnescapeDataString($cleaned)}
 catch {Write-Host -f red "`nURLDecode error: $_.`n"; return $s}}

function ZlibDecode {param([string]$s); try {$bytes = [Convert]::FromBase64String($s); $ms = [System.IO.MemoryStream]::new(); $ms.Write($bytes, 2, $bytes.Length - 2); $ms.Position = 0; $zlib = [System.IO.Compression.DeflateStream]::new($ms, [IO.Compression.CompressionMode]::Decompress); $reader = [System.IO.StreamReader]::new($zlib); return $reader.ReadToEnd()} catch {Write-Host -f red "`nZlib decode error: $_.`n"; return $s}}

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

function help {# Inline help.
# Select content.
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)"); $selection = $null; $lines = @(); $wrappedLines = @(); $position = 0; $pageSize = 30; $inputBuffer = ""

function scripthelp ($section) {$pattern = "(?ims)^## ($([regex]::Escape($section)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}

# Display Table of Contents.
while ($true) {cls; Write-Host -f cyan "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object { $_.FullName -ieq $PSCommandPath } | Select-Object -ExpandProperty BaseName) Help Sections:`n"

if ($sections.Count -gt 7) {$half = [Math]::Ceiling($sections.Count / 2)
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; $leftNumber  = "{0,2}." -f ($leftIndex + 1); $leftLabel   = " $($sections[$leftIndex].Groups[1].Value)"; $leftOutput  = [string]::Empty

if ($rightIndex -lt $sections.Count) {$rightNumber = "{0,2}." -f ($rightIndex + 1); $rightLabel  = " $($sections[$rightIndex].Groups[1].Value)"; Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel -n; $pad = 40 - ($leftNumber.Length + $leftLabel.Length)
if ($pad -gt 0) {Write-Host (" " * $pad) -n}; Write-Host -f cyan $rightNumber -n; Write-Host -f white $rightLabel}
else {Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel}}}

else {for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host -f cyan ("{0,2}. " -f ($i + 1)) -n; Write-Host -f white "$($sections[$i].Groups[1].Value)"}}

# Display Header.
line yellow 100
if ($lines.Count -gt 0) {Write-Host  -f yellow $lines[0]}
else {Write-Host "Choose a section to view." -f darkgray}
line yellow 100

# Display content.
$end = [Math]::Min($position + $pageSize, $wrappedLines.Count)
for ($i = $position; $i -lt $end; $i++) {Write-Host -f white $wrappedLines[$i]}

# Pad display section with blank lines.
for ($j = 0; $j -lt ($pageSize - ($end - $position)); $j++) {Write-Host ""}

# Display menu options.
line yellow 100; Write-Host -f white "[↑/↓]  [PgUp/PgDn]  [Home/End]  |  [#] Select section  |  [Q] Quit  " -n; if ($inputBuffer.length -gt 0) {Write-Host -f cyan "section: $inputBuffer" -n}; $key = [System.Console]::ReadKey($true)

# Define interaction.
switch ($key.Key) {'UpArrow' {if ($position -gt 0) { $position-- }; $inputBuffer = ""}
'DownArrow' {if ($position -lt ($wrappedLines.Count - $pageSize)) { $position++ }; $inputBuffer = ""}
'PageUp' {$position -= 30; if ($position -lt 0) {$position = 0}; $inputBuffer = ""}
'PageDown' {$position += 30; $maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); if ($position -gt $maxStart) {$position = $maxStart}; $inputBuffer = ""}
'Home' {$position = 0; $inputBuffer = ""}
'End' {$maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); $position = $maxStart; $inputBuffer = ""}

'Enter' {if ($inputBuffer -eq "") {"`n"; return}
elseif ($inputBuffer -match '^\d+$') {$index = [int]$inputBuffer
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index; $pattern = "(?ims)^## ($([regex]::Escape($sections[$selection-1].Groups[1].Value)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $block = $match.Groups[1].Value.TrimEnd(); $lines = $block -split "`r?`n", 2
if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}}
$inputBuffer = ""}

default {$char = $key.KeyChar
if ($char -match '^[Qq]$') {"`n"; return}
elseif ($char -match '^\d$') {$inputBuffer += $char}
else {$inputBuffer = ""}}}}}

# External call to help.
if ($help) {help; return}

# Usage.
function usage {Write-Host -f cyan "`nUsage: decodesource `"source string/file`" <auto/base64/deflate/gzip/hex/htmlentity/reverse/unicode/urldecode/quotedprintable/zlib> <number for urldecode iterations> -save <outfile> -menu -help`n"; return}

# Accept input.
function obtainvalue {if ($script:multiline) {Write-Host -f cyan "`n`nEnter the string to decode (type 'END' on a new line to finish):"; $lines = @()
while ($true) {$line = Read-Host
if ($line -eq 'END') {break}
$lines += $line};
$script:multiline = $false
return $lines -join "`n"}
else {Write-Host -f cyan "`n`nEnter the string to decode: " -n; return (Read-Host)}}

# Error-checking.
if (-not $encodedsource -and -not $menu) {usage; return}

# Interactive method.
if ($menu) {# Handle key assignments.
function getaction {while ($true) {$key = [System.Console]::ReadKey($true)
$char = $key.KeyChar
switch ($key.Key) {'F1' {return 'H'}
'Escape' {return 'Q'}
'Enter'  {if ($buffer) {return $buffer}
else {return 'CLEAR'}}
'Backspace' {return 'CLEAR'}
{$_ -match '(?i)[\dAHMQ]'} {return $char.ToString().ToUpper()}
default {return 'Invalid input.'}}}}

# Display menu.
while ($true) {
cls; Write-Host -f yellow "Decoding Method:"; line yellow 60
Write-Host -f cyan "0. " -n; Write-Host -f white "Base64".padright(32) -n; Write-Host -f white "Multi-line input is: " -n; if ($script:multiline) {Write-Host -f green "on"} else {Write-Host "off"}
Write-Host -f cyan "1. " -n; Write-Host -f white "Deflate"
Write-Host -f cyan "2. " -n; Write-Host -f white "GZip"
Write-Host -f cyan "3. " -n; Write-Host -f white "Hexadecimal"
Write-Host -f cyan "4. " -n; Write-Host -f white "HTMLEntity"
Write-Host -f cyan "5. " -n; Write-Host -f white "QuotedPrintable"
Write-Host -f cyan "6. " -n; Write-Host -f white "Reverse"
Write-Host -f cyan "7. " -n; Write-Host -f white "Unicode"
Write-Host -f cyan "8. " -n; Write-Host -f white "URLDecode"
Write-Host -f cyan "9. " -n; Write-Host -f white "ZLib"
Write-Host -f cyan "A. " -n; Write-Host -f white "Auto-detect"
line yellow 60 

# Display message center.
if ($errormessage) {wordwrap "$errormessage`n" | Write-Host -f red}
elseif ($message) {wordwrap "$message`n" | Write-Host -f white }
else {Write-Host "`n"}

# Present options.
Write-Host -f yellow "[#]Decode Method  [H]elp  [M]ulti-line input  [Q]uit " -n
$errormessage = $null; $message = $null

$action = getaction

# Assign instant action keys.
switch ($action.ToString().ToUpper()) {'CLEAR' {$message = $null; $errormessage = $null}
'H' {help}
'Q' {"`n"; return}

'A' {$decodedheader = $null; $decoded = $null; $value = obtainvalue; $guesses = AutoDetect $value; if ($guesses) {foreach ($entry in $guesses) {$method = $entry.Key; $score = $entry.Value; if ($score -gt 10) {$score = 10}; $decodedheader += "`n$method (Probability: $($score*10)%)`n"
$result = switch ($method) {'base64' {Base64Decode $value}
'gzip' {GZipDecode $value}
'zlib' {ZlibDecode $value}
'deflate' {DeflateDecode $value}
'hex' {HexDecode $value}
'urldecode' {URLDecode $value}
'htmlentity' {HtmlEntityDecode $value}
'quotedprintable' {QuotedPrintableDecode $value}
'unicode' {UnicodeEscapeDecode $value}
'reverse' {ReverseString $value}}
$decodedheader += "$result`n"}
$message = $decodedheader; $errormessage = $null}
else {$message = $null; $errormessage = "Unable to detect encoding."}}

'M' {$script:multiline = -not $script:multiline}
'0' {$value = obtainvalue; $decodedString = Base64Decode $value; $message = $decodedString; $errormessage = $null}
'1' {$value = obtainvalue; $decodedString = DeflateDecode $value; $message = $decodedString; $errormessage = $null}
'2' {$value = obtainvalue; $decodedString = GZipDecode $value; $message = $decodedString; $errormessage = $null}
'3' {$value = obtainvalue; $decodedString = HexDecode $value; $message = $decodedString; $errormessage = $null}
'4' {$value = obtainvalue; $decodedString = HTMLEntityDecode $value; $message = $decodedString; $errormessage = $null}
'5' {$value = obtainvalue; $decodedString = QuotedPrintableDecode $value; $message = $decodedString; $errormessage = $null}
'6' {$value = obtainvalue; $decodedString = ReverseString $value; $message = $decodedString; $errormessage = $null}
'7' {$value = obtainvalue; $decodedString = UnicodeEscapeDecode $value; $message = $decodedString; $errormessage = $null}
'8' {$value = obtainvalue; $decodedString = URLDecode $value; $message = $decodedString; $errormessage = $null}
'9' {$value = obtainvalue; $decodedString = ZLibDecode $value; $message = $decodedString; $errormessage = $null}
default {$message = $null; $errormessage = "Invalid key."}}}}

# Set default for URLDecoding and verify sourcetype.
if (-not $number) {$number = 3}
if (Test-Path $encodedsource) {$fileContent = Get-Content -Path $encodedsource -Raw; $source = (Resolve-Path $encodedsource).Path}
else {$fileContent = $encodedsource; $source = "String input"}
$decodedString = $fileContent

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

# Output to file.
Write-Host -f cyan "`n$source"
# File saving if chosen.
if (($save) -and (Test-Path $encodedsource) -and -not $outfile) {$baseName = [System.IO.Path]::GetFileNameWithoutExtension($source); $extension = [System.IO.Path]::GetExtension($source); $newFileName = "$baseName - decoded$extension"; Set-Content $newFileName $decodedString; Write-Host -f cyan "Output saved to: $newFileName"}
# Custom destination file save.
elseif (($save) -and (Test-Path $encodedsource) -and $outfile) {Set-Content $outfile $decodedString; Write-Host -f cyan "Output saved to: $outfile"}

# Output to screen.
line yellow; Write-Host "$fileContent"; Write-Host -f yellow ("-" * 100); Write-Host "$decodedString"; line yellow -post}

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
• ZLib

Usage: decodesource "source string/file" decodemethod <number for urldecode iterations> -save <outfile> -menu -help

One important note is that I did not use the traditional method of URLDecoding, which is to use the native System Web HttpUtility, because this is readily abused by threat actors and I do not want this utility getting mistaken for anything other than legitimate software. Therefore, I used the safer UnescapeDataString method and applied some Regex logic around the plus sign "+" to " " space character conversions that is so easily handled by the web utility, but not handled as gracefully by this alternate method.

While this method may not be 100% accurate in all cases, I believe the trade off with what is essentially human readable text in either case, still allows for a reasonable decoding method that should make this safely detected by even the most aggressive antimalware and antivirus software programs.

The -menu option displays an interactive menu for reiterative decoding actions.
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
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>
