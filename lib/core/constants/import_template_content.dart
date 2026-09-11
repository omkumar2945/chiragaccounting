class ImportTemplateContent {
  const ImportTemplateContent._();

    static const String hiringCandidatesCsv =
            'name,mobile,email,position,department,notes,applied_at\n'
            'Amit Sharma,9876543210,amit@example.com,Accountant,Finance,Strong ledger and GST basics,2026-08-01\n'
            'Priya Mehta,9988776655,priya@example.com,HR Executive,HR,Good communication and screening skills,2026-08-01\n'
            'Rahul Verma,9123456789,rahul@example.com,Checker,Audit,Can review vouchers and support follow-ups,2026-08-01\n';

  static const String clientUsersCsv =
      'client_name,company_name,mobile,email,status,gst_registration_type,gstin,pan,state,city,services,accounting_service,gst_service\n'
      'ABC Traders,ABC Traders Private Limited,9876543210,accounts@abctraders.in,not_onboarded,regular,24ABCDE1234F1Z5,ABCDE1234F,Gujarat,Ahmedabad,Accounting|GST,yes,yes\n'
      'Mohan Retail,Mohan Retail,9988776655,mohan.retail@gmail.com,not_onboarded,composition,24AAACM1234F1Z7,AAACM1234F,Gujarat,Surat,GST,yes,yes\n'
      'Shree Distributors,Shree Distributors,9123456789,billing@shreedistributors.com,not_onboarded,unregistered,,,Maharashtra,Mumbai,Accounting,yes,no\n';

  static const String customerDebtorsCsv =
      'ledger_name,ledger_group,mobile,email,gstin,pan,opening_balance\n'
      'ABC Traders,Sundry Debtors,9876543210,accounts@abctraders.in,27ABCDE1234F1Z5,ABCDE1234F,15000\n'
      'Mohan Retail,Sundry Debtors,9988776655,mohan.retail@gmail.com,,,0\n'
      'Shree Distributors,Sundry Debtors,9123456789,billing@shreedistributors.com,24AAACS1234D1Z2,AAACS1234D,25000\n'
      'Nandini Agencies,Sundry Debtors,9090909090,finance@nandiniagencies.com,29AABCN2345P1Z7,AABCN2345P,8200\n';

  static const String vendorCreditorsCsv =
      'ledger_name,ledger_group,mobile,email,gstin,pan,opening_balance\n'
      'XYZ Supplies,Sundry Creditors,9000011111,accounts@xyzsupplies.in,27AACCX9876K1Z9,AACCX9876K,12000\n'
      'Metro Wholesales,Sundry Creditors,9988001122,ap@metrowholesales.in,24AAACM1234G1Z8,AAACM1234G,5000\n'
      'Prime Metals,Sundry Creditors,9000033333,prime.metals@gmail.com,,,3500\n'
      'Global Traders,Sundry Creditors,9000022222,billing@globaltraders.com,24AABCG4321M1Z7,AABCG4321M,8000\n';

  static const String allLedgersMixedCsv =
      'ledger_name,ledger_group,mobile,email,gstin,pan,opening_balance\n'
      'ABC Traders,Sundry Debtors,9876543210,accounts@abctraders.in,27ABCDE1234F1Z5,ABCDE1234F,15000\n'
      'XYZ Supplies,Sundry Creditors,9000011111,accounts@xyzsupplies.in,27AACCX9876K1Z9,AACCX9876K,12000\n'
      'Cash Account,Cash-in-Hand,,,,,0\n'
      'Bank of India A/c,Bank Accounts,,,,,250000\n'
      'Discount Received,Indirect Incomes,,,,,0\n'
      'Stationery Expense,Indirect Expenses,,,,,0\n';

  static const String inventoryCsv =
      'product_name,hsn,unit,opening_stock,purchase_rate,sales_rate,category\n'
      'Notebook A5,4820,Nos,120,28,35,Stationery\n'
      'Ball Pen Blue,9608,Nos,500,6,8,Stationery\n'
      'Cement OPC 50kg,25232930,Bag,90,320,365,Building Material\n'
      'Steel Rod 12mm,72142000,Nos,75,540,610,Steel\n'
      'Ceramic Tile 2x2,69072100,Box,45,450,560,Tiles\n';

  static const String inventoryJson =
      '[\n'
      '  {"product_name":"Notebook A5","hsn":"4820","unit":"Nos","opening_stock":120,"purchase_rate":28,"sales_rate":35,"category":"Stationery"},\n'
      '  {"product_name":"Ball Pen Blue","hsn":"9608","unit":"Nos","opening_stock":500,"purchase_rate":6,"sales_rate":8,"category":"Stationery"},\n'
      '  {"product_name":"Cement OPC 50kg","hsn":"25232930","unit":"Bag","opening_stock":90,"purchase_rate":320,"sales_rate":365,"category":"Building Material"},\n'
      '  {"product_name":"Steel Rod 12mm","hsn":"72142000","unit":"Nos","opening_stock":75,"purchase_rate":540,"sales_rate":610,"category":"Steel"},\n'
      '  {"product_name":"Ceramic Tile 2x2","hsn":"69072100","unit":"Box","opening_stock":45,"purchase_rate":450,"sales_rate":560,"category":"Tiles"}\n'
      ']\n';
}
