const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;

const Allocator = std.mem.Allocator;

pub const max_lockout_history: u64 = 31;
pub const poll_for_signature_timeout_ms: u64 = 15_000;
pub const poll_for_signature_confirmation_timeout_ms: u64 = 20_000;
pub const signature_poll_interval_ms: u64 = 250;
pub const default_balance_poll_timeout_ms: u64 = 1_000;
pub const default_balance_poll_interval_ms: u64 = 100;
pub const get_new_latest_blockhash_timeout_ms: u64 = 5_000;
pub const get_new_latest_blockhash_interval_ms: u64 = 400;
pub const wait_for_balance_error_retries: usize = 30;

const base58_alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
const base58_inverse = init: {
    var table = [_]i16{-1} ** 256;
    for (base58_alphabet, 0..) |ch, index| {
        table[ch] = @intCast(index);
    }
    break :init table;
};

pub const RpcError = error{
    HttpError,
    RpcError,
    InvalidResponse,
    AccountDataUnavailable,
    AccountNotFound,
    Timeout,
    TransactionFailed,
    TransactionNotConfirmed,
    TransactionNotFound,
    BlockhashExpired,
};

pub const SdkError = error{
    InvalidBase58Character,
    InvalidBase58Length,
    InvalidSecretKeyLength,
    MissingSigner,
    TooManyAccountKeys,
    InstructionAccountNotFound,
};

fn base58Value(byte: u8) SdkError!u8 {
    const value = base58_inverse[byte];
    if (value < 0) return error.InvalidBase58Character;
    return @intCast(value);
}

pub fn decodeBase58(allocator: Allocator, encoded: []const u8) ![]u8 {
    const trimmed = std.mem.trim(u8, encoded, " \n\r\t");
    if (trimmed.len == 0) return error.InvalidBase58Length;

    var leading_zeroes: usize = 0;
    for (trimmed) |byte| {
        if (byte == '1') {
            leading_zeroes += 1;
        } else {
            break;
        }
    }

    var decoded = std.ArrayList(u8).empty;
    errdefer decoded.deinit(allocator);

    for (trimmed) |byte| {
        var carry: u64 = try base58Value(byte);
        var index: usize = 0;
        while (index < decoded.items.len) : (index += 1) {
            const current = @as(u64, decoded.items[index]) * 58 + carry;
            decoded.items[index] = @truncate(current);
            carry = current >> 8;
        }
        while (carry > 0) {
            try decoded.append(allocator, @truncate(carry));
            carry >>= 8;
        }
    }

    if (decoded.items.len == 0) {
        const result = try allocator.alloc(u8, leading_zeroes);
        @memset(result, 0);
        return result;
    }

    const reversed = try decoded.toOwnedSlice(allocator);
    defer allocator.free(reversed);

    const result = try allocator.alloc(u8, reversed.len + leading_zeroes);
    @memset(result[0..leading_zeroes], 0);

    var output_index: usize = leading_zeroes;
    var reversed_index = reversed.len;
    while (reversed_index > 0) : (reversed_index -= 1) {
        result[output_index] = reversed[reversed_index - 1];
        output_index += 1;
    }

    return result;
}

pub fn decodeBase58WithLength(allocator: Allocator, encoded: []const u8, expected_len: usize) ![]u8 {
    const decoded = try decodeBase58(allocator, encoded);
    if (decoded.len != expected_len) {
        allocator.free(decoded);
        return error.InvalidBase58Length;
    }
    return decoded;
}

pub fn encodeBase58(allocator: Allocator, bytes: []const u8) ![]u8 {
    var leading_zeroes: usize = 0;
    while (leading_zeroes < bytes.len and bytes[leading_zeroes] == 0) : (leading_zeroes += 1) {}

    var digits = std.ArrayList(u8).empty;
    defer digits.deinit(allocator);

    for (bytes) |byte| {
        var carry: u32 = byte;
        var index: usize = 0;
        while (index < digits.items.len) : (index += 1) {
            const value = @as(u32, digits.items[index]) * 256 + carry;
            digits.items[index] = @intCast(value % 58);
            carry = value / 58;
        }
        while (carry > 0) {
            try digits.append(allocator, @intCast(carry % 58));
            carry /= 58;
        }
    }

    var encoded = std.ArrayList(u8).empty;
    errdefer encoded.deinit(allocator);

    for (0..leading_zeroes) |_| {
        try encoded.append(allocator, '1');
    }

    var index = digits.items.len;
    while (index > 0) : (index -= 1) {
        try encoded.append(allocator, base58_alphabet[digits.items[index - 1]]);
    }

    return try encoded.toOwnedSlice(allocator);
}

pub fn writeCompactVecLen(bytes: *std.ArrayList(u8), allocator: Allocator, value: usize) !void {
    var remaining = value;
    while (remaining >= 0x80) {
        try bytes.append(allocator, @as(u8, @truncate((remaining & 0x7f) | 0x80)));
        remaining >>= 7;
    }
    try bytes.append(allocator, @as(u8, @truncate(remaining)));
}

pub fn encodeBase64(allocator: Allocator, bytes: []const u8) ![]u8 {
    const encoded = try allocator.alloc(u8, std.base64.standard.Encoder.calcSize(bytes.len));
    _ = std.base64.standard.Encoder.encode(encoded, bytes);
    return encoded;
}

pub const Pubkey = struct {
    bytes: [Ed25519.PublicKey.encoded_length]u8,

    pub fn fromBytes(bytes: [Ed25519.PublicKey.encoded_length]u8) Pubkey {
        return .{ .bytes = bytes };
    }

    pub fn fromSlice(bytes: []const u8) !Pubkey {
        if (bytes.len != Ed25519.PublicKey.encoded_length) return error.InvalidBase58Length;
        var value: [Ed25519.PublicKey.encoded_length]u8 = undefined;
        @memcpy(value[0..], bytes);
        return .{ .bytes = value };
    }

    pub fn fromBase58(allocator: Allocator, encoded: []const u8) !Pubkey {
        const decoded = try decodeBase58WithLength(allocator, encoded, Ed25519.PublicKey.encoded_length);
        defer allocator.free(decoded);
        return try fromSlice(decoded);
    }

    pub fn toBase58(self: Pubkey, allocator: Allocator) ![]u8 {
        return try encodeBase58(allocator, &self.bytes);
    }

    pub fn eql(self: Pubkey, other: Pubkey) bool {
        return std.mem.eql(u8, self.bytes[0..], other.bytes[0..]);
    }
};

pub const Hash = struct {
    bytes: [32]u8,

    pub fn fromBytes(bytes: [32]u8) Hash {
        return .{ .bytes = bytes };
    }

    pub fn fromSlice(bytes: []const u8) !Hash {
        if (bytes.len != 32) return error.InvalidBase58Length;
        var value: [32]u8 = undefined;
        @memcpy(value[0..], bytes);
        return .{ .bytes = value };
    }

    pub fn fromBase58(allocator: Allocator, encoded: []const u8) !Hash {
        const decoded = try decodeBase58WithLength(allocator, encoded, 32);
        defer allocator.free(decoded);
        return try fromSlice(decoded);
    }

    pub fn toBase58(self: Hash, allocator: Allocator) ![]u8 {
        return try encodeBase58(allocator, &self.bytes);
    }
};

pub const Signature = struct {
    bytes: [Ed25519.Signature.encoded_length]u8,

    pub fn fromBytes(bytes: [Ed25519.Signature.encoded_length]u8) Signature {
        return .{ .bytes = bytes };
    }

    pub fn toBase58(self: Signature, allocator: Allocator) ![]u8 {
        return try encodeBase58(allocator, &self.bytes);
    }
};

