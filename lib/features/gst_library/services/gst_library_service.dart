import 'package:flutter/foundation.dart';

class GstProblemGuide {
  const GstProblemGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.keywords,
    required this.noticeForms,
    required this.summary,
    required this.immediateActions,
    required this.steps,
    required this.requiredDocuments,
    required this.sectionIds,
    required this.deadlineGuidance,
    required this.escalationGuidance,
  });

  final String id;
  final String title;
  final String category;
  final List<String> keywords;
  final List<String> noticeForms;
  final String summary;
  final List<String> immediateActions;
  final List<String> steps;
  final List<String> requiredDocuments;
  final List<String> sectionIds;
  final String deadlineGuidance;
  final String escalationGuidance;
}

class GstGuidanceSearchResult {
  const GstGuidanceSearchResult({
    required this.guide,
    required this.score,
    required this.matchedTerms,
  });

  final GstProblemGuide guide;
  final int score;
  final List<String> matchedTerms;
}

class GstLibrarySection {
  const GstLibrarySection({
    required this.id,
    required this.displayName,
    required this.summary,
    this.category = 'section',
    this.highlights = const <String>[],
    this.keywords = const <String>[],
  });

  final String id;
  final String displayName;
  final String summary;
  final String category;
  final List<String> highlights;
  final List<String> keywords;
}

class GstActChapter {
  const GstActChapter({
    required this.id,
    required this.title,
    required this.sectionRange,
    required this.summary,
    required this.focusAreas,
    required this.scrutinyUse,
  });

  final String id;
  final String title;
  final String sectionRange;
  final String summary;
  final List<String> focusAreas;
  final String scrutinyUse;
}

class GstActAmendmentEntry {
  const GstActAmendmentEntry({
    required this.year,
    required this.amendingInstrument,
    required this.summary,
    required this.affectedAreas,
  });

  final int year;
  final String amendingInstrument;
  final String summary;
  final List<String> affectedAreas;
}

class GstJudgementEntry {
  const GstJudgementEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.court,
    required this.year,
    required this.topic,
    required this.keywords,
    required this.filedBy,
    required this.outcome,
    required this.orderReference,
    required this.orderSummary,
    required this.replyUse,
  });

  final String id;
  final String title;
  final String summary;
  final String court;
  final int year;
  final String topic;
  final List<String> keywords;
  final String filedBy;
  final String outcome;
  final String orderReference;
  final String orderSummary;
  final String replyUse;
}

