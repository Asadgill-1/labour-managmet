/// Shape check only: 15 digits. This is not verification with the FTA (MASTER-02).
bool isTrnFormat(String input) => RegExp(r'^\d{15}$').hasMatch(input.trim());