pub const Keypair = struct {
    secret_key: [Ed25519.SecretKey.encoded_length]u8,
    public_key: Pubkey,

    pub fn fromSecretKeyBytes(secret_key: [Ed25519.SecretKey.encoded_length]u8) !Keypair {
        const key_pair = try Ed25519.KeyPair.fromSecretKey(try Ed25519.SecretKey.fromBytes(secret_key));
        return .{
            .secret_key = secret_key,
            .public_key = Pubkey.fromBytes(key_pair.public_key.toBytes()),
        };
    }

    pub fn fromSecretKeySlice(secret_key: []const u8) !Keypair {
        if (secret_key.len != Ed25519.SecretKey.encoded_length) return error.InvalidSecretKeyLength;
        var value: [Ed25519.SecretKey.encoded_length]u8 = undefined;
        @memcpy(value[0..], secret_key);
        return try fromSecretKeyBytes(value);
    }

    pub fn fromBase58SecretKey(allocator: Allocator, encoded: []const u8) !Keypair {
        const decoded = try decodeBase58WithLength(allocator, encoded, Ed25519.SecretKey.encoded_length);
        defer allocator.free(decoded);
        return try fromSecretKeySlice(decoded);
    }

    fn raw(self: Keypair) !Ed25519.KeyPair {
        return try Ed25519.KeyPair.fromSecretKey(try Ed25519.SecretKey.fromBytes(self.secret_key));
    }

    pub fn signMessage(self: Keypair, message: []const u8) !Signature {
        const key_pair = try self.raw();
        const signature = try Ed25519.KeyPair.sign(key_pair, message, null);
        return Signature.fromBytes(signature.toBytes());
    }
};

pub const AccountMeta = struct {
    pubkey: Pubkey,
    is_signer: bool,
    is_writable: bool,

    pub fn init(pubkey: Pubkey, is_signer: bool, is_writable: bool) AccountMeta {
        return .{
            .pubkey = pubkey,
            .is_signer = is_signer,
            .is_writable = is_writable,
        };
    }
};

pub const Instruction = struct {
    program_id: Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
};

pub const OwnedInstructions = struct {
    instructions: []Instruction,

    pub fn deinit(self: *OwnedInstructions, allocator: Allocator) void {
        for (self.instructions) |instruction| {
            allocator.free(instruction.accounts);
            allocator.free(instruction.data);
        }
        allocator.free(self.instructions);
        self.* = undefined;
    }
};

pub const LegacyMessageHeader = struct {
    num_required_signatures: u8,
    num_readonly_signed_accounts: u8,
    num_readonly_unsigned_accounts: u8,
};

pub const LegacyMessage = struct {
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,

    pub fn serialize(self: LegacyMessage, allocator: Allocator) ![]u8 {
        const compiled = try compileLegacyMessageBytes(allocator, self);
        allocator.free(compiled.account_keys);
        return compiled.bytes;
    }

    pub fn toBase64(self: LegacyMessage, allocator: Allocator) ![]u8 {
        const bytes = try self.serialize(allocator);
        defer allocator.free(bytes);
        return try encodeBase64(allocator, bytes);
    }

    pub fn sign(self: LegacyMessage, allocator: Allocator, signers: []const Keypair) !SignedLegacyTransaction {
        const compiled = try compileLegacyMessageBytes(allocator, self);
        errdefer allocator.free(compiled.bytes);
        errdefer allocator.free(compiled.account_keys);

        const signatures = try signCompiledLegacyMessage(allocator, compiled, signers);
        allocator.free(compiled.account_keys);

        return .{
            .signatures = signatures,
            .message_bytes = compiled.bytes,
        };
    }
};

pub const OwnedLegacyMessage = struct {
    message: LegacyMessage,
    owned_instructions: []Instruction,

    pub fn deinit(self: *OwnedLegacyMessage, allocator: Allocator) void {
        freeInstructionClones(allocator, self.owned_instructions, self.owned_instructions.len);
        self.* = undefined;
    }

    pub fn serialize(self: OwnedLegacyMessage, allocator: Allocator) ![]u8 {
        return try self.message.serialize(allocator);
    }

    pub fn toBase64(self: OwnedLegacyMessage, allocator: Allocator) ![]u8 {
        return try self.message.toBase64(allocator);
    }

    pub fn sign(self: OwnedLegacyMessage, allocator: Allocator, signers: []const Keypair) !SignedLegacyTransaction {
        return try self.message.sign(allocator, signers);
    }

    pub fn transaction(self: OwnedLegacyMessage) LegacyTransaction {
        return .{ .message = self.message };
    }
};

pub const LegacyTransaction = struct {
    message: LegacyMessage,

    pub fn sign(self: LegacyTransaction, allocator: Allocator, signers: []const Keypair) !SignedLegacyTransaction {
        return try self.message.sign(allocator, signers);
    }

    pub fn serialize(self: LegacyTransaction, allocator: Allocator, signers: []const Keypair) ![]u8 {
        var signed = try self.sign(allocator, signers);
        defer signed.deinit(allocator);
        return try signed.serialize(allocator);
    }

    pub fn toBase64(self: LegacyTransaction, allocator: Allocator, signers: []const Keypair) ![]u8 {
        var signed = try self.sign(allocator, signers);
        defer signed.deinit(allocator);
        return try signed.toBase64(allocator);
    }
};

pub const SignedLegacyTransaction = struct {
    signatures: []Signature,
    message_bytes: []u8,

    pub fn deinit(self: *SignedLegacyTransaction, allocator: Allocator) void {
        allocator.free(self.signatures);
        allocator.free(self.message_bytes);
        self.* = undefined;
    }

    pub fn serialize(self: SignedLegacyTransaction, allocator: Allocator) ![]u8 {
        var transaction = std.ArrayList(u8).empty;
        errdefer transaction.deinit(allocator);

        try writeCompactVecLen(&transaction, allocator, self.signatures.len);
        for (self.signatures) |signature| {
            try transaction.appendSlice(allocator, &signature.bytes);
        }
        try transaction.appendSlice(allocator, self.message_bytes);

        return try transaction.toOwnedSlice(allocator);
    }

    pub fn toBase64(self: SignedLegacyTransaction, allocator: Allocator) ![]u8 {
        const bytes = try self.serialize(allocator);
        defer allocator.free(bytes);
        return try encodeBase64(allocator, bytes);
    }

    pub fn firstSignature(self: SignedLegacyTransaction) ?Signature {
        if (self.signatures.len == 0) return null;
        return self.signatures[0];
    }
};

pub const CompiledInstruction = struct {
    program_id_index: u8,
    account_indexes: []const u8,
    data: []const u8,
};

pub const MessageAddressTableLookup = struct {
    account_key: Pubkey,
    writable_indexes: []const u8,
    readonly_indexes: []const u8,
};

pub const AddressLookupTableAccount = struct {
    account_key: Pubkey,
    addresses: []const Pubkey,

    pub fn findAddressIndex(self: AddressLookupTableAccount, target: Pubkey) !?u8 {
        for (self.addresses, 0..) |address, index| {
            if (!address.eql(target)) continue;
            if (index > std.math.maxInt(u8)) return error.TooManyLookupTableAddresses;
            return @intCast(index);
        }
        return null;
    }
};