class GstLibraryService extends ChangeNotifier {
  static const List<GstLibrarySection> _sections = <GstLibrarySection>[
    GstLibrarySection(
      id: 'cgst-act-2017-complete',
      displayName: 'Full GST Act 2017 with Amendments',
      summary:
          'Working legal repository covering the CGST Act, amendment checkpoints, linked rules, and reply-ready issue buckets.',
      category: 'act',
      highlights: <String>[
        'Core charging, registration, return, ITC, assessment, audit, demand and appeals chapters.',
        'Operational amendment checkpoints mapped for scrutiny replies and notice defence.',
        'Useful for drafting issue-wise legal framework before annexures and evidence.',
      ],
      keywords: <String>['cgst act', 'amendments', 'chapters', 'sections'],
    ),
    GstLibrarySection(
      id: 'sec-2',
      displayName: 'Section 2 - Definitions',
      summary: 'Foundational definitions used to interpret taxable person, supply, invoice, input tax and related GST concepts.',
      highlights: <String>[
        'Use when the notice turns on classification, supply character or statutory interpretation.',
      ],
      keywords: <String>['definitions', 'taxable person', 'supply', 'invoice'],
    ),
    GstLibrarySection(
      id: 'sec-16',
      displayName: 'Section 16 - Eligibility and Conditions for ITC',
      summary: 'Primary provision for claiming input tax credit subject to invoice, receipt, tax payment and return conditions.',
      highlights: <String>[
        'Useful for ITC mismatch, vendor default and document trail replies.',
      ],
      keywords: <String>['itc', 'input tax credit', 'eligibility', 'conditions'],
    ),
    GstLibrarySection(
      id: 'sec-17',
      displayName: 'Section 17 - Apportionment and Blocked Credits',
      summary: 'Covers business/non-business apportionment, exempt supplies and blocked credit restrictions.',
      highlights: <String>[
        'Use for motor vehicle, employee expense and exempt turnover disputes.',
      ],
      keywords: <String>['blocked credit', 'apportionment', 'exempt', 'section 17'],
    ),
    GstLibrarySection(
      id: 'sec-29',
      displayName: 'Section 29 - Cancellation or Suspension of Registration',
      summary: 'Relevant to cancellation notices, suspension restoration and ongoing compliance defaults.',
      highlights: <String>[
        'Use for REG-17 and suspension reply planning.',
      ],
      keywords: <String>['cancellation', 'suspension', 'registration'],
    ),
    GstLibrarySection(
      id: 'sec-35',
      displayName: 'Section 35 - Accounts and Records',
      summary: 'Specifies record-keeping expectations, document retention and registered place maintenance.',
      highlights: <String>[
        'Useful for audit preparation and record-production notices.',
      ],
      keywords: <String>['accounts', 'records', 'books', 'audit'],
    ),
    GstLibrarySection(
      id: 'sec-37',
      displayName: 'Section 37 - Details of Outward Supplies',
      summary: 'Governs statement of outward supplies and correction framework relevant to GSTR-1 disputes.',
      highlights: <String>[
        'Use for outward supply mismatch, amendment and invoice reporting issues.',
      ],
      keywords: <String>['gstr-1', 'outward supplies', 'invoice mismatch'],
    ),
    GstLibrarySection(
      id: 'sec-39',
      displayName: 'Section 39 - Furnishing of Returns',
      summary: 'Core return-filing provision relevant to GSTR-3B compliance, tax payment and delayed filing consequences.',
      highlights: <String>[
        'Use with Section 61 for return scrutiny and filing-default disputes.',
      ],
      keywords: <String>['returns', 'gstr-3b', 'filing', 'delayed return'],
    ),
    GstLibrarySection(
      id: 'sec-61',
      displayName: 'Section 61 - Scrutiny of Returns',
      summary: 'Applicable for discrepancy notices in filed returns.',
      highlights: <String>[
        'Use for ASMT-10 mismatch review.',
        'Supports point-wise discrepancy mapping and reply framing.',
      ],
      keywords: <String>['scrutiny', 'asmt-10', 'discrepancy', 'returns'],
    ),
    GstLibrarySection(
      id: 'rule-36',
      displayName: 'Rule 36 - ITC Conditions',
      summary: 'Reference for admissible input tax credit computation.',
      highlights: <String>[
        'Use for ITC eligibility, blocked credit and matching disputes.',
      ],
      keywords: <String>['rule 36', 'itc conditions', 'credit'],
    ),
    GstLibrarySection(
      id: 'rule-42',
      displayName: 'Rule 42 - ITC Reversal for Inputs and Input Services',
      summary: 'Prescribes reversal methodology where inputs/input services are used for taxable and exempt supplies.',
      highlights: <String>[
        'Use for exempt turnover reversals and working-paper disputes.',
      ],
      keywords: <String>['rule 42', 'reversal', 'exempt turnover'],
    ),
    GstLibrarySection(
      id: 'rule-43',
      displayName: 'Rule 43 - ITC Reversal for Capital Goods',
      summary: 'Applies capital-goods credit reversal methodology for mixed-use assets.',
      highlights: <String>[
        'Useful for plant, equipment and long-term asset ITC disputes.',
      ],
      keywords: <String>['rule 43', 'capital goods', 'reversal'],
    ),
    GstLibrarySection(
      id: 'sec-50',
      displayName: 'Section 50 - Interest on Delayed Tax',
      summary: 'Covers interest implications for delayed payments.',
      highlights: <String>[
        'Useful for interest recomputation and demand rebuttal notes.',
      ],
      keywords: <String>['interest', 'delayed tax', 'payment'],
    ),
    GstLibrarySection(
      id: 'sec-54',
      displayName: 'Section 54 - Refunds',
      summary: 'Principal refund provision covering time limits, application conditions and documentary support.',
      highlights: <String>[
        'Use for export refund, inverted duty and documentary deficiency disputes.',
      ],
      keywords: <String>['refund', 'export', 'inverted duty'],
    ),
    GstLibrarySection(
      id: 'sec-73',
      displayName: 'Section 73 - Demand without Fraud Allegation',
      summary: 'Demand recovery route for non-fraud tax short payment, wrongful ITC or erroneous refunds.',
      highlights: <String>[
        'Use for limitation, tax computation and voluntary payment strategy.',
      ],
      keywords: <String>['section 73', 'demand', 'non-fraud', 'short payment'],
    ),
    GstLibrarySection(
      id: 'sec-74',
      displayName: 'Section 74 - Demand with Fraud / Suppression Allegation',
      summary: 'Enhanced demand, penalty and evidence exposure where fraud, wilful misstatement or suppression is alleged.',
      highlights: <String>[
        'Use for stronger evidence defence and allegation-specific rebuttal.',
      ],
      keywords: <String>['section 74', 'fraud', 'suppression', 'penalty'],
    ),
    GstLibrarySection(
      id: 'sec-75',
      displayName: 'Section 75 - General Demand Provisions',
      summary: 'General procedural rules relevant to Sections 73 and 74 proceedings, hearings and adjudication mechanics.',
      highlights: <String>[
        'Useful for hearing rights, procedural lapses and demand structure review.',
      ],
      keywords: <String>['section 75', 'general provisions', 'hearing'],
    ),
    GstLibrarySection(
      id: 'rule-86a',
      displayName: 'Rule 86A - Restriction on Electronic Credit Ledger',
      summary: 'Allows temporary blocking of ITC in electronic credit ledger where officer forms reasons to believe credit is ineligible or fraud-linked.',
      highlights: <String>[
        'Use for ITC blocking challenges and documentary release representations.',
      ],
      keywords: <String>['rule 86a', 'electronic credit ledger', 'blocking'],
    ),
    GstLibrarySection(
      id: 'rule-88c',
      displayName: 'Rule 88C - Intimation on Tax Shortfall',
      summary: 'Addresses tax payable mismatch between GSTR-1 and GSTR-3B with pre-demand intimation workflow.',
      highlights: <String>[
        'Useful for automated mismatch response and early reconciliation before escalation.',
      ],
      keywords: <String>['rule 88c', 'gstr-1 vs 3b', 'shortfall', 'intimation'],
    ),
    GstLibrarySection(
      id: 'sec-83',
      displayName: 'Section 83 - Provisional Attachment',
      summary: 'High-risk coercive measure used to protect revenue during certain proceedings.',
      highlights: <String>[
        'Use for immediate escalation where bank or property attachment risk appears.',
      ],
      keywords: <String>['attachment', 'provisional attachment', 'bank account'],
    ),
    GstLibrarySection(
      id: 'sec-107',
      displayName: 'Section 107 - Appeals to Appellate Authority',
      summary: 'Appellate framework for challenging adjudication orders with pre-deposit and limitation considerations.',
      highlights: <String>[
        'Use when scrutiny or demand matters progress into appeal planning.',
      ],
      keywords: <String>['appeal', 'appellate authority', 'pre deposit'],
    ),
    GstLibrarySection(
      id: 'gst-case-judgements-orders',
      displayName: 'GST Case Judgements, Filed/Won Orders',
      summary:
          'Repository of GST case-law references with filed-by context, outcome direction and order notes for scrutiny drafting.',
      category: 'judgement',
      highlights: <String>[
        'Tracks whether the dispute was filed by taxpayer or department.',
        'Captures allowed, partly allowed or dismissed outcome notes.',
        'Helps cite practical order reasoning while preparing reply upgrades.',
      ],
      keywords: <String>['case law', 'judgements', 'orders', 'filed by', 'outcome'],
    ),
  ];

