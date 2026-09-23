class_name NetworkPackageCodec
extends RefCounted

## Asset obfuscation and integrity protection, not a secrecy boundary: the game
## necessarily ships the material needed to derive its content keys. Keeping it
## here prevents keys and cryptographic policy from leaking into gameplay code.
const MAGIC := "NSPACEPK"
const PACKAGE_FORMAT_VERSION := 1
const ENCRYPTION_FORMAT_VERSION := 1
const IV_SIZE := 16
const TAG_SIZE := 32
const HEADER_SIZE := 20
const BLOCK_SIZE := 16
const MAX_CIPHERTEXT_SIZE := 64 * 1024 * 1024
const _PACKAGE_MASTER_KEY_HEX := "725c8a961304b95a6f61216cfe3365df27ad7c0cf55f918aa13c74227bdc59e1"

static func encode(plaintext: PackedByteArray) -> Dictionary:
	var iv := Crypto.new().generate_random_bytes(IV_SIZE)
	if iv.size() != IV_SIZE: return _failure(ERR_CANT_CREATE, "Could not generate package IV.")
	var padded := _pad(plaintext)
	var aes := AESContext.new()
	var error := aes.start(AESContext.MODE_CBC_ENCRYPT, _encryption_key(), iv)
	if error != OK: return _failure(error, "Could not initialize network encryption.")
	var ciphertext := aes.update(padded); aes.finish()
	if ciphertext.is_empty() or ciphertext.size() > MAX_CIPHERTEXT_SIZE: return _failure(ERR_INVALID_DATA, "Invalid encrypted network size.")
	var authenticated := _header(ciphertext.size()); authenticated.append_array(iv); authenticated.append_array(ciphertext)
	var tag := _hmac(_authentication_key(), authenticated)
	if tag.size() != TAG_SIZE: return _failure(ERR_CANT_CREATE, "Could not authenticate network package.")
	var package := authenticated.duplicate(); package.append_array(tag)
	return {"success": true, "error": OK, "data": package}

static func decode(package: PackedByteArray) -> Dictionary:
	if package.size() < HEADER_SIZE + IV_SIZE + TAG_SIZE: return _failure(ERR_FILE_CORRUPT, "Network package is truncated.")
	if package.slice(0, MAGIC.length()).get_string_from_ascii() != MAGIC: return _failure(ERR_FILE_UNRECOGNIZED, "Network package magic is invalid.")
	var package_version := _u16(package, 8); var encryption_version := _u16(package, 10)
	if package_version != PACKAGE_FORMAT_VERSION: return _failure(ERR_UNAVAILABLE, "Unsupported network package version %d." % package_version)
	if encryption_version != ENCRYPTION_FORMAT_VERSION: return _failure(ERR_UNAVAILABLE, "Unsupported network encryption version %d." % encryption_version)
	var iv_size := int(package[12]); var tag_size := int(package[13]); var ciphertext_size := _u32(package, 16)
	if iv_size != IV_SIZE or tag_size != TAG_SIZE or ciphertext_size <= 0 or ciphertext_size > MAX_CIPHERTEXT_SIZE or ciphertext_size % BLOCK_SIZE != 0: return _failure(ERR_FILE_CORRUPT, "Network package lengths are invalid.")
	var authenticated_size := HEADER_SIZE + iv_size + ciphertext_size
	if package.size() != authenticated_size + tag_size: return _failure(ERR_FILE_CORRUPT, "Network package size does not match its header.")
	var authenticated := package.slice(0, authenticated_size)
	var expected_tag := _hmac(_authentication_key(), authenticated)
	var supplied_tag := package.slice(authenticated_size, package.size())
	if not _constant_time_equal(expected_tag, supplied_tag): return _failure(ERR_INVALID_DATA, "Network package authentication failed.")
	var iv := package.slice(HEADER_SIZE, HEADER_SIZE + iv_size)
	var ciphertext := package.slice(HEADER_SIZE + iv_size, authenticated_size)
	var aes := AESContext.new()
	var error := aes.start(AESContext.MODE_CBC_DECRYPT, _encryption_key(), iv)
	if error != OK: return _failure(error, "Could not initialize network decryption.")
	var padded := aes.update(ciphertext); aes.finish()
	var plaintext: Variant = _unpad(padded)
	if plaintext == null: return _failure(ERR_FILE_CORRUPT, "Network package padding is invalid.")
	return {"success": true, "error": OK, "data": plaintext, "package_version": package_version, "encryption_version": encryption_version}

static func _header(ciphertext_size: int) -> PackedByteArray:
	var result := MAGIC.to_ascii_buffer(); _append_u16(result, PACKAGE_FORMAT_VERSION); _append_u16(result, ENCRYPTION_FORMAT_VERSION); result.append(IV_SIZE); result.append(TAG_SIZE); _append_u16(result, 0); _append_u32(result, ciphertext_size); return result

static func _pad(data: PackedByteArray) -> PackedByteArray:
	var result := data.duplicate(); var padding := BLOCK_SIZE - (result.size() % BLOCK_SIZE)
	for unused in padding: result.append(padding)
	return result

static func _unpad(data: PackedByteArray) -> Variant:
	if data.is_empty(): return null
	var padding := int(data[data.size() - 1])
	if padding <= 0 or padding > BLOCK_SIZE or padding > data.size(): return null
	for index in range(data.size() - padding, data.size()):
		if int(data[index]) != padding: return null
	return data.slice(0, data.size() - padding)

static func _encryption_key() -> PackedByteArray: return _hmac(_master_key(), "NETSPACE-AES-256-V1".to_utf8_buffer())
static func _authentication_key() -> PackedByteArray: return _hmac(_master_key(), "NETSPACE-HMAC-SHA256-V1".to_utf8_buffer())
static func _master_key() -> PackedByteArray: return _PACKAGE_MASTER_KEY_HEX.hex_decode()

static func _hmac(key: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	var context := HMACContext.new()
	if context.start(HashingContext.HASH_SHA256, key) != OK: return PackedByteArray()
	if context.update(data) != OK: return PackedByteArray()
	return context.finish()

static func _constant_time_equal(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size(): return false
	var difference := 0
	for index in a.size(): difference |= int(a[index]) ^ int(b[index])
	return difference == 0

static func _append_u16(data: PackedByteArray, value: int) -> void: data.append((value >> 8) & 0xff); data.append(value & 0xff)
static func _append_u32(data: PackedByteArray, value: int) -> void: data.append((value >> 24) & 0xff); data.append((value >> 16) & 0xff); data.append((value >> 8) & 0xff); data.append(value & 0xff)
static func _u16(data: PackedByteArray, offset: int) -> int: return (int(data[offset]) << 8) | int(data[offset + 1])
static func _u32(data: PackedByteArray, offset: int) -> int: return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])
static func _failure(error: Error, message: String) -> Dictionary: return {"success": false, "error": error, "message": message, "data": PackedByteArray()}
