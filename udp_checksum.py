import struct

def compute_udp_checksum(source_ip, dest_ip, udp_length, source_port, dest_port, data):
    """
    Compute the UDP checksum given the source and destination IP addresses,
    UDP segment length, source and destination ports, and data.
    """

    # Prepare the pseudo-header
    pseudo_header = struct.pack('!4s4sBBH', 
                                source_ip, 
                                dest_ip, 
                                0, 
                                17,  # protocol number for UDP
                                udp_length)

    # Prepare the UDP header
    udp_header = struct.pack('!HHHH', 
                             source_port, 
                             dest_port, 
                             udp_length, 
                             0)  # Checksum initially zero

    # Calculate the total length and pad with zero byte if necessary for even number of bytes
    total_length = len(udp_header) + len(data)
    if total_length % 2 == 1:
        data += b'\x00'

    # Calculate the checksum including pseudo-header, UDP header, and data
    checksum = 0
    for i in range(0, len(pseudo_header), 2):
        checksum += int.from_bytes(pseudo_header[i:i+2], byteorder='big')
    for i in range(0, len(udp_header), 2):
        checksum += int.from_bytes(udp_header[i:i+2], byteorder='big')
    for i in range(0, len(data), 2):
        checksum += int.from_bytes(data[i:i+2], byteorder='big')

    # Add overflow and take one's complement
    checksum = (checksum >> 16) + (checksum & 0xFFFF)
    checksum += checksum >> 16
    checksum = ~checksum & 0xFFFF

    return checksum

# Example usage
source_ip = struct.pack('!4B', 192, 168, 1, 1)   # 192.168.1.1
dest_ip = struct.pack('!4B', 192, 168, 1, 2)     # 192.168.1.2
udp_length = 16  # UDP header + data
source_port = 12345
dest_port = 80
data = b'hello world\x00\x00\x00'  # padding to make even if needed

checksum = compute_udp_checksum(source_ip, dest_ip, udp_length, source_port, dest_port, data)
print(f'UDP checksum: {checksum:04x}')