pub const VersionedMessageV0 = struct {
    header: LegacyMessageHeader,
    account_keys: []const Pubkey,
    recent_blockhash: Hash,
    instructions: []const CompiledInstruction,
    address_table_lookups: []const MessageAddressTableLookup,

    pub fn compile(
        allocator: Allocator,
        payer: Pubkey,
        recent_blockhash: Hash,
        instructions: []const Instruction,
        address_lookup_tables: []const AddressLookupTableAccount,
    ) !OwnedVersionedMessageV0 {
        return try compileVersionedMessageV0(
            allocator,
            payer,
            recent_blockhash,
            instructions,
            address_lookup_tables,
        );
    }

    pub fn serialize(self: VersionedMessageV0, allocator: Allocator) ![]u8 {
        var serialized = std.ArrayList(u8).empty;
        errdefer serialized.deinit(allocator);

        try serialized.append(allocator, 0x80);
        try serialized.append(allocator, self.header.num_required_signatures);
        try serialized.append(allocator, self.header.num_readonly_signed_accounts);
        try serialized.append(allocator, self.header.num_readonly_unsigned_accounts);

        try writeCompactVecLen(&serialized, allocator, self.account_keys.len);
        for (self.account_keys) |account_key| {
            try serialized.appendSlice(allocator, &account_key.bytes);
        }

        try serialized.appendSlice(allocator, &self.recent_blockhash.bytes);

        try writeCompactVecLen(&serialized, allocator, self.instructions.len);
        for (self.instructions) |instruction| {
            try serialized.append(allocator, instruction.program_id_index);
            try writeCompactVecLen(&serialized, allocator, instruction.account_indexes.len);
            try serialized.appendSlice(allocator, instruction.account_indexes);
            try writeCompactVecLen(&serialized, allocator, instruction.data.len);
            try serialized.appendSlice(allocator, instruction.data);
        }

        try writeCompactVecLen(&serialized, allocator, self.address_table_lookups.len);
        for (self.address_table_lookups) |lookup| {
            try serialized.appendSlice(allocator, &lookup.account_key.bytes);
            try writeCompactVecLen(&serialized, allocator, lookup.writable_indexes.len);
            try serialized.appendSlice(allocator, lookup.writable_indexes);
            try writeCompactVecLen(&serialized, allocator, lookup.readonly_indexes.len);
            try serialized.appendSlice(allocator, lookup.readonly_indexes);
        }

        return try serialized.toOwnedSlice(allocator);
    }

    pub fn toBase64(self: VersionedMessageV0, allocator: Allocator) ![]u8 {
        const bytes = try self.serialize(allocator);
        defer allocator.free(bytes);
        return try encodeBase64(allocator, bytes);
    }

    pub fn sign(self: VersionedMessageV0, allocator: Allocator, signers: []const Keypair) !SignedVersionedTransaction {
        const message_bytes = try self.serialize(allocator);
        errdefer allocator.free(message_bytes);

        const signatures = try signStaticAccountKeys(
            allocator,
            self.header,
            self.account_keys,
            message_bytes,
            signers,
        );

        return .{
            .signatures = signatures,
            .message_bytes = message_bytes,
        };
    }
};

pub const OwnedVersionedMessageV0 = struct {
    message: VersionedMessageV0,

    pub fn deinit(self: *OwnedVersionedMessageV0, allocator: Allocator) void {
        allocator.free(self.message.account_keys);
        for (self.message.instructions) |instruction| {
            allocator.free(instruction.account_indexes);
            allocator.free(instruction.data);
        }
        allocator.free(self.message.instructions);
        for (self.message.address_table_lookups) |lookup| {
            allocator.free(lookup.writable_indexes);
            allocator.free(lookup.readonly_indexes);
        }
        allocator.free(self.message.address_table_lookups);
        self.* = undefined;
    }

    pub fn serialize(self: OwnedVersionedMessageV0, allocator: Allocator) ![]u8 {
        return try self.message.serialize(allocator);
    }

    pub fn toBase64(self: OwnedVersionedMessageV0, allocator: Allocator) ![]u8 {
        return try self.message.toBase64(allocator);
    }

    pub fn sign(self: OwnedVersionedMessageV0, allocator: Allocator, signers: []const Keypair) !SignedVersionedTransaction {
        return try self.message.sign(allocator, signers);
    }
};

pub const VersionedTransaction = struct {
    message: VersionedMessageV0,

    pub fn sign(self: VersionedTransaction, allocator: Allocator, signers: []const Keypair) !SignedVersionedTransaction {
        return try self.message.sign(allocator, signers);
    }

    pub fn serialize(self: VersionedTransaction, allocator: Allocator, signers: []const Keypair) ![]u8 {
        var signed = try self.sign(allocator, signers);
        defer signed.deinit(allocator);
        return try signed.serialize(allocator);
    }

    pub fn toBase64(self: VersionedTransaction, allocator: Allocator, signers: []const Keypair) ![]u8 {
        var signed = try self.sign(allocator, signers);
        defer signed.deinit(allocator);
        return try signed.toBase64(allocator);
    }
};

pub const SignedVersionedTransaction = struct {
    signatures: []Signature,
    message_bytes: []u8,

    pub fn deinit(self: *SignedVersionedTransaction, allocator: Allocator) void {
        allocator.free(self.signatures);
        allocator.free(self.message_bytes);
        self.* = undefined;
    }

    pub fn serialize(self: SignedVersionedTransaction, allocator: Allocator) ![]u8 {
        var transaction = std.ArrayList(u8).empty;
        errdefer transaction.deinit(allocator);

        try writeCompactVecLen(&transaction, allocator, self.signatures.len);
        for (self.signatures) |signature| {
            try transaction.appendSlice(allocator, &signature.bytes);
        }
        try transaction.appendSlice(allocator, self.message_bytes);

        return try transaction.toOwnedSlice(allocator);
    }

    pub fn toBase64(self: SignedVersionedTransaction, allocator: Allocator) ![]u8 {
        const bytes = try self.serialize(allocator);
        defer allocator.free(bytes);
        return try encodeBase64(allocator, bytes);
    }

    pub fn firstSignature(self: SignedVersionedTransaction) ?Signature {
        if (self.signatures.len == 0) return null;
        return self.signatures[0];
    }
};

pub const TransferInstruction = struct {
    accounts: [2]AccountMeta,
    data: [9]u8,

    pub fn instruction(self: *const TransferInstruction) Instruction {
        return .{
            .program_id = SystemProgram.id(),
            .accounts = self.accounts[0..],
            .data = self.data[0..],
        };
    }
};

pub const NonceAdvanceInstruction = struct {
    accounts: [3]AccountMeta,
    data: [1]u8,

    pub fn instruction(self: *const NonceAdvanceInstruction) Instruction {
        return .{
            .program_id = SystemProgram.id(),
            .accounts = self.accounts[0..],
            .data = self.data[0..],
        };
    }
};

pub const NonceWithdrawInstruction = struct {
    accounts: [5]AccountMeta,
    data: [9]u8,

    pub fn instruction(self: *const NonceWithdrawInstruction) Instruction {
        return .{
            .program_id = SystemProgram.id(),
            .accounts = self.accounts[0..],
            .data = self.data[0..],
        };
    }
};

pub const NonceInitializeInstruction = struct {
    accounts: [3]AccountMeta,
    data: [33]u8,

    pub fn instruction(self: *const NonceInitializeInstruction) Instruction {
        return .{
            .program_id = SystemProgram.id(),
            .accounts = self.accounts[0..],
            .data = self.data[0..],
        };
    }
};

pub const NonceAuthorizeInstruction = struct {
    accounts: [2]AccountMeta,
    data: [33]u8,

    pub fn instruction(self: *const NonceAuthorizeInstruction) Instruction {
        return .{
            .program_id = SystemProgram.id(),
            .accounts = self.accounts[0..],
            .data = self.data[0..],
        };
    }
};

pub const Sysvar = struct {
    pub const recent_blockhashes_base58 = "SysvarRecentB1ockHashes11111111111111111111";
    pub const rent_base58 = "SysvarRent111111111111111111111111111111111";

    pub fn recentBlockhashes(allocator: Allocator) !Pubkey {
        return try Pubkey.fromBase58(allocator, recent_blockhashes_base58);
    }

    pub fn rent(allocator: Allocator) !Pubkey {
        return try Pubkey.fromBase58(allocator, rent_base58);
    }
};