  static const List<GstActChapter> _actChapters = <GstActChapter>[
    GstActChapter(
      id: 'chapter-1',
      title: 'Chapter I - Preliminary',
      sectionRange: 'Sections 1-2',
      summary: 'Short title, extent, commencement and the statutory definitions that anchor every GST interpretation exercise.',
      focusAreas: <String>['Definitions', 'Interpretation', 'Foundational terms'],
      scrutinyUse: 'Use when a notice depends on how supply, invoice, input tax, business or taxable person is interpreted.',
    ),
    GstActChapter(
      id: 'chapter-3',
      title: 'Chapter III - Levy and Collection of Tax',
      sectionRange: 'Sections 7-11',
      summary: 'Covers scope of supply, tax liability timing and power to exempt supplies.',
      focusAreas: <String>['Supply', 'Composite supply', 'Mixed supply', 'Exemptions'],
      scrutinyUse: 'Use for classification, levy and exemption-based reply positions.',
    ),
    GstActChapter(
      id: 'chapter-6',
      title: 'Chapter VI - Registration',
      sectionRange: 'Sections 22-30',
      summary: 'Registration threshold, compulsory registration, amendment and cancellation framework.',
      focusAreas: <String>['Registration', 'Amendment', 'Cancellation', 'Suspension'],
      scrutinyUse: 'Use for registration validity, suspension and REG-17 disputes.',
    ),
    GstActChapter(
      id: 'chapter-7',
      title: 'Chapter VII - Tax Invoice, Credit and Debit Notes',
      sectionRange: 'Sections 31-34',
      summary: 'Invoice, revised invoice, debit note and credit note requirements.',
      focusAreas: <String>['Invoice compliance', 'Credit notes', 'Debit notes'],
      scrutinyUse: 'Use for invoice-documentary disputes and mismatch explanations.',
    ),
    GstActChapter(
      id: 'chapter-8',
      title: 'Chapter VIII - Accounts and Records',
      sectionRange: 'Sections 35-36',
      summary: 'Record maintenance and document retention obligations.',
      focusAreas: <String>['Books', 'Records', 'Retention'],
      scrutinyUse: 'Use when officer requires primary books, reconciliations and stock evidence.',
    ),
    GstActChapter(
      id: 'chapter-9',
      title: 'Chapter IX - Returns',
      sectionRange: 'Sections 37-48',
      summary: 'Outward supply statement, returns, annual return and data reporting obligations.',
      focusAreas: <String>['GSTR-1', 'GSTR-3B', 'Annual return', 'Rectification'],
      scrutinyUse: 'Use for return mismatch, shortfall and late filing disputes.',
    ),
    GstActChapter(
      id: 'chapter-10',
      title: 'Chapter X - Payment of Tax',
      sectionRange: 'Sections 49-53',
      summary: 'Electronic ledgers, utilization and delayed-tax interest consequences.',
      focusAreas: <String>['Electronic credit ledger', 'Cash ledger', 'Interest'],
      scrutinyUse: 'Use for interest recomputation and ledger-based demand defence.',
    ),
    GstActChapter(
      id: 'chapter-11',
      title: 'Chapter XI - Refunds',
      sectionRange: 'Section 54-58',
      summary: 'Refund entitlement, documentation and specialized authorities.',
      focusAreas: <String>['Export refund', 'Inverted duty', 'Documentary evidence'],
      scrutinyUse: 'Use for refund deficiency memos and refund rejection replies.',
    ),
    GstActChapter(
      id: 'chapter-12',
      title: 'Chapter XII - Assessment',
      sectionRange: 'Sections 59-64',
      summary: 'Self-assessment, provisional assessment, scrutiny and best judgement assessment.',
      focusAreas: <String>['Self-assessment', 'Scrutiny', 'Best judgement'],
      scrutinyUse: 'Primary chapter for ASMT-10 and return scrutiny response architecture.',
    ),
    GstActChapter(
      id: 'chapter-13',
      title: 'Chapter XIII - Audit',
      sectionRange: 'Sections 65-66',
      summary: 'Departmental audit and special audit powers.',
      focusAreas: <String>['Audit notice', 'Special audit', 'Officer queries'],
      scrutinyUse: 'Use where scrutiny expands into audit and deeper data requests.',
    ),
    GstActChapter(
      id: 'chapter-14',
      title: 'Chapter XIV - Inspection, Search, Seizure and Arrest',
      sectionRange: 'Sections 67-72',
      summary: 'Enforcement powers and immediate-response risk areas.',
      focusAreas: <String>['Inspection', 'Search', 'Seizure', 'Summons'],
      scrutinyUse: 'Escalate immediately when notices reference inspection or coercive powers.',
    ),
    GstActChapter(
      id: 'chapter-15',
      title: 'Chapter XV - Demands and Recovery',
      sectionRange: 'Sections 73-84',
      summary: 'Demand, adjudication, recovery and provisional attachment framework.',
      focusAreas: <String>['Section 73', 'Section 74', 'Section 75', 'Section 83'],
      scrutinyUse: 'Use for show-cause demand strategy, evidence planning and recovery risk assessment.',
    ),
    GstActChapter(
      id: 'chapter-16',
      title: 'Chapter XVI - Liability to Pay in Certain Cases',
      sectionRange: 'Sections 85-94',
      summary: 'Transferee, agent, director and special-person liability positions.',
      focusAreas: <String>['Successor liability', 'Director liability', 'Agent liability'],
      scrutinyUse: 'Use when responsibility is extended beyond the filing entity.',
    ),
    GstActChapter(
      id: 'chapter-17',
      title: 'Chapter XVII - Advance Ruling',
      sectionRange: 'Sections 95-106',
      summary: 'Advance ruling process and statutory interpretation route.',
      focusAreas: <String>['Advance ruling', 'Classification', 'Interpretation'],
      scrutinyUse: 'Use to identify interpretive positions already debated before authorities.',
    ),
    GstActChapter(
      id: 'chapter-18',
      title: 'Chapter XVIII - Appeals and Revision',
      sectionRange: 'Sections 107-121',
      summary: 'Appeals, revision powers and tribunal pathway.',
      focusAreas: <String>['Appeals', 'Revision', 'Pre-deposit', 'Limitation'],
      scrutinyUse: 'Use when scrutiny culminates in appeal strategy after final order.',
    ),
    GstActChapter(
      id: 'chapter-19',
      title: 'Chapter XIX - Offences and Penalties',
      sectionRange: 'Sections 122-138',
      summary: 'Penalty exposure, confiscation and prosecution-related provisions.',
      focusAreas: <String>['Penalties', 'Confiscation', 'Prosecution'],
      scrutinyUse: 'Use where notice language escalates into wilful misconduct or fake-invoice allegations.',
    ),
    GstActChapter(
      id: 'chapter-20',
      title: 'Chapter XX - Transitional Provisions',
      sectionRange: 'Sections 139-142',
      summary: 'Transition arrangements from pre-GST laws to GST regime.',
      focusAreas: <String>['Transition credit', 'Legacy proceedings'],
      scrutinyUse: 'Use for migration-period disputes and transitional credit arguments.',
    ),
    GstActChapter(
      id: 'chapter-21',
      title: 'Chapter XXI - Miscellaneous',
      sectionRange: 'Sections 143-174',
      summary: 'Job work, information powers, anti-profiteering, delegated legislation and repeal/savings.',
      focusAreas: <String>['Job work', 'Information', 'Delegated powers', 'Repeal and savings'],
      scrutinyUse: 'Use for specialized disputes involving procedure, notifications, circulars and repealed-law carryovers.',
    ),
  ];

