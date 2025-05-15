# DecodeSource
Powershell module to decrypt 10 different types of encryption methods using native PowerShell functionality.

This started out as a simple URLDecoder tool, in order to allow security personnel to decode strings iteratively if necessary, but I decided to expand it, by adding more decode methodologies. So, I started digging into what could be accomplished natively in PowerShell without extensions and these are the ones I came up with. Yes, the "reverse" method is kind of silly and no I did not include ROT-13, because my Caesar tool already does that and a lot more, but this list covers pretty much everything else:

• Base64

• Deflate

• GZip

• Hex

• HTMLEntity

• QuotedPrintable

• Reverse

• Unicode

• URLDecode

• ZLip

Usage: decodesource "source string/file" decodemethod -save <outfile> -help
