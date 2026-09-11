import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/clients/DataExchange/client_data_exchange_screen.dart'
  as data_exchange;

class ClientDataExchangeScreen extends StatelessWidget {
  final int initialTabIndex;

  const ClientDataExchangeScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return data_exchange.ClientDataExchangeScreen(
      initialTabIndex: initialTabIndex,
    );
  }
}