enum UniversalStatus {
  draft,
  submitted,
  verified,
  approved,
  completed,
  archived,
}

extension UniversalStatusX on UniversalStatus {
  String get displayName {
    switch (this) {
      case UniversalStatus.draft:
        return 'Draft';
      case UniversalStatus.submitted:
        return 'Submitted';
      case UniversalStatus.verified:
        return 'Verified';
      case UniversalStatus.approved:
        return 'Approved';
      case UniversalStatus.completed:
        return 'Completed';
      case UniversalStatus.archived:
        return 'Archived';
    }
  }
}