  static const List<GstActAmendmentEntry> _amendmentTimeline =
      <GstActAmendmentEntry>[
        GstActAmendmentEntry(
          year: 2018,
          amendingInstrument: 'CGST (Amendment) Act, 2018',
          summary: 'Refined return, ITC, registration and recovery mechanics after the first operational year of GST.',
          affectedAreas: <String>['Returns', 'ITC', 'Registration', 'Recovery'],
        ),
        GstActAmendmentEntry(
          year: 2019,
          amendingInstrument: 'Finance Act updates and related notifications',
          summary: 'Operational easing and implementation adjustments through notifications, rules and return-system changes.',
          affectedAreas: <String>['Compliance process', 'Return system', 'Procedural relief'],
        ),
        GstActAmendmentEntry(
          year: 2020,
          amendingInstrument: 'Finance Act, 2020 / Rule changes',
          summary: 'Strengthened matching controls, fraud-prevention levers and documentation expectations.',
          affectedAreas: <String>['Rule 86A', 'Matching controls', 'Fraud-risk review'],
        ),
        GstActAmendmentEntry(
          year: 2021,
          amendingInstrument: 'Finance Act, 2021 / Rule updates',
          summary: 'Reworked ITC conditions, return reconciliation expectations and tighter system-driven compliance checks.',
          affectedAreas: <String>['ITC', 'Return reconciliation', 'System controls'],
        ),
        GstActAmendmentEntry(
          year: 2022,
          amendingInstrument: 'Finance Act, 2022 / Annual GST changes',
          summary: 'Clarified refund, return and penalty exposures along with process modernization.',
          affectedAreas: <String>['Refunds', 'Returns', 'Penalty framework'],
        ),
        GstActAmendmentEntry(
          year: 2023,
          amendingInstrument: 'Finance Act, 2023 / Rule 88C and compliance analytics updates',
          summary: 'Expanded system-intimation and mismatch handling for outward-supply versus return tax differences.',
          affectedAreas: <String>['Rule 88C', 'Mismatch handling', 'Analytics-based compliance'],
        ),
      ];