pub const SystemProgram = struct {
    pub fn id() Pubkey {
        return Pubkey.fromBytes(.{0} ** Ed25519.PublicKey.encoded_length);
    }

    pub fn transfer(from: Pubkey, to: Pubkey, lamports: u64) TransferInstruction {
        var instruction_data = [_]u8{2} ++ [_]u8{0} ** 8;
        std.mem.writeInt(u64, instruction_data[1..9], lamports, .little);

        return .{
            .accounts = .{
                AccountMeta.init(from, true, true),
                AccountMeta.init(to, false, true),
            },
            .data = instruction_data,
        };
    }

    pub fn advanceNonceAccount(
        allocator: Allocator,
        nonce_account: Pubkey,
        authority: Pubkey,
    ) !NonceAdvanceInstruction {
        return .{
            .accounts = .{
                AccountMeta.init(nonce_account, false, true),
                AccountMeta.init(try Sysvar.recentBlockhashes(allocator), false, false),
                AccountMeta.init(authority, true, false),
            },
            .data = .{4},
        };
    }

    pub fn withdrawNonceAccount(
        allocator: Allocator,
        nonce_account: Pubkey,
        recipient: Pubkey,
        authority: Pubkey,
        lamports: u64,
    ) !NonceWithdrawInstruction {
        var instruction_data = [_]u8{5} ++ [_]u8{0} ** 8;
        std.mem.writeInt(u64, instruction_data[1..9], lamports, .little);

        return .{
            .accounts = .{
                AccountMeta.init(nonce_account, false, true),
                AccountMeta.init(recipient, false, true),
                AccountMeta.init(try Sysvar.recentBlockhashes(allocator), false, false),
                AccountMeta.init(try Sysvar.rent(allocator), false, false),
                AccountMeta.init(authority, true, false),
            },
            .data = instruction_data,
        };
    }

    pub fn initializeNonceAccount(
        allocator: Allocator,
        nonce_account: Pubkey,
        authority: Pubkey,
    ) !NonceInitializeInstruction {
        var instruction_data = [_]u8{6} ++ [_]u8{0} ** Ed25519.PublicKey.encoded_length;
        @memcpy(instruction_data[1 .. 1 + authority.bytes.len], authority.bytes[0..]);

        return .{
            .accounts = .{
                AccountMeta.init(nonce_account, false, true),
                AccountMeta.init(try Sysvar.recentBlockhashes(allocator), false, false),
                AccountMeta.init(try Sysvar.rent(allocator), false, false),
            },
            .data = instruction_data,
        };
    }

    pub fn authorizeNonceAccount(
        nonce_account: Pubkey,
        authority: Pubkey,
        new_authority: Pubkey,
    ) NonceAuthorizeInstruction {
        var instruction_data = [_]u8{7} ++ [_]u8{0} ** Ed25519.PublicKey.encoded_length;
        @memcpy(instruction_data[1 .. 1 + new_authority.bytes.len], new_authority.bytes[0..]);

        return .{
            .accounts = .{
                AccountMeta.init(nonce_account, false, true),
                AccountMeta.init(authority, true, false),
            },
            .data = instruction_data,
        };
    }
};

fn freeInstructionClones(allocator: Allocator, instructions: []Instruction, initialized_len: usize) void {
    for (instructions[0..initialized_len]) |instruction| {
        allocator.free(instruction.accounts);
        allocator.free(instruction.data);
    }
    allocator.free(instructions);
}

fn cloneInstruction(allocator: Allocator, instruction: Instruction) !Instruction {
    return .{
        .program_id = instruction.program_id,
        .accounts = try allocator.dupe(AccountMeta, instruction.accounts),
        .data = try allocator.dupe(u8, instruction.data),
    };
}

pub fn cloneInstructions(allocator: Allocator, instructions: []const Instruction) !OwnedInstructions {
    const cloned = try allocator.alloc(Instruction, instructions.len);
    var initialized_len: usize = 0;
    errdefer freeInstructionClones(allocator, cloned, initialized_len);

    for (instructions, 0..) |instruction, index| {
        cloned[index] = try cloneInstruction(allocator, instruction);
        initialized_len += 1;
    }

    return .{ .instructions = cloned };
}

pub fn prependNonceAdvanceInstruction(
    allocator: Allocator,
    nonce_account: Pubkey,
    authority: Pubkey,
    instructions: []const Instruction,
) !OwnedInstructions {
    const cloned = try allocator.alloc(Instruction, instructions.len + 1);
    var initialized_len: usize = 0;
    errdefer freeInstructionClones(allocator, cloned, initialized_len);

    const advance = try SystemProgram.advanceNonceAccount(allocator, nonce_account, authority);
    cloned[0] = try cloneInstruction(allocator, advance.instruction());
    initialized_len = 1;

    for (instructions, 0..) |instruction, index| {
        cloned[index + 1] = try cloneInstruction(allocator, instruction);
        initialized_len += 1;
    }

    return .{ .instructions = cloned };
}

const CompiledLegacyMessage = struct {
    header: LegacyMessageHeader,
    account_keys: []Pubkey,
    bytes: []u8,
};

const LookupBuildState = struct {
    account_key: Pubkey,
    writable_indexes: std.ArrayList(u8),
    writable_addresses: std.ArrayList(Pubkey),
    readonly_indexes: std.ArrayList(u8),
    readonly_addresses: std.ArrayList(Pubkey),

    fn init(account_key: Pubkey) LookupBuildState {
        return .{
            .account_key = account_key,
            .writable_indexes = .empty,
            .writable_addresses = .empty,
            .readonly_indexes = .empty,
            .readonly_addresses = .empty,
        };
    }

    fn deinit(self: *LookupBuildState, allocator: Allocator) void {
        self.writable_indexes.deinit(allocator);
        self.writable_addresses.deinit(allocator);
        self.readonly_indexes.deinit(allocator);
        self.readonly_addresses.deinit(allocator);
    }

    fn append(
        self: *LookupBuildState,
        allocator: Allocator,
        pubkey: Pubkey,
        address_index: u8,
        is_writable: bool,
    ) !void {
        if (containsPubkey(self.writable_addresses.items, pubkey) or containsPubkey(self.readonly_addresses.items, pubkey)) {
            return;
        }

        if (is_writable) {
            try self.writable_addresses.append(allocator, pubkey);
            try self.writable_indexes.append(allocator, address_index);
            return;
        }

        try self.readonly_addresses.append(allocator, pubkey);
        try self.readonly_indexes.append(allocator, address_index);
    }
};

const ResolvedLookupAddress = struct {
    table_index: usize,
    address_index: u8,
};

fn appendOrMergeAccountMeta(
    metas: *std.ArrayList(AccountMeta),
    allocator: Allocator,
    meta: AccountMeta,
) !void {
    for (metas.items) |*existing| {
        if (existing.pubkey.eql(meta.pubkey)) {
            existing.is_signer = existing.is_signer or meta.is_signer;
            existing.is_writable = existing.is_writable or meta.is_writable;
            return;
        }
    }

    try metas.append(allocator, meta);
}

fn accountMetaGroup(meta: AccountMeta) u8 {
    if (meta.is_signer and meta.is_writable) return 0;
    if (meta.is_signer and !meta.is_writable) return 1;
    if (!meta.is_signer and meta.is_writable) return 2;
    return 3;
}

fn findPubkeyIndex(keys: []const Pubkey, target: Pubkey) !u8 {
    for (keys, 0..) |key, index| {
        if (key.eql(target)) return @intCast(index);
    }
    return error.InstructionAccountNotFound;
}

fn containsPubkey(keys: []const Pubkey, target: Pubkey) bool {
    for (keys) |key| {
        if (key.eql(target)) return true;
    }
    return false;
}

