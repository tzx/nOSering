|files table|file1|file2|....|

files table: 1024 bytes (2 sectors)
just an ordered array in this order:
|name:u32, size: u32|name, size|....|
There can only be 1024 // ((32 + 32)/8) = 128 files

each file section takes 1MiB long (no choice), so that's the max file size

index is the ordered placement in the files table starting at 0
index is used to find the section that represent the file
Example - to find the start of the section for file of index 4:
1024(files table) + 4(idx) * 1048576(1MiB)

null character as name means it is not used


Wait this is not efficient; size of bytes don't make sense; there are no directories!; duplicate file names!
Yea and I don't care.
