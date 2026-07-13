import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget dashboardCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  icon,
                  size: 35,
                  color: color,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),

      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Chirag Accounting"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "Welcome 👋",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              "Smart Accounting Dashboard",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 25),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,

                children: [

                  dashboardCard(
                    icon: Icons.point_of_sale,
                    title: "Sales",
                    color: Colors.green,
                  ),

                  dashboardCard(
                    icon: Icons.shopping_cart,
                    title: "Purchase",
                    color: Colors.orange,
                  ),

                  dashboardCard(
                    icon: Icons.account_balance,
                    title: "Bank",
                    color: Colors.blue,
                  ),

                  dashboardCard(
                    icon: Icons.receipt_long,
                    title: "Reports",
                    color: Colors.purple,
                  ),

                  dashboardCard(
                    icon: Icons.folder,
                    title: "Documents",
                    color: Colors.teal,
                  ),

                  dashboardCard(
                    icon: Icons.people,
                    title: "Clients",
                    color: Colors.red,
                  ),

                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}