fn collectOrderedAccountMetas(
    allocator: Allocator,
    payer: Pubkey,
    instructions: []const Instruction,
) ![]AccountMeta {
    var collected_metas = std.ArrayList(AccountMeta).empty;
    defer collected_metas.deinit(allocator);

    try appendOrMergeAccountMeta(&collected_metas, allocator, AccountMeta.init(payer, true, true));

    for (instructions) |instruction| {
        for (instruction.accounts) |account| {
            try appendOrMergeAccountMeta(&collected_metas, allocator, account);
        }
        try appendOrMergeAccountMeta(&collected_metas, allocator, AccountMeta.init(instruction.program_id, false, false));
    }

    if (collected_metas.items.len > std.math.maxInt(u8)) return error.TooManyAccountKeys;

    var ordered_metas = std.ArrayList(AccountMeta).empty;
    errdefer ordered_metas.deinit(allocator);

    for (0..4) |group| {
        for (collected_metas.items) |meta| {
            if (accountMetaGroup(meta) == group) {
                try ordered_metas.append(allocator, meta);
            }
        }
    }

    return try ordered_metas.toOwnedSlice(allocator);
}

fn compileLegacyMessageBytes(allocator: Allocator, message: LegacyMessage) !CompiledLegacyMessage {
    const ordered_meta_slice = try collectOrderedAccountMetas(
        allocator,
        message.payer,
        message.instructions,
    );
    defer allocator.free(ordered_meta_slice);

    const account_keys = try allocator.alloc(Pubkey, ordered_meta_slice.len);
    errdefer allocator.free(account_keys);

    var header = LegacyMessageHeader{
        .num_required_signatures = 0,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };

    for (ordered_meta_slice, 0..) |meta, index| {
        account_keys[index] = meta.pubkey;
        if (meta.is_signer) {
            header.num_required_signatures += 1;
            if (!meta.is_writable) header.num_readonly_signed_accounts += 1;
        } else if (!meta.is_writable) {
            header.num_readonly_unsigned_accounts += 1;
        }
    }

    var serialized = std.ArrayList(u8).empty;
    errdefer serialized.deinit(allocator);

    try serialized.append(allocator, header.num_required_signatures);
    try serialized.append(allocator, header.num_readonly_signed_accounts);
    try serialized.append(allocator, header.num_readonly_unsigned_accounts);

    try writeCompactVecLen(&serialized, allocator, account_keys.len);
    for (account_keys) |account_key| {
        try serialized.appendSlice(allocator, &account_key.bytes);
    }

    try serialized.appendSlice(allocator, &message.recent_blockhash.bytes);

    try writeCompactVecLen(&serialized, allocator, message.instructions.len);
    for (message.instructions) |instruction| {
        try serialized.append(allocator, try findPubkeyIndex(account_keys, instruction.program_id));
        try writeCompactVecLen(&serialized, allocator, instruction.accounts.len);
        for (instruction.accounts) |account| {
            try serialized.append(allocator, try findPubkeyIndex(account_keys, account.pubkey));
        }
        try writeCompactVecLen(&serialized, allocator, instruction.data.len);
        try serialized.appendSlice(allocator, instruction.data);
    }

    return .{
        .header = header,
        .account_keys = account_keys,
        .bytes = try serialized.toOwnedSlice(allocator),
    };
}

fn instructionUsesProgramId(instructions: []const Instruction, target: Pubkey) bool {
    for (instructions) |instruction| {
        if (instruction.program_id.eql(target)) return true;
    }
    return false;
}

fn resolveLookupAddress(
    address_lookup_tables: []const AddressLookupTableAccount,
    target: Pubkey,
) !?ResolvedLookupAddress {
    for (address_lookup_tables, 0..) |table, table_index| {
        if (try table.findAddressIndex(target)) |address_index| {
            return .{
                .table_index = table_index,
                .address_index = address_index,
            };
        }
    }
    return null;
}

fn findLoadedAccountIndex(
    lookup_states: []const LookupBuildState,
    static_account_count: usize,
    total_loaded_writable: usize,
    target: Pubkey,
) !?u8 {
    var writable_base = static_account_count;
    for (lookup_states) |state| {
        for (state.writable_addresses.items, 0..) |address, index| {
            if (!address.eql(target)) continue;
            const resolved_index = writable_base + index;
            if (resolved_index > std.math.maxInt(u8)) return error.TooManyAccountKeys;
            return @intCast(resolved_index);
        }
        writable_base += state.writable_addresses.items.len;
    }

    var readonly_base = static_account_count + total_loaded_writable;
    for (lookup_states) |state| {
        for (state.readonly_addresses.items, 0..) |address, index| {
            if (!address.eql(target)) continue;
            const resolved_index = readonly_base + index;
            if (resolved_index > std.math.maxInt(u8)) return error.TooManyAccountKeys;
            return @intCast(resolved_index);
        }
        readonly_base += state.readonly_addresses.items.len;
    }

    return null;
}

pub fn compileVersionedMessageV0(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    const ordered_metas = try collectOrderedAccountMetas(allocator, payer, instructions);
    defer allocator.free(ordered_metas);

    var static_metas = std.ArrayList(AccountMeta).empty;
    defer static_metas.deinit(allocator);

    const lookup_states = try allocator.alloc(LookupBuildState, address_lookup_tables.len);
    defer allocator.free(lookup_states);
    for (address_lookup_tables, 0..) |table, index| {
        lookup_states[index] = LookupBuildState.init(table.account_key);
    }
    defer for (lookup_states) |*state| state.deinit(allocator);

    for (ordered_metas) |meta| {
        if (!meta.is_signer and !instructionUsesProgramId(instructions, meta.pubkey)) {
            if (try resolveLookupAddress(address_lookup_tables, meta.pubkey)) |resolved| {
                try lookup_states[resolved.table_index].append(
                    allocator,
                    meta.pubkey,
                    resolved.address_index,
                    meta.is_writable,
                );
                continue;
            }
        }

        try static_metas.append(allocator, meta);
    }

    var total_loaded_writable: usize = 0;
    var total_loaded_readonly: usize = 0;
    for (lookup_states) |state| {
        total_loaded_writable += state.writable_addresses.items.len;
        total_loaded_readonly += state.readonly_addresses.items.len;
    }

    if (static_metas.items.len + total_loaded_writable + total_loaded_readonly > std.math.maxInt(u8)) {
        return error.TooManyAccountKeys;
    }

    const account_keys = try allocator.alloc(Pubkey, static_metas.items.len);
    errdefer allocator.free(account_keys);

    var header = LegacyMessageHeader{
        .num_required_signatures = 0,
        .num_readonly_signed_accounts = 0,
        .num_readonly_unsigned_accounts = 0,
    };

    for (static_metas.items, 0..) |meta, index| {
        account_keys[index] = meta.pubkey;
        if (meta.is_signer) {
            header.num_required_signatures += 1;
            if (!meta.is_writable) header.num_readonly_signed_accounts += 1;
        } else if (!meta.is_writable) {
            header.num_readonly_unsigned_accounts += 1;
        }
    }

    const compiled_instructions = try allocator.alloc(CompiledInstruction, instructions.len);
    var compiled_instruction_count: usize = 0;
    errdefer {
        for (compiled_instructions[0..compiled_instruction_count]) |instruction| {
            allocator.free(instruction.account_indexes);
            allocator.free(instruction.data);
        }
        allocator.free(compiled_instructions);
    }

    for (instructions, 0..) |instruction, instruction_index| {
        const account_indexes = try allocator.alloc(u8, instruction.accounts.len);
        errdefer allocator.free(account_indexes);

        for (instruction.accounts, 0..) |account, account_index| {
            if (findPubkeyIndex(account_keys, account.pubkey)) |resolved_index| {
                account_indexes[account_index] = resolved_index;
                continue;
            } else |_| {}

            account_indexes[account_index] = (try findLoadedAccountIndex(
                lookup_states,
                account_keys.len,
                total_loaded_writable,
                account.pubkey,
            )) orelse return error.InstructionAccountNotFound;
        }

        const instruction_data = try allocator.dupe(u8, instruction.data);
        errdefer allocator.free(instruction_data);

        compiled_instructions[instruction_index] = .{
            .program_id_index = try findPubkeyIndex(account_keys, instruction.program_id),
            .account_indexes = account_indexes,
            .data = instruction_data,
        };
        compiled_instruction_count += 1;
    }

    var compiled_lookups = std.ArrayList(MessageAddressTableLookup).empty;
    errdefer {
        for (compiled_lookups.items) |lookup| {
            allocator.free(lookup.writable_indexes);
            allocator.free(lookup.readonly_indexes);
        }
        compiled_lookups.deinit(allocator);
    }

    for (lookup_states) |*state| {
        if (state.writable_indexes.items.len == 0 and state.readonly_indexes.items.len == 0) continue;

        try compiled_lookups.append(allocator, .{
            .account_key = state.account_key,
            .writable_indexes = try state.writable_indexes.toOwnedSlice(allocator),
            .readonly_indexes = try state.readonly_indexes.toOwnedSlice(allocator),
        });
    }

    return .{
        .message = .{
            .header = header,
            .account_keys = account_keys,
            .recent_blockhash = recent_blockhash,
            .instructions = compiled_instructions,
            .address_table_lookups = try compiled_lookups.toOwnedSlice(allocator),
        },
    };
}

