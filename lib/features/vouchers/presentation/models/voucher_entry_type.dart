import 'package:flutter/material.dart';

enum VoucherEntryType {
  payment,
  receipt,
  contra,
  journal,
  purchase,
  sales,
  debitNote,
  creditNote,
  expense,
  income,
  bankTransfer,
  cashTransfer,
}

extension VoucherEntryTypeX on VoucherEntryType {
  String get title {
    switch (this) {
      case VoucherEntryType.payment:
        return 'Payment Voucher';
      case VoucherEntryType.receipt:
        return 'Receipt Voucher';
      case VoucherEntryType.contra:
        return 'Contra Voucher';
      case VoucherEntryType.journal:
        return 'Journal Voucher';
      case VoucherEntryType.purchase:
        return 'Purchase Voucher';
      case VoucherEntryType.sales:
        return 'Sales Voucher';
      case VoucherEntryType.debitNote:
        return 'Debit Note';
      case VoucherEntryType.creditNote:
        return 'Credit Note';
      case VoucherEntryType.expense:
        return 'Expense Voucher';
      case VoucherEntryType.income:
        return 'Income Voucher';
      case VoucherEntryType.bankTransfer:
        return 'Bank Transfer';
      case VoucherEntryType.cashTransfer:
        return 'Cash Transfer';
    }
  }

  String get subtitle {
    switch (this) {
      case VoucherEntryType.payment:
        return 'Record outgoing payments with complete references.';
      case VoucherEntryType.receipt:
        return 'Capture incoming collections with proof and notes.';
      case VoucherEntryType.contra:
        return 'Transfer value between cash and bank accounts.';
      case VoucherEntryType.journal:
        return 'Post adjustment and non-cash accounting entries.';
      case VoucherEntryType.purchase:
        return 'Create purchase invoice entries with item details.';
      case VoucherEntryType.sales:
        return 'Create sales invoice entries with GST breakup.';
      case VoucherEntryType.debitNote:
        return 'Raise debit note against supplier or customer.';
      case VoucherEntryType.creditNote:
        return 'Issue credit note with reason and line item details.';
      case VoucherEntryType.expense:
        return 'Book operational expenses with payment mode.';
      case VoucherEntryType.income:
        return 'Record non-sales income entries accurately.';
      case VoucherEntryType.bankTransfer:
        return 'Post transfer from one bank account to another.';
      case VoucherEntryType.cashTransfer:
        return 'Track cash transfers between business points.';
    }
  }

  IconData get icon {
    switch (this) {
      case VoucherEntryType.payment:
        return Icons.payments_outlined;
      case VoucherEntryType.receipt:
        return Icons.account_balance_wallet_outlined;
      case VoucherEntryType.contra:
        return Icons.sync_alt_outlined;
      case VoucherEntryType.journal:
        return Icons.menu_book_outlined;
      case VoucherEntryType.purchase:
        return Icons.shopping_cart_outlined;
      case VoucherEntryType.sales:
        return Icons.point_of_sale_outlined;
      case VoucherEntryType.debitNote:
        return Icons.trending_down_outlined;
      case VoucherEntryType.creditNote:
        return Icons.assignment_return_outlined;
      case VoucherEntryType.expense:
        return Icons.money_off_csred_outlined;
      case VoucherEntryType.income:
        return Icons.trending_up_outlined;
      case VoucherEntryType.bankTransfer:
        return Icons.account_balance_outlined;
      case VoucherEntryType.cashTransfer:
        return Icons.currency_rupee_outlined;
    }
  }
}
