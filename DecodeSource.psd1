@{RootModule = 'DecodeSource.psm1'
ModuleVersion = '1.2'
GUID = 'e4a7b2e2-1234-4a5f-8d10-9f87c1234567'
Author = 'Schvenn'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '(c) Craig Plath. All rights reserved.'
Description = 'Multi-encoding decode tool supporting base64, deflate, gzip, hex, htmlentity, quotedprintable, reverse, unicode, urldecode, and zlib, without external dependencies or need to use external sources.'
PowerShellVersion = '5.1'
FunctionsToExport = @('decodesource')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
FileList = @('DecodeSource.psm1')

PrivateData = @{PSData = @{Tags = @('base64','decode','deflate','gzip','hex','htmlentity','quotedprintable','unicode','url','urldecode','security','forensics','cybersecurity','SOC')
LicenseUri = 'https://github.com/Schvenn/DecodeSource/blob/main/LICENSE'
ProjectUri = 'https://github.com/Schvenn/DecodeSource'
ReleaseNotes = 'Initial PowerShell gallery release. Module for local multi-method text decoding, no dependencies, keeps data secure by keeping it offline.'}}}