pub fn buildVersionedMessageV0(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try compileVersionedMessageV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn compileVersionedMessage(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try compileVersionedMessageV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn compileVersionedMessageWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

fn signCompiledLegacyMessage(
    allocator: Allocator,
    compiled: CompiledLegacyMessage,
    signers: []const Keypair,
) ![]Signature {
    return try signStaticAccountKeys(
        allocator,
        compiled.header,
        compiled.account_keys,
        compiled.bytes,
        signers,
    );
}

fn signStaticAccountKeys(
    allocator: Allocator,
    header: LegacyMessageHeader,
    account_keys: []const Pubkey,
    message_bytes: []const u8,
    signers: []const Keypair,
) ![]Signature {
    if (@as(usize, header.num_required_signatures) > account_keys.len) {
        return error.InvalidMessageHeader;
    }

    const signatures = try allocator.alloc(Signature, @as(usize, header.num_required_signatures));
    errdefer allocator.free(signatures);

    for (0..@as(usize, header.num_required_signatures)) |index| {
        const required_signer = account_keys[index];
        const signer = for (signers) |candidate| {
            if (candidate.public_key.eql(required_signer)) break candidate;
        } else return error.MissingSigner;

        signatures[index] = try signer.signMessage(message_bytes);
    }

    return signatures;
}

pub fn buildLegacyTransferMessage(
    allocator: Allocator,
    sender_public_key: [Ed25519.PublicKey.encoded_length]u8,
    destination_public_key: [Ed25519.PublicKey.encoded_length]u8,
    recent_blockhash: [32]u8,
    lamports: u64,
) ![]u8 {
    const transfer_instruction = SystemProgram.transfer(
        Pubkey.fromBytes(sender_public_key),
        Pubkey.fromBytes(destination_public_key),
        lamports,
    );
    const instructions = [_]Instruction{transfer_instruction.instruction()};
    const message = LegacyMessage{
        .payer = Pubkey.fromBytes(sender_public_key),
        .recent_blockhash = Hash.fromBytes(recent_blockhash),
        .instructions = instructions[0..],
    };

    return try message.serialize(allocator);
}

pub fn buildLegacyMessage(
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) LegacyMessage {
    return .{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions = instructions,
    };
}

pub fn buildOwnedLegacyMessage(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) !OwnedLegacyMessage {
    const owned_instructions = try cloneInstructions(allocator, instructions);
    return .{
        .message = .{
            .payer = payer,
            .recent_blockhash = recent_blockhash,
            .instructions = owned_instructions.instructions,
        },
        .owned_instructions = owned_instructions.instructions,
    };
}

pub fn compileLegacyMessage(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyMessage(
        allocator,
        payer,
        recent_blockhash,
        instructions,
    );
}

pub fn buildOwnedLegacyTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildOwnedLegacyMessage(
        allocator,
        payer,
        recent_blockhash,
        instructions[0..],
    );
}

pub fn buildLegacyTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyTransferMessageWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyMessageBytes(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) ![]u8 {
    const message = LegacyMessage{
        .payer = payer,
        .recent_blockhash = recent_blockhash,
        .instructions = instructions,
    };

    return try message.serialize(allocator);
}

pub fn buildLegacyTransferMessageBytesWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    var owned = try buildOwnedLegacyTransferMessageWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
    );
    defer owned.deinit(allocator);
    return try owned.serialize(allocator);
}

pub fn buildLegacyTransferMessageBytes(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    return try buildLegacyTransferMessageBytesWithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyMessageBase64(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) ![]u8 {
    const message_bytes = try buildLegacyMessageBytes(
        allocator,
        payer,
        recent_blockhash,
        instructions,
    );
    defer allocator.free(message_bytes);

    return try encodeBase64(allocator, message_bytes);
}

pub fn buildLegacyTransferMessageBase64WithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    const message_bytes = try buildLegacyTransferMessageBytesWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
    );
    defer allocator.free(message_bytes);
    return try encodeBase64(allocator, message_bytes);
}

pub fn buildLegacyTransferMessageBase64(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    return try buildLegacyTransferMessageBase64WithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildOwnedLegacyMessageWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) !OwnedLegacyMessage {
    const owned_instructions = try prependNonceAdvanceInstruction(
        allocator,
        nonce_account,
        nonce_authority,
        instructions,
    );
    return .{
        .message = .{
            .payer = payer,
            .recent_blockhash = recent_blockhash,
            .instructions = owned_instructions.instructions,
        },
        .owned_instructions = owned_instructions.instructions,
    };
}

pub fn compileLegacyMessageWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyMessageWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        recent_blockhash,
        instructions,
    );
}

pub fn buildLegacyMessageWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) ![]u8 {
    var owned_message = try buildOwnedLegacyMessageWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        recent_blockhash,
        instructions,
    );
    defer owned_message.deinit(allocator);

    return try owned_message.serialize(allocator);
}

pub fn buildLegacyMessageBase64WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
) ![]u8 {
    const message_bytes = try buildLegacyMessageWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        recent_blockhash,
        instructions,
    );
    defer allocator.free(message_bytes);

    return try encodeBase64(allocator, message_bytes);
}

pub fn buildLegacyTransferTransaction(
    allocator: Allocator,
    secret_key: []const u8,
    destination_public_key: []const u8,
    recent_blockhash: []const u8,
    lamports: u64,
) ![]u8 {
    const keypair = try Keypair.fromSecretKeySlice(secret_key);
    const destination = try Pubkey.fromSlice(destination_public_key);
    const blockhash = try Hash.fromSlice(recent_blockhash);

    const transfer_instruction = SystemProgram.transfer(keypair.public_key, destination, lamports);
    const instructions = [_]Instruction{transfer_instruction.instruction()};
    const transaction = LegacyTransaction{
        .message = .{
            .payer = keypair.public_key,
            .recent_blockhash = blockhash,
            .instructions = instructions[0..],
        },
    };

    var signed = try transaction.sign(allocator, &.{keypair});
    defer signed.deinit(allocator);

    return try signed.toBase64(allocator);
}

pub fn buildSignedLegacyTransaction(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    const transaction = LegacyTransaction{
        .message = .{
            .payer = payer,
            .recent_blockhash = recent_blockhash,
            .instructions = instructions,
        },
    };

    return try transaction.sign(allocator, signers);
}

pub fn buildLegacyTransaction(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    return try buildSignedLegacyTransaction(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        signers,
    );
}

pub fn buildLegacyTransactionBase64(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedLegacyTransaction(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        signers,
    );
    defer signed.deinit(allocator);

    return try signed.toBase64(allocator);
}

pub fn buildSignedLegacyTransferTransactionWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildSignedLegacyTransaction(
        allocator,
        payer,
        recent_blockhash,
        instructions[0..],
        signers,
    );
}

pub fn buildLegacyTransferTransactionWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    return try buildSignedLegacyTransferTransactionWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
}

pub fn buildLegacyTransferTransactionBase64WithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedLegacyTransferTransactionWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
    defer signed.deinit(allocator);
    return try signed.toBase64(allocator);
}

pub fn buildSignedLegacyTransactionWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    var owned_instructions = try prependNonceAdvanceInstruction(
        allocator,
        nonce_account,
        nonce_authority,
        instructions,
    );
    defer owned_instructions.deinit(allocator);

    const transaction = LegacyTransaction{
        .message = .{
            .payer = payer,
            .recent_blockhash = recent_blockhash,
            .instructions = owned_instructions.instructions,
        },
    };

    return try transaction.sign(allocator, signers);
}

pub fn buildLegacyTransactionWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    return try buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        recent_blockhash,
        instructions,
        signers,
    );
}

pub fn buildLegacyTransactionBase64WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        recent_blockhash,
        instructions,
        signers,
    );
    defer signed.deinit(allocator);

    return try signed.toBase64(allocator);
}

pub fn buildOwnedLegacyNonceTransferMessage(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildOwnedLegacyMessageWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        recent_blockhash,
        instructions[0..],
    );
}

pub fn buildOwnedLegacyNonceTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyNonceTransferMessage(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyNonceTransferMessage(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyNonceTransferMessage(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyNonceTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyNonceTransferMessageWithSender(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyTransferMessageBytesWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    return try buildLegacyNonceTransferMessageBytes(
        allocator,
        payer,
        payer,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyNonceTransferMessageBytes(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    var owned = try buildOwnedLegacyNonceTransferMessage(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
    defer owned.deinit(allocator);

    return try owned.serialize(allocator);
}

pub fn buildLegacyNonceTransferMessageBytesWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    return try buildLegacyNonceTransferMessageBytes(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyTransferMessageBase64WithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    return try buildLegacyNonceTransferMessageBase64(
        allocator,
        payer,
        payer,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildLegacyNonceTransferMessageBase64(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    const message_bytes = try buildLegacyNonceTransferMessageBytes(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
    defer allocator.free(message_bytes);

    return try encodeBase64(allocator, message_bytes);
}

pub fn buildLegacyNonceTransferMessageBase64WithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) ![]u8 {
    return try buildLegacyNonceTransferMessageBase64(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildOwnedLegacyTransferMessage(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyTransferMessageWithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildSignedLegacyTransferTransaction(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    return try buildSignedLegacyTransferTransactionWithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
}

pub fn buildLegacyTransferTransactionBase64(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) ![]u8 {
    return try buildLegacyTransferTransactionBase64WithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
}

pub fn buildOwnedLegacyTransferMessageWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
) !OwnedLegacyMessage {
    return try buildOwnedLegacyNonceTransferMessage(
        allocator,
        payer,
        payer,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
    );
}

pub fn buildSignedLegacyTransferTransactionWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    return try buildSignedLegacyNonceTransferTransaction(
        allocator,
        payer,
        payer,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
}

pub fn buildLegacyTransferTransactionWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    return try buildSignedLegacyTransferTransactionWithNonce(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
}

pub fn buildSignedLegacyNonceTransferTransaction(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildSignedLegacyTransactionWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        nonce_authority,
        recent_blockhash,
        instructions[0..],
        signers,
    );
}

pub fn buildLegacyNonceTransferTransaction(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) !SignedLegacyTransaction {
    return try buildSignedLegacyNonceTransferTransaction(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
}

pub fn buildLegacyTransferTransactionBase64WithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) ![]u8 {
    return try buildLegacyNonceTransferTransactionBase64(
        allocator,
        payer,
        payer,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
}

pub fn buildLegacyNonceTransferTransactionBase64(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    nonce_authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedLegacyNonceTransferTransaction(
        allocator,
        payer,
        sender,
        nonce_account,
        nonce_authority,
        destination,
        recent_blockhash,
        lamports,
        signers,
    );
    defer signed.deinit(allocator);

    return try signed.toBase64(allocator);
}

pub fn buildLegacyTransferMessageWithNonce(
    allocator: Allocator,
    sender_public_key: [Ed25519.PublicKey.encoded_length]u8,
    nonce_account_public_key: [Ed25519.PublicKey.encoded_length]u8,
    destination_public_key: [Ed25519.PublicKey.encoded_length]u8,
    recent_blockhash: [32]u8,
    lamports: u64,
) ![]u8 {
    const sender = Pubkey.fromBytes(sender_public_key);
    var owned = try buildOwnedLegacyNonceTransferMessage(
        allocator,
        sender,
        sender,
        Pubkey.fromBytes(nonce_account_public_key),
        sender,
        Pubkey.fromBytes(destination_public_key),
        Hash.fromBytes(recent_blockhash),
        lamports,
    );
    defer owned.deinit(allocator);

    return try owned.serialize(allocator);
}

pub fn buildLegacyTransferTransactionBase64FromSecretKeyWithNonce(
    allocator: Allocator,
    secret_key: []const u8,
    nonce_account_public_key: []const u8,
    destination_public_key: []const u8,
    recent_blockhash: []const u8,
    lamports: u64,
) ![]u8 {
    const keypair = try Keypair.fromSecretKeySlice(secret_key);
    const nonce_account = try Pubkey.fromSlice(nonce_account_public_key);
    const destination = try Pubkey.fromSlice(destination_public_key);
    return try buildLegacyNonceTransferTransactionBase64(
        allocator,
        keypair.public_key,
        keypair.public_key,
        nonce_account,
        keypair.public_key,
        destination,
        try Hash.fromSlice(recent_blockhash),
        lamports,
        &.{keypair},
    );
}

pub fn buildSignedVersionedTransactionV0(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    var compiled = try compileVersionedMessageV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
    defer compiled.deinit(allocator);

    return try compiled.sign(allocator, signers);
}

pub fn buildVersionedTransactionV0(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransactionV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildSignedVersionedTransaction(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransactionV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransaction(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransaction(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildOwnedVersionedMessage(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try compileVersionedMessageV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedMessage(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessage(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildOwnedVersionedMessageV0WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    var owned_instructions = try prependNonceAdvanceInstruction(
        allocator,
        nonce_account,
        authority,
        instructions,
    );
    defer owned_instructions.deinit(allocator);

    return try compileVersionedMessageV0(
        allocator,
        payer,
        recent_blockhash,
        owned_instructions.instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedMessageV0WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedMessageV0BytesWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    var compiled = try buildOwnedVersionedMessageV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
    defer compiled.deinit(allocator);

    return try compiled.serialize(allocator);
}

pub fn buildVersionedMessageBytesWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedMessageV0BytesWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedMessageV0Base64WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const message_bytes = try buildVersionedMessageV0BytesWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
    defer allocator.free(message_bytes);
    return try encodeBase64(allocator, message_bytes);
}

pub fn buildVersionedMessageBase64WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedMessageV0Base64WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildSignedVersionedTransactionV0WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    var compiled = try buildOwnedVersionedMessageV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
    defer compiled.deinit(allocator);

    return try compiled.sign(allocator, signers);
}

pub fn buildVersionedTransactionV0WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildSignedVersionedTransactionWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransactionWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransactionWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildOwnedVersionedMessageWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedMessageWithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedMessageWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedTransactionV0Base64WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
    defer signed.deinit(allocator);
    return try signed.toBase64(allocator);
}

pub fn buildVersionedTransactionBase64WithNonceInstructions(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    return try buildVersionedTransactionV0Base64WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildOwnedVersionedTransferMessage(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedTransferMessageWithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedTransferMessage(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedTransferMessage(
        allocator,
        payer,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildOwnedVersionedTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try compileVersionedMessageV0(
        allocator,
        payer,
        recent_blockhash,
        instructions[0..],
        address_lookup_tables,
    );
}

pub fn buildVersionedTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedTransferMessageWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildOwnedVersionedTransferMessageWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedNonceTransferMessage(
        allocator,
        payer,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedTransferMessageWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedTransferMessageWithNonce(
        allocator,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildOwnedVersionedNonceTransferMessage(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildOwnedVersionedMessageV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions[0..],
        address_lookup_tables,
    );
}

pub fn buildOwnedVersionedNonceTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedNonceTransferMessage(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferMessage(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedNonceTransferMessage(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferMessageWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) !OwnedVersionedMessageV0 {
    return try buildOwnedVersionedNonceTransferMessageWithSender(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedTransferMessageBytesWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedNonceTransferMessageBytes(
        allocator,
        payer,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedTransferMessageBytesWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    var owned = try buildOwnedVersionedTransferMessageWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
    defer owned.deinit(allocator);
    return try owned.serialize(allocator);
}

pub fn buildVersionedNonceTransferMessageBytes(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildVersionedMessageV0BytesWithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions[0..],
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferMessageBytesWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedNonceTransferMessageBytes(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedTransferMessageBase64(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const message_bytes = try buildVersionedTransferMessageBytesWithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
    defer allocator.free(message_bytes);
    return try encodeBase64(allocator, message_bytes);
}

pub fn buildVersionedTransferMessageBase64WithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const message_bytes = try buildVersionedTransferMessageBytesWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
    defer allocator.free(message_bytes);
    return try encodeBase64(allocator, message_bytes);
}

pub fn buildVersionedTransferMessageBase64WithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedNonceTransferMessageBase64(
        allocator,
        payer,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildVersionedNonceTransferMessageBase64(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const message_bytes = try buildVersionedNonceTransferMessageBytes(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
    defer allocator.free(message_bytes);
    return try encodeBase64(allocator, message_bytes);
}

pub fn buildVersionedNonceTransferMessageBase64WithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedNonceTransferMessageBase64(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
    );
}

pub fn buildSignedVersionedTransferTransactionWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildSignedVersionedTransactionV0(
        allocator,
        payer,
        recent_blockhash,
        instructions[0..],
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransferTransactionWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransferTransactionWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildSignedVersionedTransferTransaction(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransferTransactionWithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransferTransaction(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransferTransaction(
        allocator,
        payer,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildSignedVersionedTransferTransactionWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedNonceTransferTransaction(
        allocator,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransferTransactionWithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedTransferTransactionWithNonce(
        allocator,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransferTransactionBase64WithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedVersionedTransferTransactionWithSender(
        allocator,
        payer,
        sender,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
    defer signed.deinit(allocator);
    return try signed.toBase64(allocator);
}

pub fn buildVersionedTransferTransactionBase64(
    allocator: Allocator,
    payer: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    return try buildVersionedTransferTransactionBase64WithSender(
        allocator,
        payer,
        payer,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransferTransactionBase64WithNonce(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    return try buildVersionedNonceTransferTransactionBase64(
        allocator,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildSignedVersionedNonceTransferTransaction(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedNonceTransferTransactionWithSender(
        allocator,
        payer,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedNonceTransferTransaction(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedNonceTransferTransaction(
        allocator,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildSignedVersionedNonceTransferTransactionWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    const transfer = SystemProgram.transfer(sender, destination, lamports);
    const instructions = [_]Instruction{transfer.instruction()};
    return try buildSignedVersionedTransactionV0WithNonceInstructions(
        allocator,
        payer,
        nonce_account,
        authority,
        recent_blockhash,
        instructions[0..],
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedNonceTransferTransactionWithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) !SignedVersionedTransaction {
    return try buildSignedVersionedNonceTransferTransactionWithSender(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedNonceTransferTransactionBase64(
    allocator: Allocator,
    payer: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    return try buildVersionedNonceTransferTransactionBase64WithSender(
        allocator,
        payer,
        payer,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedNonceTransferTransactionBase64WithSender(
    allocator: Allocator,
    payer: Pubkey,
    sender: Pubkey,
    nonce_account: Pubkey,
    authority: Pubkey,
    destination: Pubkey,
    recent_blockhash: Hash,
    lamports: u64,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedVersionedNonceTransferTransactionWithSender(
        allocator,
        payer,
        sender,
        nonce_account,
        authority,
        destination,
        recent_blockhash,
        lamports,
        address_lookup_tables,
        signers,
    );
    defer signed.deinit(allocator);
    return try signed.toBase64(allocator);
}

pub fn buildVersionedMessageBytes(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedMessageV0Bytes(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedMessageBase64(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    return try buildVersionedMessageV0Base64(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
}

pub fn buildVersionedMessageV0Bytes(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    var compiled = try compileVersionedMessageV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
    defer compiled.deinit(allocator);

    return try compiled.serialize(allocator);
}

pub fn buildVersionedMessageV0Base64(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
) ![]u8 {
    const message_bytes = try buildVersionedMessageV0Bytes(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
    );
    defer allocator.free(message_bytes);

    return try encodeBase64(allocator, message_bytes);
}

pub fn buildVersionedTransactionV0Base64(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    var signed = try buildSignedVersionedTransactionV0(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
    defer signed.deinit(allocator);

    return try signed.toBase64(allocator);
}

pub fn buildVersionedTransactionBase64(
    allocator: Allocator,
    payer: Pubkey,
    recent_blockhash: Hash,
    instructions: []const Instruction,
    address_lookup_tables: []const AddressLookupTableAccount,
    signers: []const Keypair,
) ![]u8 {
    return try buildVersionedTransactionV0Base64(
        allocator,
        payer,
        recent_blockhash,
        instructions,
        address_lookup_tables,
        signers,
    );
}

pub fn buildVersionedTransferMessageBytes(
    allocator: Allocator,
    sender_public_key: [Ed25519.PublicKey.encoded_length]u8,
    destination_public_key: [Ed25519.PublicKey.encoded_length]u8,
    recent_blockhash: [32]u8,
    lamports: u64,
    address_table_lookups: []const MessageAddressTableLookup,
) ![]u8 {
    var serialized = std.ArrayList(u8).empty;
    errdefer serialized.deinit(allocator);

    const transfer_instruction = SystemProgram.transfer(
        Pubkey.fromBytes(sender_public_key),
        Pubkey.fromBytes(destination_public_key),
        lamports,
    );

    try serialized.append(allocator, 0x80);
    try serialized.append(allocator, 1);
    try serialized.append(allocator, 0);
    try serialized.append(allocator, 1);

    try writeCompactVecLen(&serialized, allocator, 3);
    try serialized.appendSlice(allocator, &sender_public_key);
    try serialized.appendSlice(allocator, &destination_public_key);
    try serialized.appendSlice(allocator, &SystemProgram.id().bytes);
    try serialized.appendSlice(allocator, &recent_blockhash);

    try writeCompactVecLen(&serialized, allocator, 1);
    try serialized.append(allocator, 2);
    try writeCompactVecLen(&serialized, allocator, 2);
    try serialized.append(allocator, 0);
    try serialized.append(allocator, 1);
    try writeCompactVecLen(&serialized, allocator, transfer_instruction.data.len);
    try serialized.appendSlice(allocator, transfer_instruction.data[0..]);

    try writeCompactVecLen(&serialized, allocator, address_table_lookups.len);
    for (address_table_lookups) |lookup| {
        try serialized.appendSlice(allocator, &lookup.account_key.bytes);
        try writeCompactVecLen(&serialized, allocator, lookup.writable_indexes.len);
        try serialized.appendSlice(allocator, lookup.writable_indexes);
        try writeCompactVecLen(&serialized, allocator, lookup.readonly_indexes.len);
        try serialized.appendSlice(allocator, lookup.readonly_indexes);
    }

    return try serialized.toOwnedSlice(allocator);
}
