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
    if (encoded.len == 0) return error.InvalidBase58Length;

    var leading_zeroes: usize = 0;
    for (encoded) |byte| {
        if (byte == '1') {
            leading_zeroes += 1;
        } else {
            break;
        }
    }

    var decoded = std.ArrayList(u8).empty;
    errdefer decoded.deinit(allocator);

    for (encoded) |byte| {
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
        const compiled = try compileLegacyMessage(allocator, self);
        allocator.free(compiled.account_keys);
        return compiled.bytes;
    }

    pub fn toBase64(self: LegacyMessage, allocator: Allocator) ![]u8 {
        const bytes = try self.serialize(allocator);
        defer allocator.free(bytes);
        return try encodeBase64(allocator, bytes);
    }

    pub fn sign(self: LegacyMessage, allocator: Allocator, signers: []const Keypair) !SignedLegacyTransaction {
        const compiled = try compileLegacyMessage(allocator, self);
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

pub const VersionedMessageV0 = struct {
    header: LegacyMessageHeader,
    account_keys: []const Pubkey,
    recent_blockhash: Hash,
    instructions: []const CompiledInstruction,
    address_table_lookups: []const MessageAddressTableLookup,

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
};

const CompiledLegacyMessage = struct {
    header: LegacyMessageHeader,
    account_keys: []Pubkey,
    bytes: []u8,
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

fn compileLegacyMessage(allocator: Allocator, message: LegacyMessage) !CompiledLegacyMessage {
    var collected_metas = std.ArrayList(AccountMeta).empty;
    defer collected_metas.deinit(allocator);

    try appendOrMergeAccountMeta(&collected_metas, allocator, AccountMeta.init(message.payer, true, true));

    for (message.instructions) |instruction| {
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

    const ordered_meta_slice = try ordered_metas.toOwnedSlice(allocator);
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
