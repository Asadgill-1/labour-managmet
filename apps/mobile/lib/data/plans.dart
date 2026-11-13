import 'dart:typed_data';

/// A plan on sale, from the cloud's versioned config (D-074). Prices in integer fils; a null limit is unlimited.
typedef Plan = ({String code, String name, int priceFils, int addonFils, int? workers, int? clients, int? managers});

/// The platform's bank account, as typed into the live settings. A field not filled in is null, and not shown.
typedef BankDetails = ({String? bankName, String? accountNumber, String? iban, String? holder});

extension BankReady on BankDetails {
  /// Something to pay into.
  bool get ready => accountNumber != null || iban != null;
}

/// A payment slip the company sent, and how it stands: waiting, accepted or refused with a reason (BILL-01).
typedef Slip = ({String id, String planCode, int months, int expectedFils, String state, String? refuseReason, DateTime sentAt, bool fileArrived});

enum SlipKind {
  jpg('image/jpeg'),
  png('image/png'),
  pdf('application/pdf');

  const SlipKind(this.mime);

  final String mime;
}

/// As large as the cloud's slip bucket takes.
const slipMaxBytes = 5 * 1024 * 1024;

/// The payment page stays out of a Play Store build until the policy review (BILL-07, D-012).
const playStoreBuild = bool.fromEnvironment('PLAY_STORE');

/// What a picked file is, by its first bytes rather than its name, or null when it is not a photo or a PDF.
SlipKind? slipKindOf(Uint8List bytes) {
  bool starts(List<int> magic) => bytes.length >= magic.length && [for (var i = 0; i < magic.length; i++) bytes[i] == magic[i]].every((b) => b);
  if (starts([0xFF, 0xD8, 0xFF])) return SlipKind.jpg;
  if (starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return SlipKind.png;
  if (starts('%PDF-'.codeUnits)) return SlipKind.pdf;
  return null;
}
