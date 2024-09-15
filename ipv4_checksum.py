import struct
# IP_VERSION          = 4'd4;                 # IPv4                           
# IP_IHL              = 4'd5;                 # IHL(5) == 20 bytes length      
# IP_TOS              = 0;                    # type of service 0 -> normal    
# IP_TOTAL_LENGTH     = 16'h0028;                # 20 byte header 20 bytes data   
# IP_ID               = 0;                    # fragmentation not considered   
# IP_FRAG_OFFSET      = 16'h4000;             # Don't Fragment (DF)            
# IP_TTL              = 8'h40;                # 64, common time to live        
# IP_PROTOCOL         = 8'h11;                # UDP                            
# IP_SOURCE_IP        = 32'hc0a80164;         # 192.168.1.100                  
# IP_DESTINATION_IP   = 32'hc0a801FF;         # broadcast 192.168.1.255        
# IP_CHECKSUM         = 0;                    # 0 for the same of checksum calc 


def calculate_ipv4_checksum(header_bytes):
    # Ensure that the header is exactly 20 bytes
    if len(header_bytes) != 20:
        raise ValueError("Header must be exactly 20 bytes")

    # Set checksum field (bytes 10-11 in the header) to zero for checksum calculation
    header_bytes = header_bytes[:10] + b'\x00\x00' + header_bytes[12:]

    # Sum all 16-bit words
    checksum = 0
    for i in range(0, len(header_bytes), 2):
        # Unpack two bytes at a time into a 16-bit (short) integer
        word, = struct.unpack('!H', header_bytes[i:i+2])
        checksum += word
        # Handle overflow
        checksum = (checksum & 0xFFFF) + (checksum >> 16)

    # Finalize checksum: One's complement
    checksum = ~checksum & 0xFFFF
    return checksum

# Example usage
header = b'\x45\x00\x00\x28\x00\x00\x40\x00\x40\x11\x00\x00\xc0\xa8\x01\x65\xc0\xa8\x01\xff'
checksum = calculate_ipv4_checksum(header)
print("Checksum:", format(checksum, '04x'))
