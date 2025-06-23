#!/usr/bin/ruby

def to_hex bytes
    output = ("%064x" % bytes.length) + bytes.map { |byte| "%02x" % [byte] }.join("")
    output + ("0" * (64 - output.length % 64))
end

raise unless to_hex([0x12, 0x34, 0x56, 0x78, 0xaa, 0xbb, 0xcc, 0xdd]) == "000000000000000000000000000000000000000000000000000000000000000812345678aabbccdd000000000000000000000000000000000000000000000000"

data = File.read(ARGV[0], encoding: "binary").bytes
print to_hex(data)