  static const List<GstProblemGuide> _problemGuides = <GstProblemGuide>[
    GstProblemGuide(
      id: 'asmt-10-scrutiny',
      title: 'ASMT-10 return scrutiny notice',
      category: 'Return scrutiny',
      keywords: <String>[
        'scrutiny',
        'discrepancy',
        'return mismatch',
        'gstr 1',
        'gstr 3b',
        'itc mismatch',
      ],
      noticeForms: <String>['ASMT-10', 'ASMT 10'],
      summary:
          'Reconcile every discrepancy with filed returns, books and portal data before preparing a point-wise response.',
      immediateActions: <String>[
        'Verify GSTIN, tax period, notice number and reply deadline.',
        'Download filed GSTR-1, GSTR-3B and relevant electronic ledgers.',
        'Preserve the complete notice and supporting working papers.',
      ],
      steps: <String>[
        'Map each allegation to the affected return table and transactions.',
        'Prepare books-to-return and return-to-portal reconciliations.',
        'Separate accepted, timing and disputed differences.',
        'Draft a factual point-wise reply with indexed annexures.',
        'Obtain professional review before filing.',
      ],
      requiredDocuments: <String>[
        'Complete ASMT-10 notice',
        'Filed GSTR-1 and GSTR-3B',
        'Books and tax ledgers',
        'Invoice-level reconciliation',
        'Supporting invoices and credit notes',
      ],
      sectionIds: <String>['sec-61', 'rule-36'],
      deadlineGuidance:
          'Use the deadline stated in the notice and seek extension before expiry when evidence cannot be completed.',
      escalationGuidance:
          'Escalate material tax exposure, repeated mismatch or fraud language to the CA or legal reviewer.',
    ),
    GstProblemGuide(
      id: 'drc-demand-recovery',
      title: 'DRC demand and recovery notice',
      category: 'Demand and recovery',
      keywords: <String>[
        'demand',
        'recovery',
        'tax short paid',
        'interest',
        'penalty',
        'show cause',
      ],
      noticeForms: <String>['DRC-01', 'DRC-01A', 'DRC-07'],
      summary:
          'Validate jurisdiction, limitation, computation and allegation-wise evidence before accepting or contesting a demand.',
      immediateActions: <String>[
        'Confirm the form, proceeding stage and response deadline.',
        'Recompute tax, interest and penalty independently.',
        'Identify whether payment or a reply has already been recorded.',
      ],
      steps: <String>[
        'Create an allegation-wise demand reconciliation.',
        'Check limitation, duplicate demand and prior proceedings.',
        'Document admitted and disputed portions separately.',
        'Prepare legal and factual submissions with evidence.',
        'Review payment, hearing and appeal options before action.',
      ],
      requiredDocuments: <String>[
        'Complete DRC notice and annexures',
        'Demand computation',
        'Relevant returns and ledgers',
        'Prior replies or orders',
        'Payment challans and evidence',
      ],
      sectionIds: <String>['sec-50'],
      deadlineGuidance:
          'Verify the statutory and notice-specific deadline immediately because recovery timelines affect remedies.',
      escalationGuidance:
          'Escalate every material demand, penalty allegation or recovery action for CA and legal review.',
    ),
    GstProblemGuide(
      id: 'registration-cancellation',
      title: 'Registration cancellation or suspension notice',
      category: 'Registration',
      keywords: <String>[
        'registration',
        'cancellation',
        'suspension',
        'non filing',
        'principal place',
      ],
      noticeForms: <String>['REG-17', 'REG-31'],
      summary:
          'Resolve the compliance default and prove continuing eligibility and business activity with current records.',
      immediateActions: <String>[
        'Check portal status and the effective suspension date.',
        'Identify pending returns, verification or address issues.',
        'Collect current business, identity and premises evidence.',
      ],
      steps: <String>[
        'Cure return or profile defaults where legally possible.',
        'Prepare evidence of genuine business activity.',
        'Draft the reply and request a hearing when appropriate.',
        'Track the portal acknowledgement and final order.',
      ],
      requiredDocuments: <String>[
        'Complete registration notice',
        'Registration certificate',
        'Premises and business activity proof',
        'Filed return status',
        'Identity and authorization documents',
      ],
      sectionIds: <String>[],
      deadlineGuidance:
          'Reply within the notice deadline because suspension can restrict invoicing and returns.',
      escalationGuidance:
          'Escalate cancellation, retrospective action or disputed jurisdiction immediately.',
    ),
    GstProblemGuide(
      id: 'general-gst-enquiry',
      title: 'General GST notice review',
      category: 'General',
      keywords: <String>['notice', 'gst', 'reply', 'hearing'],
      noticeForms: <String>[],
      summary:
          'Verify the complete notice, statutory provision, facts, deadline and portal status before responding.',
      immediateActions: <String>[
        'Capture the complete notice and all annexures.',
        'Verify GSTIN, period, authority, form and deadline.',
        'Check OCR text against the source document.',
      ],
      steps: <String>[
        'Identify every allegation and requested action.',
        'Reconcile allegations with books, returns and portal records.',
        'Prepare a factual response and indexed evidence.',
        'Obtain CA or legal review before filing.',
      ],
      requiredDocuments: <String>[
        'Complete notice and annexures',
        'Relevant returns and books',
        'Issue-wise reconciliation',
        'Supporting evidence',
      ],
      sectionIds: <String>[],
      deadlineGuidance: 'Use the date stated in the complete notice.',
      escalationGuidance:
          'Escalate unclear jurisdiction, material demand, fraud language, hearing or cancellation risk.',
    ),
  ];

