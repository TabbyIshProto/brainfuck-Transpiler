pub const int_size: u8 = 12;
pub const ident_char_cap = 63;
pub const selected_mode = mode.extended;

const mode = enum {
    strict,
    default,
    extended,
    all,
};
