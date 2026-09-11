enum ClientLoanType {
  home,
  mortgage,
  construction,
  overdraftCc,
  personal,
  business,
  cgtmse,
  vehicle,
  education,
  gold,
}

extension ClientLoanTypeLabel on ClientLoanType {
  String get displayName => switch (this) {
    ClientLoanType.home => 'Home Loan',
    ClientLoanType.mortgage => 'Mortgage Loan',
    ClientLoanType.construction => 'Construction Loan',
    ClientLoanType.overdraftCc => 'Bank OD / CC',
    ClientLoanType.personal => 'Personal Loan',
    ClientLoanType.business => 'Business Loan',
    ClientLoanType.cgtmse => 'CGTMSE Scheme Loan',
    ClientLoanType.vehicle => 'Vehicle Loan',
    ClientLoanType.education => 'Education Loan',
    ClientLoanType.gold => 'Gold Loan',
  };

  bool get usesDailyInterest => this == ClientLoanType.overdraftCc;
  bool get requiresVehicleSelection => this == ClientLoanType.vehicle;
}

enum ClientInvestmentType {
  sip,
  chits,
  lic,
  ulip,
  healthInsurance,
  mutualFund,
  fd,
  ppf,
  nps,
  stocks,
}

extension ClientInvestmentTypeLabel on ClientInvestmentType {
  String get displayName => switch (this) {
    ClientInvestmentType.sip => 'SIP',
    ClientInvestmentType.chits => 'Chits',
    ClientInvestmentType.lic => 'LIC',
    ClientInvestmentType.ulip => 'ULIP',
    ClientInvestmentType.healthInsurance => 'Health Insurance',
    ClientInvestmentType.mutualFund => 'Mutual Fund',
    ClientInvestmentType.fd => 'Fixed Deposit',
    ClientInvestmentType.ppf => 'PPF',
    ClientInvestmentType.nps => 'NPS',
    ClientInvestmentType.stocks => 'Stocks',
  };

  bool get needsMaturityTarget => this != ClientInvestmentType.healthInsurance;
  bool get needsChitFields => this == ClientInvestmentType.chits;
  bool get needsSumAssured =>
      this == ClientInvestmentType.healthInsurance ||
      this == ClientInvestmentType.lic ||
      this == ClientInvestmentType.ulip;
}

class LoanPlan {
  const LoanPlan({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.loanType,
    required this.planName,
    required this.lenderName,
    required this.principalAmount,
    required this.annualInterestRate,
    required this.tenureMonths,
    required this.reminderDate,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.utilizedAmount = 0,
    this.utilizedDays = 30,
    this.maturityDate,
    this.isClaimed = false,
  });

  final String id;
  final String clientId;
  final String clientName;
  final ClientLoanType loanType;
  final String planName;
  final String lenderName;
  final double principalAmount;
  final double annualInterestRate;
  final int tenureMonths;
  final DateTime reminderDate;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String vehicleMake;
  final String vehicleModel;
  final double utilizedAmount;
  final int utilizedDays;
  final DateTime? maturityDate;
  final bool isClaimed;

  LoanPlan copyWith({
    String? id,
    String? clientId,
    String? clientName,
    ClientLoanType? loanType,
    String? planName,
    String? lenderName,
    double? principalAmount,
    double? annualInterestRate,
    int? tenureMonths,
    DateTime? reminderDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? vehicleMake,
    String? vehicleModel,
    double? utilizedAmount,
    int? utilizedDays,
    DateTime? maturityDate,
    bool? isClaimed,
  }) {
    return LoanPlan(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      loanType: loanType ?? this.loanType,
      planName: planName ?? this.planName,
      lenderName: lenderName ?? this.lenderName,
      principalAmount: principalAmount ?? this.principalAmount,
      annualInterestRate: annualInterestRate ?? this.annualInterestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      reminderDate: reminderDate ?? this.reminderDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      utilizedAmount: utilizedAmount ?? this.utilizedAmount,
      utilizedDays: utilizedDays ?? this.utilizedDays,
      maturityDate: maturityDate ?? this.maturityDate,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'loanType': loanType.name,
    'planName': planName,
    'lenderName': lenderName,
    'principalAmount': principalAmount,
    'annualInterestRate': annualInterestRate,
    'tenureMonths': tenureMonths,
    'reminderDate': reminderDate.toIso8601String(),
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'vehicleMake': vehicleMake,
    'vehicleModel': vehicleModel,
    'utilizedAmount': utilizedAmount,
    'utilizedDays': utilizedDays,
    'maturityDate': maturityDate?.toIso8601String(),
    'isClaimed': isClaimed,
  };

  factory LoanPlan.fromJson(Map<String, dynamic> json) {
    return LoanPlan(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      loanType: ClientLoanType.values.firstWhere(
        (value) => value.name == json['loanType']?.toString(),
        orElse: () => ClientLoanType.home,
      ),
      planName: json['planName']?.toString() ?? '',
      lenderName: json['lenderName']?.toString() ?? '',
      principalAmount: (json['principalAmount'] as num?)?.toDouble() ?? 0,
      annualInterestRate:
          (json['annualInterestRate'] as num?)?.toDouble() ?? 0,
      tenureMonths: (json['tenureMonths'] as num?)?.toInt() ?? 12,
      reminderDate: DateTime.tryParse(json['reminderDate']?.toString() ?? '') ??
          DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      vehicleMake: json['vehicleMake']?.toString() ?? '',
      vehicleModel: json['vehicleModel']?.toString() ?? '',
      utilizedAmount: (json['utilizedAmount'] as num?)?.toDouble() ?? 0,
      utilizedDays: (json['utilizedDays'] as num?)?.toInt() ?? 30,
      maturityDate: DateTime.tryParse(json['maturityDate']?.toString() ?? ''),
      isClaimed: json['isClaimed'] as bool? ?? false,
    );
  }
}

class InvestmentPlan {
  const InvestmentPlan({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.investmentType,
    required this.planName,
    required this.monthlyContribution,
    required this.yearlyContribution,
    required this.targetAmount,
    required this.expectedReturnRate,
    required this.tenureMonths,
    required this.reminderDate,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.batchAmount = 0,
    this.monthlyPremium = 0,
    this.sumAssuredAmount = 0,
    this.maturityDate,
    this.isClaimed = false,
    this.attachmentPath,
    this.attachmentName,
  });