  static const List<GstJudgementEntry> _judgements = <GstJudgementEntry>[
    GstJudgementEntry(
      id: 'judgement-1',
      title: 'M/S. Bharti Airtel Ltd. v. Union of India',
      summary: 'A landmark reference on input tax credit and procedural fairness in GST matters.',
      court: 'Supreme Court of India',
      year: 2023,
      topic: 'ITC and procedural fairness',
      keywords: <String>['itc', 'procedural', 'fairness'],
      filedBy: 'Taxpayer',
      outcome: 'Partly allowed / issue clarified',
      orderReference: 'Supreme Court order note for rectification and ITC transition issues',
      orderSummary:
          'Useful when the draft reply needs to explain that procedural machinery cannot always rewrite the return design after the fact, but factual reconciliation still matters.',
      replyUse:
          'Use for ITC reconciliation, procedural fairness, and return-design limitation arguments.',
    ),
    GstJudgementEntry(
      id: 'judgement-2',
      title: 'Karnataka High Court on reverse charge and valuation',
      summary: 'Useful precedent for reverse charge applicability and valuation disputes.',
      court: 'Karnataka High Court',
      year: 2022,
      topic: 'Reverse charge and valuation',
      keywords: <String>['reverse charge', 'valuation', 'gst'],
      filedBy: 'Taxpayer',
      outcome: 'Relief granted on issue-specific valuation reasoning',
      orderReference: 'High Court order note on valuation interpretation and levy scope',
      orderSummary:
          'Helpful where the notice extends valuation or reverse-charge exposure without reconciling the actual nature of supply and documentary support.',
      replyUse:
          'Use for valuation rebuttal, reverse-charge scope disputes and factual classification notes.',
    ),
    GstJudgementEntry(
      id: 'judgement-3',
      title: 'Delhi High Court on notice and limitation',
      summary: 'Helpful guidance on notice issuance, limitation and reply strategy for GST disputes.',
      court: 'Delhi High Court',
      year: 2021,
      topic: 'Notice and limitation',
      keywords: <String>['notice', 'limitation', 'reply'],
      filedBy: 'Taxpayer',
      outcome: 'Proceeding questioned on notice quality / limitation grounds',
      orderReference: 'High Court order note on valid notice foundation and timeline discipline',
      orderSummary:
          'Useful when the proceeding suffers from vague allegation drafting, missing annexures, or a visible limitation issue.',
      replyUse:
          'Use for preliminary objections on limitation, jurisdiction and deficient notice structure.',
    ),
    GstJudgementEntry(
      id: 'judgement-4',
      title: 'Appellate ruling on export refund documentation',
      summary: 'Reference for refund disputes where documentary compliance was substantially met.',
      court: 'Appellate Authority',
      year: 2022,
      topic: 'Refund and documentation',
      keywords: <String>['refund', 'export', 'documentation'],
      filedBy: 'Taxpayer',
      outcome: 'Allowed subject to document verification',
      orderReference: 'Appellate order note on substantial compliance for exports',
      orderSummary:
          'Useful when the officer focuses on technical document gaps despite reconciled export trail and tax neutrality.',
      replyUse:
          'Use for refund scrutiny, export paperwork gaps and substantial-compliance arguments.',
    ),
    GstJudgementEntry(
      id: 'judgement-5',
      title: 'Department appeal on fake invoice allegation and evidentiary burden',
      summary: 'Guides how transaction trail, transport proof and payment evidence influence adverse invoice allegations.',
      court: 'High Court',
      year: 2024,
      topic: 'Fake invoice / evidentiary burden',
      keywords: <String>['fake invoice', 'evidence', 'transport', 'payment'],
      filedBy: 'Department appeal',
      outcome: 'Mixed outcome based on evidence quality',
      orderReference: 'Order note on burden of proof and transaction trail verification',
      orderSummary:
          'Useful where the reply needs to show bank trail, e-way bill, goods receipt and ledger continuity before any adverse inference is drawn.',
      replyUse:
          'Use for bogus billing allegations, supplier-risk notices and evidence-index planning.',
    ),
      GstJudgementEntry(
        id: 'judgement-6',
        title: 'Madras High Court on personal hearing and natural justice',
        summary: 'Supports challenge where adjudication moved ahead without meaningful opportunity of hearing.',
        court: 'Madras High Court',
        year: 2023,
        topic: 'Natural justice and hearing',
        keywords: <String>['hearing', 'natural justice', 'adjudication'],
        filedBy: 'Taxpayer',
        outcome: 'Order set aside for fresh hearing',
        orderReference: 'Order note on meaningful hearing before adverse decision',
        orderSummary:
          'Useful when the officer closes proceedings without addressing submitted reconciliation or adjournment requests.',
        replyUse:
          'Use for hearing-right objections, procedural fairness and remand requests.',
      ),
      GstJudgementEntry(
        id: 'judgement-7',
        title: 'Gujarat High Court on cancellation restoration for procedural default',
        summary: 'Helpful in registration restoration matters where substantive business continuity was demonstrated.',
        court: 'Gujarat High Court',
        year: 2022,
        topic: 'Registration cancellation',
        keywords: <String>['registration', 'cancellation', 'restoration'],
        filedBy: 'Taxpayer',
        outcome: 'Relief granted with restoration directions',
        orderReference: 'Order note on balancing compliance default with genuine business continuity',
        orderSummary:
          'Useful when registration is proposed to be cancelled without considering updated returns or business evidence.',
        replyUse:
          'Use for REG-17 replies, suspension restoration and proportionality arguments.',
      ),
      GstJudgementEntry(
        id: 'judgement-8',
        title: 'Allahabad High Court on detention, e-way bill defect and proportional response',
        summary: 'Reference for transport and e-way bill disputes where minor errors were treated as severe violations.',
        court: 'Allahabad High Court',
        year: 2021,
        topic: 'E-way bill and detention',
        keywords: <String>['e-way bill', 'detention', 'minor error'],
        filedBy: 'Taxpayer',
        outcome: 'Relief on proportionality grounds',
        orderReference: 'Order note on distinguishing clerical defects from evasion intent',
        orderSummary:
          'Useful where minor transportation-document issues are escalated into tax and penalty exposure.',
        replyUse:
          'Use for transport-document reconciliation and proportionality-based defence.',
      ),
      GstJudgementEntry(
        id: 'judgement-9',
        title: 'Rajasthan High Court on provisional attachment review',
        summary: 'Guides how attachment powers should be used cautiously and with proportional justification.',
        court: 'Rajasthan High Court',
        year: 2024,
        topic: 'Provisional attachment',
        keywords: <String>['attachment', 'bank attachment', 'section 83'],
        filedBy: 'Taxpayer',
        outcome: 'Attachment narrowed / reviewed',
        orderReference: 'Order note on necessity and proportionality for Section 83 attachment',
        orderSummary:
          'Useful where account-freezing or attachment is invoked without clear necessity or quantified risk to revenue.',
        replyUse:
          'Use for urgent representation against attachment and revenue-protection overreach.',
      ),
      GstJudgementEntry(
        id: 'judgement-10',
        title: 'CESTAT-style appellate reasoning on classification and exemption overlap',
        summary: 'Practical reference for tariff classification disputes impacting rate, exemption and penalty exposure.',
        court: 'Appellate Tribunal reasoning reference',
        year: 2023,
        topic: 'Classification and exemption',
        keywords: <String>['classification', 'exemption', 'rate dispute'],
        filedBy: 'Taxpayer',
        outcome: 'Issue remanded / partly allowed',
        orderReference: 'Order note on classification evidence and exemption preconditions',
        orderSummary:
          'Useful when the rate dispute turns on product description, composition, HSN alignment and exemption conditions.',
        replyUse:
          'Use for HSN, rate and exemption-condition arguments in scrutiny and appeal prep.',
      ),
  ];

