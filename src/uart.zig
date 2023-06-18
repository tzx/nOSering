const fmt = @import("std").fmt;
const Writer = @import("std").io.Writer;

// Resource: https://www.lammertbies.nl/comm/info/serial-uart#LCR

const UART_BASE_ADDRESS = 0x1000_0000;

pub fn uartInit() void {
    var uart = @intToPtr([*]volatile u8, UART_BASE_ADDRESS)[0..8];

    // Set DLAB = 1
    uart[3] = 0b1000_0000;

    // Set baud rate to 38,400 bps
    uart[0] = 0x03;
    uart[1] = 0x00;

    // Set DLAB = 0 and LCR: 8 data bits, one stop bit, no parity
    uart[3] = 0b0000_0011;

    // Enable transmit and receive interrupts
    uart[1] = 0b0000_0011;
}

fn uartPutc(base_addr: usize, c: u8) void {
    var uart = @intToPtr([*]volatile u8, base_addr)[0..8];

    // Wait for LSR Bit 5 to say that the THR is empty
    while (uart[5] & 1 << 5 == 0) {}
    uart[0] = c;
}

fn uartGetc(base_addr: usize) ?u8 {
    var uart = @intToPtr([*]volatile u8, base_addr)[0..8];
    // There's a character
    if (uart[5] & 1 != 0) {
        return uart[0];
    }
    return null;
}

pub fn handleUartIntr() void {
    while (uartGetc(UART_BASE_ADDRESS)) |c_| {
        const c = if (c_ == '\r') '\n' else c_;
        if (c == 0x7f) { // backspace or delete
            // We do a destructive backspace
            print(&[3]u8{ 0x08, ' ', 0x08 });
        } else {
            uartPutc(UART_BASE_ADDRESS, c);
        }
    }
}

// TODO: move this to own file

fn print(str: []const u8) void {
    for (str) |c| {
        uartPutc(UART_BASE_ADDRESS, c);
    }
}

pub const writer = Writer(void, error{}, callback){ .context = {} };

fn callback(_: void, string: []const u8) error{}!usize {
    print(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}