  final String id;
  final String clientId;
  final String clientName;
  final ClientInvestmentType investmentType;
  final String planName;
  final double monthlyContribution;
  final double yearlyContribution;
  final double targetAmount;
  final double expectedReturnRate;
  final int tenureMonths;
  final DateTime reminderDate;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double batchAmount;
  final double monthlyPremium;
  final double sumAssuredAmount;
  final DateTime? maturityDate;
  final bool isClaimed;
  final String? attachmentPath;
  final String? attachmentName;

  InvestmentPlan copyWith({
    String? id,
    String? clientId,
    String? clientName,
    ClientInvestmentType? investmentType,
    String? planName,
    double? monthlyContribution,
    double? yearlyContribution,
    double? targetAmount,
    double? expectedReturnRate,
    int? tenureMonths,
    DateTime? reminderDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? batchAmount,
    double? monthlyPremium,
    double? sumAssuredAmount,
    DateTime? maturityDate,
    bool? isClaimed,
    String? attachmentPath,
    String? attachmentName,
  }) {
    return InvestmentPlan(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      investmentType: investmentType ?? this.investmentType,
      planName: planName ?? this.planName,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      yearlyContribution: yearlyContribution ?? this.yearlyContribution,
      targetAmount: targetAmount ?? this.targetAmount,
      expectedReturnRate: expectedReturnRate ?? this.expectedReturnRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      reminderDate: reminderDate ?? this.reminderDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      batchAmount: batchAmount ?? this.batchAmount,
      monthlyPremium: monthlyPremium ?? this.monthlyPremium,
      sumAssuredAmount: sumAssuredAmount ?? this.sumAssuredAmount,
      maturityDate: maturityDate ?? this.maturityDate,
      isClaimed: isClaimed ?? this.isClaimed,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentName: attachmentName ?? this.attachmentName,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'investmentType': investmentType.name,
    'planName': planName,
    'monthlyContribution': monthlyContribution,
    'yearlyContribution': yearlyContribution,
    'targetAmount': targetAmount,
    'expectedReturnRate': expectedReturnRate,
    'tenureMonths': tenureMonths,
    'reminderDate': reminderDate.toIso8601String(),
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'batchAmount': batchAmount,
    'monthlyPremium': monthlyPremium,
    'sumAssuredAmount': sumAssuredAmount,
    'maturityDate': maturityDate?.toIso8601String(),
    'isClaimed': isClaimed,
    'attachmentPath': attachmentPath,
    'attachmentName': attachmentName,
  };

  factory InvestmentPlan.fromJson(Map<String, dynamic> json) {
    return InvestmentPlan(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      investmentType: ClientInvestmentType.values.firstWhere(
        (value) => value.name == json['investmentType']?.toString(),
        orElse: () => ClientInvestmentType.sip,
      ),
      planName: json['planName']?.toString() ?? '',
      monthlyContribution:
          (json['monthlyContribution'] as num?)?.toDouble() ?? 0,
      yearlyContribution: (json['yearlyContribution'] as num?)?.toDouble() ?? 0,
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      expectedReturnRate:
          (json['expectedReturnRate'] as num?)?.toDouble() ?? 0,
      tenureMonths: (json['tenureMonths'] as num?)?.toInt() ?? 12,
      reminderDate: DateTime.tryParse(json['reminderDate']?.toString() ?? '') ??
          DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      batchAmount: (json['batchAmount'] as num?)?.toDouble() ?? 0,
      monthlyPremium: (json['monthlyPremium'] as num?)?.toDouble() ?? 0,
      sumAssuredAmount: (json['sumAssuredAmount'] as num?)?.toDouble() ?? 0,
      maturityDate: DateTime.tryParse(json['maturityDate']?.toString() ?? ''),
      isClaimed: json['isClaimed'] as bool? ?? false,
      attachmentPath: json['attachmentPath']?.toString(),
      attachmentName: json['attachmentName']?.toString(),
    );
  }
}

const Map<String, List<String>> vehicleLoanCatalog = <String, List<String>>{
  'Maruti Suzuki': <String>['Swift', 'Dzire', 'Brezza', 'Ertiga', 'Baleno'],
  'Hyundai': <String>['Creta', 'Venue', 'i20', 'Verna', 'Exter'],
  'Tata': <String>['Nexon', 'Punch', 'Harrier', 'Tiago', 'Safari'],
  'Mahindra': <String>['Scorpio', 'XUV700', 'Bolero', 'Thar', 'XUV3XO'],
  'Toyota': <String>['Innova', 'Fortuner', 'Glanza', 'Hyryder', 'Rumion'],
  'Honda': <String>['City', 'Amaze', 'Elevate'],
  'Kia': <String>['Seltos', 'Sonet', 'Carens'],
  'Renault': <String>['Kiger', 'Triber', 'Kwid'],
};