  List<GstLibrarySection> get sections =>
      List<GstLibrarySection>.unmodifiable(_sections);

  List<GstProblemGuide> get problemGuides =>
      List<GstProblemGuide>.unmodifiable(_problemGuides);

  List<GstActChapter> get actChapters =>
      List<GstActChapter>.unmodifiable(_actChapters);

  List<GstActAmendmentEntry> get amendmentTimeline =>
      List<GstActAmendmentEntry>.unmodifiable(_amendmentTimeline);

  List<GstJudgementEntry> get judgements =>
      List<GstJudgementEntry>.unmodifiable(_judgements);

  List<String> get judgementCourts => _sortedUnique(
    _judgements.map((entry) => entry.court),
  );

  List<String> get judgementFiledByOptions => _sortedUnique(
    _judgements.map((entry) => entry.filedBy),
  );

  List<String> get judgementOutcomeOptions => _sortedUnique(
    _judgements.map((entry) => entry.outcome),
  );

  GstLibrarySection? sectionById(String id) {
    for (final section in _sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  List<GstLibrarySection> searchSections(
    String query, {
    String category = 'all',
  }) {
    final normalized = _normalizeSearchText(query);
    final queryTerms = normalized
        .split(' ')
        .where((term) => term.length > 1)
        .toList(growable: false);
    return _sections.where((section) {
      if (category != 'all' && section.category != category) {
        if (!(category == 'section' &&
            section.category != 'act' &&
            section.category != 'judgement')) {
          return false;
        }
      }
      if (normalized.isEmpty) return true;
      final haystack = _normalizeSearchText(
        <String>[
          section.displayName,
          section.summary,
          ...section.highlights,
          ...section.keywords,
        ].join(' '),
      );
      return _matchesAllTerms(haystack, queryTerms);
    }).toList(growable: false);
  }

  List<GstJudgementEntry> searchJudgements({
    String query = '',
    String? court,
    String? filedBy,
    String? outcome,
  }) {
    final normalized = _normalizeSearchText(query);
    final queryTerms = normalized
        .split(' ')
        .where((term) => term.length > 1)
        .toList(growable: false);
    return _judgements.where((judgement) {
      if (court != null && court.isNotEmpty && judgement.court != court) {
        return false;
      }
      if (filedBy != null && filedBy.isNotEmpty && judgement.filedBy != filedBy) {
        return false;
      }
      if (outcome != null && outcome.isNotEmpty && judgement.outcome != outcome) {
        return false;
      }
      if (normalized.isEmpty) return true;
      final haystack = _normalizeSearchText(
        <String>[
          judgement.title,
          judgement.summary,
          judgement.topic,
          judgement.court,
          judgement.filedBy,
          judgement.outcome,
          judgement.orderReference,
          judgement.orderSummary,
          judgement.replyUse,
          ...judgement.keywords,
        ].join(' '),
      );
      return _matchesAllTerms(haystack, queryTerms);
    }).toList(growable: false);
  }

  List<GstGuidanceSearchResult> searchGuidance(String question) {
    final normalized = _normalizeSearchText(question);
    final queryTerms = normalized
        .split(' ')
        .where((term) => term.length > 1)
        .toSet();
    final results = <GstGuidanceSearchResult>[];

    for (final guide in _problemGuides) {
      var score = 0;
      final matched = <String>{};
      for (final form in guide.noticeForms) {
        if (normalized.contains(_normalizeSearchText(form))) {
          score += 12;
          matched.add(form);
        }
      }
      for (final keyword in guide.keywords) {
        final normalizedKeyword = _normalizeSearchText(keyword);
        if (normalized.contains(normalizedKeyword)) {
          score += normalizedKeyword.contains(' ') ? 7 : 4;
          matched.add(keyword);
        } else if (queryTerms.contains(normalizedKeyword)) {
          score += 3;
          matched.add(keyword);
        }
      }
      if (score > 0 && guide.id != 'general-gst-enquiry') {
        results.add(
          GstGuidanceSearchResult(
            guide: guide,
            score: score,
            matchedTerms: matched.toList(growable: false),
          ),
        );
      }
    }

    results.sort((left, right) => right.score.compareTo(left.score));
    if (results.isNotEmpty) return results;
    return <GstGuidanceSearchResult>[
      GstGuidanceSearchResult(
        guide: _problemGuides.last,
        score: 0,
        matchedTerms: const <String>[],
      ),
    ];
  }

  static String _normalizeSearchText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> _sortedUnique(Iterable<String> values) {
    final unique = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    unique.sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return unique;
  }

  static bool _matchesAllTerms(String haystack, List<String> queryTerms) {
    if (queryTerms.isEmpty) return true;
    for (final term in queryTerms) {
      if (!haystack.contains(term)) {
        return false;
      }
    }
    return true;
  }
}
