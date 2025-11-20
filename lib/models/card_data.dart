class CardData {
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? documentNumber;
  final String? dateOfBirth;
  final String? expiryDate;
  final String? address;
  final String? nationality;
  final String? sex;
  final String? documentType;
  final String? rawText;

  CardData({
    this.firstName,
    this.lastName,
    this.fullName,
    this.documentNumber,
    this.dateOfBirth,
    this.expiryDate,
    this.address,
    this.nationality,
    this.sex,
    this.documentType,
    this.rawText,
  });

  bool get isEmpty {
    return firstName == null &&
        lastName == null &&
        fullName == null &&
        documentNumber == null;
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'documentNumber': documentNumber,
      'dateOfBirth': dateOfBirth,
      'expiryDate': expiryDate,
      'address': address,
      'nationality': nationality,
      'sex': sex,
      'documentType': documentType,
      'rawText': rawText,
    };
  }
}

